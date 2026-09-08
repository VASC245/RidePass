// Notificaciones server-to-server: correo al comprador (Resend) y WhatsApp
// al vendedor (Twilio). Nunca se exponen como endpoint: solo las llaman
// public-reserve y kushki-charge después de registrar la venta.
//
// Secrets necesarios:
//   RESEND_API_KEY, RESEND_FROM (ej. "ChivaPass <noreply@smartchiva.com>")
//   TWILIO_SID, TWILIO_TOKEN, TWILIO_WHATSAPP_FROM (ej. "whatsapp:+14155238886")
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
  amount: number
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
    ["Total", money(t.amount)],
    ["Pago", t.paymentLabel],
  ]

  // Logo alojado en el sitio (los clientes de correo no cargan SVG ni fuentes)
  let origin = "https://chivaspass.netlify.app"
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

export async function sendEmail(to: string, subject: string, html: string): Promise<boolean> {
  const key  = Deno.env.get("RESEND_API_KEY")
  const from = Deno.env.get("RESEND_FROM") ?? "ChivaPass <noreply@smartchiva.com>"
  if (!key) { console.warn("[notify] RESEND_API_KEY no configurado; correo omitido"); return false }
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ from, to, subject, html }),
    })
    if (!res.ok) console.error("[notify] Resend error:", res.status, await res.text())
    return res.ok
  } catch (e) {
    console.error("[notify] Resend fetch failed:", (e as Error).message)
    return false
  }
}

export async function sendWhatsApp(phone: string, body: string): Promise<boolean> {
  const sid   = Deno.env.get("TWILIO_SID")
  const token = Deno.env.get("TWILIO_TOKEN")
  const from  = Deno.env.get("TWILIO_WHATSAPP_FROM")
  if (!sid || !token || !from) { console.warn("[notify] Twilio no configurado; WhatsApp omitido"); return false }

  const digits = String(phone).replace(/[^\d+]/g, "")
  if (!digits) return false
  const normalized = digits.startsWith("+") ? digits : `+593${digits.replace(/^0/, "")}`

  try {
    const res = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${sid}:${token}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ From: from, To: `whatsapp:${normalized}`, Body: body }).toString(),
    })
    if (!res.ok) console.error("[notify] Twilio error:", res.status, await res.text())
    return res.ok
  } catch (e) {
    console.error("[notify] Twilio fetch failed:", (e as Error).message)
    return false
  }
}

// Aviso al vendedor (dueño de chiva o negocio) por WhatsApp.
export async function notifySeller(
  supabase: SupabaseClient,
  ownerId: string,
  t: TicketInfo,
): Promise<void> {
  const { data } = await supabase
    .from("panel_settings")
    .select("contact_whatsapp")
    .eq("user_id", ownerId)
    .maybeSingle()
  const phone = data?.contact_whatsapp
  if (!phone) return

  const paid = t.status === "pagado"
  const what = t.kind === "tour"
    ? `${t.title} · asientos ${t.seats?.join(", ") ?? t.quantity}`
    : `${t.title} · ${t.quantity} entrada(s)`

  const body = [
    paid ? `Venta confirmada: ${what}` : `Nueva reserva pendiente: ${what}`,
    `${t.customer.name}${t.customer.phone ? ` · ${t.customer.phone}` : ""}`,
    `${money(t.amount)} · ${t.paymentLabel}`,
    paid ? "El pago ya está aprobado." : "Entra a tu panel para verificar el comprobante.",
  ].join("\n")

  await sendWhatsApp(phone, body)
}

// Envía correo al comprador y aviso al vendedor sin bloquear la respuesta
// principal más de lo necesario. Los fallos solo se registran.
export async function notifyAll(supabase: SupabaseClient, ownerId: string, t: TicketInfo): Promise<void> {
  const { subject, html } = ticketEmail(t)
  await Promise.allSettled([
    sendEmail(t.customer.email, subject, html),
    notifySeller(supabase, ownerId, t),
  ])
}
