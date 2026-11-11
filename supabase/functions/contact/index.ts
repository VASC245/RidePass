// Formulario de contacto del sitio público (/contacto).
// Envía la solicitud por correo (Brevo) a CONTACT_EMAIL o, si no está, a
// BREVO_SENDER_EMAIL, con reply-to al correo de quien escribe.
//
// Entrada: { nombre, apellidos, email, phone, negocio, pais, tours, tipo, motivo, mensaje?, turnstileToken? }
// Respuesta: { success, message? }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { corsFor, jsonResponse, rateLimited, verifyTurnstile } from "../_shared/http.ts"
import { escapeHtml, sendEmail } from "../_shared/notify.ts"

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const FIELDS: Array<[string, string]> = [
  ["nombre", "Nombre"],
  ["apellidos", "Apellidos"],
  ["email", "Correo"],
  ["phone", "Teléfono / WhatsApp"],
  ["negocio", "Chiva o negocio"],
  ["pais", "País"],
  ["tours", "Tours al mes"],
  ["tipo", "Tipo de negocio"],
  ["motivo", "Motivo"],
]

serve(async (req) => {
  const cors = corsFor(req)
  const json = jsonResponse(cors)
  if (req.method === "OPTIONS") return new Response(null, { headers: cors })
  if (req.method !== "POST") return json({ success: false, message: "Método no permitido." }, 405)

  try {
    const body = await req.json()
    const str = (v: unknown, max = 120) => String(v ?? "").trim().slice(0, max)
    const data: Record<string, string> = {}
    for (const [key] of FIELDS) data[key] = str(body?.[key])
    const mensaje = str(body?.mensaje, 2000)

    if (FIELDS.some(([key]) => !data[key]) || !EMAIL_RE.test(data.email)) {
      return json({ success: false, message: "Completa todos los campos obligatorios." }, 400)
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )
    if (await rateLimited(supabase, req, "contact", 5, 3600)) {
      return json({ success: false, message: "Ya recibimos varias solicitudes desde esta conexión. Intenta más tarde." }, 429)
    }
    if (!(await verifyTurnstile(req, body?.turnstileToken))) {
      return json({ success: false, message: "No pudimos verificar que no eres un robot. Recarga la página e intenta de nuevo." }, 403)
    }

    const to = Deno.env.get("CONTACT_EMAIL") ?? Deno.env.get("BREVO_SENDER_EMAIL")
    if (!to) {
      console.error("[contact] sin CONTACT_EMAIL ni BREVO_SENDER_EMAIL")
      return json({ success: false, message: "No pudimos enviar tu mensaje. Escríbenos por WhatsApp o correo." }, 503)
    }

    const rows = FIELDS.map(([key, label]) =>
      `<tr><td style="padding:4px 12px 4px 0;color:#6B7280">${label}</td><td style="padding:4px 0;color:#111827">${escapeHtml(data[key])}</td></tr>`
    ).join("")
    const html = `<div style="font-family:Arial,sans-serif;font-size:14px">
      <p>Nueva solicitud desde el formulario de contacto de chivaspass.</p>
      <table>${rows}</table>
      ${mensaje ? `<p style="margin-top:16px;white-space:pre-wrap">${escapeHtml(mensaje)}</p>` : ""}
    </div>`
    const subject = `Contacto: ${data.motivo} · ${data.negocio}`.slice(0, 150)

    const ok = await sendEmail(to, subject, html, "", { replyTo: data.email, tag: "contacto" })
    if (!ok) {
      return json({ success: false, message: "No pudimos enviar tu mensaje. Escríbenos por WhatsApp o correo." }, 502)
    }
    return json({ success: true })
  } catch (err) {
    console.error("contact:", (err as Error).message)
    return json({ success: false, message: "Error interno al enviar el mensaje." }, 500)
  }
})
