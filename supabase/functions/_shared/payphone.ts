// PayPhone: cálculo del split, cifrado de transferTo y llamadas a la API
// del Botón de Pagos. Lo usan payphone-prepare y payphone-confirm.
//
// Documentación (verificada el 10 nov 2026):
//   https://docs.payphone.app/boton-de-pago-por-redireccion
//   https://docs.payphone.app/split-de-pagos
//
// Todos los montos van en CENTAVOS ENTEROS. Nada de flotantes después de
// toCents(): así no hay diferencias de redondeo entre lo que se reparte y lo
// que se cobra.

export const PAYPHONE_API = "https://pay.payphonetodoesposible.com/api"

// ─────────────────────────── Montos ───────────────────────────

// Dólares (número o texto de la base) → centavos. Rechaza más de 2 decimales:
// un monto así no debería salir nunca de la base y es mejor detenerse.
export function toCents(dollars: number | string): number {
  const n = Number(dollars)
  if (!Number.isFinite(n) || n < 0) throw new Error(`INVALID_AMOUNT: ${dollars}`)
  const cents = Math.round(n * 100)
  if (Math.abs(cents - n * 100) > 1e-6) throw new Error(`INVALID_AMOUNT: ${dollars}`)
  return cents
}

// Comisión de PayPhone sobre el total, redondeada HACIA ARRIBA al centavo.
// Es la opción conservadora: si PayPhone redondea distinto, el tope nunca
// deja repartir más de lo que realmente queda (lo que falte lo pondría el
// saldo de ChivasPass, según la documentación).
// pct con hasta 2 decimales (5.75) → se trabaja en centésimas de punto.
export function commissionCents(totalCents: number, pct: number): number {
  if (!Number.isInteger(totalCents) || totalCents < 0) throw new Error("INVALID_AMOUNT")
  const hundredths = Math.round(pct * 100)
  if (!Number.isFinite(pct) || pct < 0 || pct >= 100 || Math.abs(hundredths - pct * 100) > 1e-6) {
    throw new Error(`INVALID_COMMISSION: ${pct}`)
  }
  return Math.ceil((totalCents * hundredths) / 10000)
}

export interface SplitRecipientInput {
  role: "owner" | "agency"
  identifier: string
  type: number         // 3 = RUC/cédula (Business), 4 = celular +593 (Personal)
  amount: number | string  // dólares, tal como los devuelve payphone_split_recipients
}

export interface SplitPlan {
  total_cents: number
  payphone_cents: number
  seller_cents: number        // suma de todo lo que se reparte
  net_fee_cents: number       // lo que queda para ChivasPass
  commission_pct: number
  recipients: { role: string; identifier: string; type: number; amount_cents: number }[]
}

export type SplitError =
  | "NO_RECIPIENTS"
  | "MULTI_RECIPIENT_DISABLED"
  | "INVALID_RECIPIENT"
  | "SPLIT_EXCEEDS_AVAILABLE"

const IDENTIFIER_RE: Record<number, RegExp> = {
  3: /^[0-9]{10}([0-9]{3})?$/,
  4: /^\+5939[0-9]{8}$/,
}

// Arma el reparto y valida el tope:
//   seller_cents <= total_cents - payphone_cents
// allowMultiple=false (fase 1): solo un receptor. Con true se acepta dueño +
// agencia; queda probado pero apagado hasta activarlo.
export function planSplit(
  totalDollars: number | string,
  commissionPct: number,
  recipients: SplitRecipientInput[],
  allowMultiple = false,
): { ok: true; plan: SplitPlan } | { ok: false; error: SplitError; detail?: Record<string, number> } {
  if (!recipients.length) return { ok: false, error: "NO_RECIPIENTS" }
  if (recipients.length > 1 && !allowMultiple) return { ok: false, error: "MULTI_RECIPIENT_DISABLED" }

  const total = toCents(totalDollars)
  const payphone = commissionCents(total, commissionPct)

  const rows = []
  for (const r of recipients) {
    const type = Number(r.type)
    const re = IDENTIFIER_RE[type]
    if (!re || !re.test(String(r.identifier ?? ""))) return { ok: false, error: "INVALID_RECIPIENT" }
    const cents = toCents(r.amount)
    if (cents <= 0) return { ok: false, error: "INVALID_RECIPIENT" }
    rows.push({ role: r.role, identifier: String(r.identifier), type, amount_cents: cents })
  }

  const seller = rows.reduce((s, r) => s + r.amount_cents, 0)
  const available = total - payphone
  if (seller > available) {
    return { ok: false, error: "SPLIT_EXCEEDS_AVAILABLE", detail: { total, payphone, seller, available } }
  }

  return {
    ok: true,
    plan: {
      total_cents: total,
      payphone_cents: payphone,
      seller_cents: seller,
      net_fee_cents: available - seller,
      commission_pct: commissionPct,
      recipients: rows,
    },
  }
}

// JSON del split tal como lo pide PayPhone. La documentación muestra Amount
// como texto ("100") en el JSON ilustrativo y como número (500) en los
// ejemplos de código: PAYPHONE_SPLIT_AMOUNT_AS=number cambia el formato sin
// tocar código si PayPhone responde que debe ser número.
export function transferToJson(plan: SplitPlan, amountAs: "string" | "number" = "string"): string {
  return JSON.stringify(plan.recipients.map((r) => ({
    Identifier: r.identifier,
    Type: r.type,
    Amount: amountAs === "number" ? r.amount_cents : String(r.amount_cents),
  })))
}

// ─────────────────────────── Cifrado ───────────────────────────

// AES-256-CBC + Base64, igual que el ejemplo oficial:
//   PHP: openssl_encrypt($json, 'AES-256-CBC', $clave, OPENSSL_RAW_DATA, '')
//   JS:  CryptoJS.AES.encrypt(json, Utf8.parse(clave), { iv: Utf8.parse('') })
// El IV vacío equivale a 16 bytes en cero en ambas librerías; el relleno es
// PKCS7 (el de Web Crypto y el de ambas librerías). La clave se usa tal cual
// en UTF-8 y debe medir 32 bytes: con otro largo CryptoJS usaría AES-128/192
// y PHP rellenaría con ceros, y los dos ejemplos dejarían de coincidir.
export async function encryptTransferTo(json: string, key: string): Promise<string> {
  const keyBytes = new TextEncoder().encode(key)
  if (keyBytes.length !== 32) {
    throw new Error(`PAYPHONE_ENCRYPTION_KEY debe medir 32 bytes (mide ${keyBytes.length}).`)
  }
  const cryptoKey = await crypto.subtle.importKey("raw", keyBytes, { name: "AES-CBC" }, false, ["encrypt"])
  const cipher = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv: new Uint8Array(16) },
    cryptoKey,
    new TextEncoder().encode(json),
  )
  let bin = ""
  for (const b of new Uint8Array(cipher)) bin += String.fromCharCode(b)
  return btoa(bin)
}

// ─────────────────────────── API ───────────────────────────

// 32 caracteres hexadecimales: único y sin guiones. PayPhone no documenta el
// largo máximo de clientTransactionId.
export const newClientTransactionId = () => crypto.randomUUID().replaceAll("-", "")

export interface PrepareInput {
  token: string
  storeId: string
  clientTransactionId: string
  totalCents: number
  reference: string
  responseUrl: string
  cancellationUrl?: string
  email?: string
  transferTo?: string
}

export interface PrepareResult {
  ok: boolean
  status: number
  paymentId?: string
  payWithCard?: string
  payWithPayPhone?: string
  body: Record<string, unknown>
}

// POST /api/button/Prepare. Sin impuestos desglosados: el total va completo
// en amountWithoutTax (amount = amountWithoutTax + amountWithTax + tax).
export async function preparePayment(input: PrepareInput): Promise<PrepareResult> {
  const body: Record<string, unknown> = {
    amount: input.totalCents,
    amountWithoutTax: input.totalCents,
    amountWithTax: 0,
    tax: 0,
    clientTransactionId: input.clientTransactionId,
    currency: "USD",
    storeId: input.storeId,
    reference: input.reference.slice(0, 100),
    responseUrl: input.responseUrl,
    lang: "es",
    timeZone: -5,
  }
  if (input.cancellationUrl) body.cancellationUrl = input.cancellationUrl
  if (input.email) body.email = input.email
  if (input.transferTo) body.transferTo = input.transferTo

  const res = await fetch(`${PAYPHONE_API}/button/Prepare`, {
    method: "POST",
    headers: { Authorization: `Bearer ${input.token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  })
  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>
  const payWithCard = typeof data.payWithCard === "string" ? data.payWithCard : undefined
  return {
    ok: res.ok && Boolean(payWithCard),
    status: res.status,
    paymentId: data.paymentId != null ? String(data.paymentId) : undefined,
    payWithCard,
    payWithPayPhone: typeof data.payWithPayPhone === "string" ? data.payWithPayPhone : undefined,
    body: data,
  }
}

export interface ConfirmResult {
  ok: boolean               // la llamada respondió con un detalle de transacción
  status: number
  approved: boolean         // statusCode 3
  canceled: boolean         // statusCode 2
  transactionId?: string
  amountCents?: number
  clientTransactionId?: string
  authorizationCode?: string
  body: Record<string, unknown>
}

// POST /api/button/V2/Confirm con { id, clientTxId }. Hay que llamarla en los
// 5 minutos siguientes al pago: si no, PayPhone revierte la transacción.
export async function confirmPayment(token: string, id: number, clientTxId: string): Promise<ConfirmResult> {
  const res = await fetch(`${PAYPHONE_API}/button/V2/Confirm`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({ id, clientTxId }),
    signal: AbortSignal.timeout(15000),
  })
  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>
  const code = Number(data.statusCode)
  const status = String(data.transactionStatus ?? "").toLowerCase()
  return {
    ok: res.ok && data.statusCode !== undefined,
    status: res.status,
    approved: code === 3 && status === "approved",
    canceled: code === 2 || status === "canceled",
    transactionId: data.transactionId != null ? String(data.transactionId) : undefined,
    amountCents: data.amount != null ? Number(data.amount) : undefined,
    clientTransactionId: data.clientTransactionId != null ? String(data.clientTransactionId) : undefined,
    authorizationCode: data.authorizationCode != null ? String(data.authorizationCode) : undefined,
    body: data,
  }
}

// Respuesta de PayPhone sin datos sensibles para guardar en metadata.
export function safeConfirmBody(body: Record<string, unknown>): Record<string, unknown> {
  const keep = ["statusCode", "transactionStatus", "transactionId", "authorizationCode", "amount",
    "clientTransactionId", "cardBrand", "lastDigits", "message", "messageCode", "date", "storeName", "errorCode"]
  return Object.fromEntries(Object.entries(body).filter(([k]) => keep.includes(k)))
}
