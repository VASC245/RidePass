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
import { sellerSms, ticketEmail, type TicketInfo } from "./messages.ts"

export { escapeHtml, sellerSms, ticketEmail, type TicketInfo } from "./messages.ts"

const BREVO_API = "https://api.brevo.com/v3"
// Si Brevo tarda, la venta ya está hecha: no dejar al comprador esperando.
const BREVO_TIMEOUT_MS = 8000

export async function sendEmail(
  to: string, subject: string, html: string, toName = "",
  opts: { replyTo?: string; tag?: string } = {},
): Promise<boolean> {
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
        ...(opts.replyTo ? { replyTo: { email: opts.replyTo } } : {}),
        subject,
        htmlContent: html,
        tags: [opts.tag ?? "ticket"],
      }),
      signal: AbortSignal.timeout(BREVO_TIMEOUT_MS),
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
  if (!recipient) { console.warn("[notify] teléfono inválido para SMS"); return false }
  try {
    const res = await fetch(`${BREVO_API}/transactionalSMS/send`, {
      method: "POST",
      headers: { "api-key": key, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ sender, recipient, content, type: "transactional", tag: "venta" }),
      signal: AbortSignal.timeout(BREVO_TIMEOUT_MS),
    })
    if (!res.ok) console.error("[notify] Brevo SMS error:", res.status, await res.text())
    return res.ok
  } catch (e) {
    console.error("[notify] Brevo SMS fetch failed:", (e as Error).message)
    return false
  }
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
