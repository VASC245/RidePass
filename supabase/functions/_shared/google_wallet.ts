// Google Wallet: crea (o actualiza) el pase en la API de Google y devuelve el
// enlace "Guardar en Google Wallet".
//
// Se guarda el objeto por la API en vez de meterlo entero en el JWT: así el
// enlace es corto (los JWT largos fallan en algunos navegadores) y podemos
// marcar el pase como usado más adelante con un PATCH.
//
// Secrets (los carga Valentin):
//   GOOGLE_WALLET_ISSUER_ID         número del emisor en pay.google.com/business/console
//   GOOGLE_WALLET_SERVICE_ACCOUNT   el JSON completo de la clave de la cuenta de
//                                   servicio (client_email + private_key)

import { importPKCS8, SignJWT } from "https://esm.sh/jose@5.9.6"

const API = "https://walletobjects.googleapis.com/walletobjects/v1"
const SCOPE = "https://www.googleapis.com/auth/wallet_object.issuer"

export interface GoogleSigner {
  issuerId: string
  clientEmail: string
  privateKeyPem: string
}

export function googleSignerFromEnv(env: (k: string) => string | undefined): GoogleSigner | null {
  const issuerId = env("GOOGLE_WALLET_ISSUER_ID")?.trim()
  const raw = env("GOOGLE_WALLET_SERVICE_ACCOUNT")?.trim()
  if (!issuerId || !raw) return null
  const sa = JSON.parse(raw)
  if (!sa?.client_email || !sa?.private_key) throw new Error("La clave de la cuenta de servicio no trae client_email/private_key.")
  return { issuerId, clientEmail: sa.client_email, privateKeyPem: sa.private_key }
}

let cachedToken: { value: string; exp: number } | null = null

async function accessToken(s: GoogleSigner): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value
  const key = await importPKCS8(s.privateKeyPem, "RS256")
  const assertion = await new SignJWT({ scope: SCOPE })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(s.clientEmail)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key)
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
    signal: AbortSignal.timeout(8000),
  })
  const body = await res.json().catch(() => ({}))
  if (!res.ok || !body.access_token) throw new Error(`token de Google: ${res.status} ${body.error ?? ""}`)
  cachedToken = { value: body.access_token, exp: now + Number(body.expires_in ?? 3600) }
  return cachedToken.value
}

async function call(token: string, method: string, path: string, body?: unknown): Promise<Response> {
  return await fetch(`${API}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(8000),
  })
}

// Inserta; si ya existe (409), lo actualiza con los datos actuales.
async function upsert(token: string, kind: "genericClass" | "genericObject", resource: Record<string, unknown>) {
  const ins = await call(token, "POST", `/${kind}`, resource)
  if (ins.ok) return
  if (ins.status !== 409) throw new Error(`${kind} insert: ${ins.status} ${await ins.text()}`)
  const id = encodeURIComponent(String(resource.id))
  const upd = await call(token, "PATCH", `/${kind}/${id}`, resource)
  if (!upd.ok) throw new Error(`${kind} patch: ${upd.status} ${await upd.text()}`)
}

let classReady = false

// Guarda clase y objeto y devuelve https://pay.google.com/gp/v/save/<jwt>.
export async function googleSaveUrl(
  s: GoogleSigner,
  klass: Record<string, unknown>,
  object: Record<string, unknown>,
  origins: string[],
): Promise<string> {
  const token = await accessToken(s)
  if (!classReady) { await upsert(token, "genericClass", klass); classReady = true }
  await upsert(token, "genericObject", object)

  const key = await importPKCS8(s.privateKeyPem, "RS256")
  const jwt = await new SignJWT({
    origins,
    typ: "savetowallet",
    payload: { genericObjects: [{ id: object.id, classId: object.classId }] },
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(s.clientEmail)
    .setAudience("google")
    .setIssuedAt()
    .sign(key)
  return `https://pay.google.com/gp/v/save/${jwt}`
}
