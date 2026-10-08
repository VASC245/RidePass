// Notificaciones server-to-server con Brevo: correo al comprador y SMS al
// vendedor. Nunca se exponen como endpoint: solo las llaman public-reserve y
// kushki-charge después de registrar la venta.
//
// Secrets necesarios:
//   BREVO_API_KEY        clave de API de Brevo (SMTP & API > API keys)
//   BREVO_SENDER_EMAIL   remitente verificado en Brevo (ej. "tickets@chivaspass.com")
//   BREVO_SENDER_NAME    opcional, por defecto "chivaspass"
//   BREVO_SMS_SENDER     opcional, nombre del SMS (máx. 11 letras/números), por defecto "chivaspass"
// Si falta alguno, la notificación se omite y se registra en el log; la
// venta nunca falla por una notificación.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

export const escapeHtml = (v: unknown) =>
  String(v ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string))

const fmtDate = (d: string | Date | null | undefined) => {
  if (!d) return ""
  try {
    return new Date(d).toLocaleString("es-EC", {
      timeZone: "America/Guayaquil", dateStyle: "long", timeStyle: "short",
    })
  } catch { return String(d) }
}

const money = (n: number | string) => `$${Number(n).toFixed(2)}`

export interface TicketInfo {
  kind: "tour" | "business"
  status: "pagado" | "pendiente"
  customer: { name: string; email: string; phone?: string }
  title: string          // nombre del tour o del evento
  place: string          // chiva o negocio
  date: string | Date
  seats?: number[]
  quantity: number
  amount: number         // total pagado por el comprador (incluye cargo por servicio)
  subtotal?: number      // precio del vendedor
  fee?: number           // cargo por servicio al comprador
  paymentLabel: string   // "Tarjeta · 123456" | "Transferencia · TRX-1" | "Efectivo"
  ticketUrl: string
}

export function ticketEmail(t: TicketInfo): { subject: string; html: string } {
  const paid = t.status === "pagado"
  const subject = paid
    ? `Tu ticket para ${t.title}`
    : `Recibimos tu reserva para ${t.title}`

  const intro = paid
    ? "Tu pago fue confirmado. Este es tu ticket de ingreso."
    : "Recibimos tu comprobante. Te avisaremos cuando el vendedor lo verifique; el QR quedará activo en ese momento."

  const rows: [string, string][] = [
    [t.kind === "tour" ? "Tour" : "Evento", t.title],
    [t.kind === "tour" ? "Chiva" : "Lugar", t.place],
    [t.kind === "tour" ? "Salida" : "Fecha", fmtDate(t.date)],
    t.kind === "tour" && t.seats?.length
      ? ["Asientos", t.seats.join(", ")]
      : ["Entradas", String(t.quantity)],
    ...(t.fee && t.fee > 0
      ? [[t.kind === "tour" ? "Asientos" : "Entradas", money(t.subtotal ?? t.amount - t.fee)] as [string, string],
         ["Cargo por servicio", money(t.fee)] as [string, string]]
      : []),
    ["Total", money(t.amount)],
    ["Pago", t.paymentLabel],
  ]

  // Logo alojado en el sitio (los clientes de correo no cargan SVG ni fuentes)
  let origin = "https://chivaspass.com"
  try { if (t.ticketUrl) origin = new URL(t.ticketUrl).origin } catch { /* usa el valor por defecto */ }
  const logoUrl = `${origin}/img/brand/chivaspass-logo-white-on-orange.png`

  const html = `
  <div style="font-family:Arial,Helvetica,sans-serif;max-width:520px;margin:0 auto;color:#111827">
    <div style="background:#F77F00;color:#fff;padding:20px 24px;border-radius:12px 12px 0 0">
      <img src="${logoUrl}" alt="chivaspass" width="180" style="display:block;height:auto;border:0;margin:0 0 10px -6px" />
      <div style="font-size:20px;font-weight:700">${escapeHtml(subject)}</div>
    </div>
    <div style="border:1px solid #e5e7eb;border-top:0;padding:24px;border-radius:0 0 12px 12px">
      <p style="margin:0 0 12px">Hola ${escapeHtml(t.customer.name)},</p>
      <p style="margin:0 0 20px;color:#374151">${intro}</p>
      <table style="width:100%;border-collapse:collapse;font-size:14px">
        ${rows.map(([k, v]) => `
          <tr>
            <td style="padding:8px 0;color:#6b7280;border-bottom:1px solid #f3f4f6">${escapeHtml(k)}</td>
            <td style="padding:8px 0;text-align:right;font-weight:600;border-bottom:1px solid #f3f4f6">${escapeHtml(v)}</td>
          </tr>`).join("")}
      </table>
      ${t.ticketUrl ? `
      <p style="margin:24px 0 8px;text-align:center">
        <a href="${escapeHtml(t.ticketUrl)}" style="display:inline-block;background:#111827;color:#fff;text-decoration:none;padding:12px 20px;border-radius:10px;font-weight:600">
          Ver mi ticket y código QR
        </a>
      </p>
      <p style="margin:0;text-align:center;font-size:12px;color:#9ca3af">${escapeHtml(t.ticketUrl)}</p>` : ""}
      <p style="margin:24px 0 0;font-size:12px;color:#9ca3af">chivaspass · Baños de Agua Santa, Ecuador</p>
    </div>
  </div>`

  return { subject, html }
}

const BREVO_API = "https://api.brevo.com/v3"

export async function sendEmail(to: string, subject: string, html: string, toName = ""): Promise<boolean> {
  const key   = Deno.env.get("BREVO_API_KEY")
  const email = Deno.env.get("BREVO_SENDER_EMAIL")
  const name  = Deno.env.get("BREVO_SENDER_NAME") ?? "chivaspass"
  if (!key || !email) { console.warn("[notify] Brevo sin BREVO_API_KEY o BREVO_SENDER_EMAIL; correo omitido"); return false }
  try {
    const res = await fetch(`${BREVO_API}/smtp/email`, {
      method: "POST",
      headers: { "api-key": key, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        sender: { name, email },
        to: [toName ? { email: to, name: toName } : { email: to }],
        subject,
        htmlContent: html,
        tags: ["ticket"],
      }),
    })
    if (!res.ok) console.error("[notify] Brevo email error:", res.status, await res.text())
    return res.ok
  } catch (e) {
    console.error("[notify] Brevo email fetch failed:", (e as Error).message)
    return false
  }
}

// Números de Ecuador: "099 123 4567" o "0991234567" → "593991234567".
// Brevo espera el número con código de país, sin "+".
export function normalizePhone(phone: string): string | null {
  const raw = String(phone ?? "").trim()
  if (!raw) return null
  const digits = raw.replace(/\D/g, "")
  if (!digits) return null
  if (raw.startsWith("+") || digits.startsWith("593")) return digits.length >= 10 ? digits : null
  const local = digits.replace(/^0/, "")
  return local.length === 9 ? `593${local}` : null
}

export async function sendSms(phone: string, content: string): Promise<boolean> {
  const key    = Deno.env.get("BREVO_API_KEY")
  const sender = (Deno.env.get("BREVO_SMS_SENDER") ?? "chivaspass").replace(/[^A-Za-z0-9]/g, "").slice(0, 11)
  if (!key) { console.warn("[notify] Brevo sin BREVO_API_KEY; SMS omitido"); return false }
  const recipient = normalizePhone(phone)
  if (!recipient) { console.warn("[notify] teléfono inválido para SMS:", phone); return false }
  try {
    const res = await fetch(`${BREVO_API}/transactionalSMS/send`, {
      method: "POST",
      headers: { "api-key": key, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ sender, recipient, content, type: "transactional", tag: "venta" }),
    })
    if (!res.ok) console.error("[notify] Brevo SMS error:", res.status, await res.text())
    return res.ok
  } catch (e) {
    console.error("[notify] Brevo SMS fetch failed:", (e as Error).message)
    return false
  }
}

// Un SMS se cobra por cada 160 caracteres solo si todo el texto cabe en el
// alfabeto GSM-7; una sola "á" lo pasa a Unicode (70 caracteres por SMS).
// Por eso se quitan las tildes (la ñ sí es GSM) y se recorta el texto libre
// (tour y cliente) antes que las instrucciones.
const toGsm = (v: string) =>
  v.replace(/ñ/g, "\u0001").replace(/Ñ/g, "\u0002")
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/\u0001/g, "ñ").replace(/\u0002/g, "Ñ")
    .replace(/[^\x20-\x7EñÑ\n]/g, "")

const clip = (v: string, n: number) => (v.length > n ? v.slice(0, Math.max(0, n)).trimEnd() : v)

export function sellerSms(t: TicketInfo): string {
  const paid = t.status === "pagado"
  const qty = t.kind === "tour"
    ? (t.seats?.length && t.seats.length <= 4 ? `asientos ${t.seats.join(",")}` : `${t.seats?.length ?? t.quantity} asientos`)
    : `${t.quantity} entradas`
  const head = paid ? "chivaspass: Venta confirmada." : "chivaspass: Reserva por verificar."
  const end  = paid ? "" : " Revisa el comprobante en tu panel."
  const build = (title: string, name: string) => `${head} ${title}, ${qty}. ${name}. ${money(t.amount)}.${end}`

  // Lo que sobra de 160 se reparte entre el tour (60 %) y el cliente
  const room  = 160 - build("", "").length
  const title = clip(toGsm(t.title), Math.max(8, Math.floor(room * 0.6)))
  const name  = clip(toGsm(t.customer.name), Math.max(6, room - title.length))
  return build(title, name).slice(0, 160)
}

// Aviso al vendedor (dueño de chiva o negocio) por SMS al teléfono de su
// configuración; si no tiene, al WhatsApp registrado.
export async function notifySeller(
  supabase: SupabaseClient,
  ownerId: string,
  t: TicketInfo,
): Promise<void> {
  const { data } = await supabase
    .from("panel_settings")
    .select("contact_phone, contact_whatsapp")
    .eq("user_id", ownerId)
    .maybeSingle()
  const phone = data?.contact_phone || data?.contact_whatsapp
  if (!phone) return
  await sendSms(phone, sellerSms(t))
}

// Envía correo al comprador y aviso al vendedor sin bloquear la respuesta
// principal más de lo necesario. Los fallos solo se registran.
export async function notifyAll(supabase: SupabaseClient, ownerId: string, t: TicketInfo): Promise<void> {
  const { subject, html } = ticketEmail(t)
  await Promise.allSettled([
    sendEmail(t.customer.email, subject, html, t.customer.name),
    notifySeller(supabase, ownerId, t),
  ])
}
