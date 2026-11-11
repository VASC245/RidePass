// Textos de las notificaciones (correo al comprador y SMS al vendedor).
// Sin dependencias externas para poder probarlos con `deno test` sin red
// ni tipos de supabase-js. El envío vive en notify.ts.

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
  sellerAmount?: number  // lo que recibe el vendedor si no es el total (venta de agencia con sobreprecio)
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

// Un SMS se cobra por cada 160 caracteres solo si todo el texto cabe en el
// alfabeto GSM-7; una sola "á" lo pasa a Unicode (70 caracteres por SMS).
// Por eso se quitan las tildes (la ñ sí es GSM) y se recorta el texto libre
// (tour y cliente) antes que las instrucciones.
const toGsm = (v: string) =>
  v.normalize("NFC")
    .replace(/[^ñÑ]/g, (c) => c.normalize("NFD").replace(/[\u0300-\u036f]/g, ""))
    .replace(/[^\x20-\x7EñÑ\n]/g, "")

const clip = (v: string, n: number) => (v.length > n ? v.slice(0, Math.max(0, n)).trimEnd() : v)

export function sellerSms(t: TicketInfo): string {
  const paid = t.status === "pagado"
  const qty = t.kind === "tour"
    ? (t.seats?.length && t.seats.length <= 4 ? `asientos ${t.seats.join(",")}` : `${t.seats?.length ?? t.quantity} asientos`)
    : `${t.quantity} entradas`
  const head = paid ? "chivaspass: Venta confirmada." : "chivaspass: Reserva por verificar."
  const end  = paid ? "" : " Revisa el comprobante en tu panel."
  const build = (title: string, name: string) => `${head} ${title}, ${qty}. ${name}. ${money(t.sellerAmount ?? t.amount)}.${end}`

  // Lo que sobra de 160 se reparte entre el tour (60 %) y el cliente
  const room  = 160 - build("", "").length
  const title = clip(toGsm(t.title), Math.max(8, Math.floor(room * 0.6)))
  const name  = clip(toGsm(t.customer.name), Math.max(6, room - title.length))
  return build(title, name).slice(0, 160)
}
