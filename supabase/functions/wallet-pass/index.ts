// Pase del ticket para Apple Wallet y Google Wallet.
//
//   GET /functions/v1/wallet-pass?id=<uuid del ticket>&p=apple   → archivo .pkpass
//   GET /functions/v1/wallet-pass?id=<uuid del ticket>&p=google  → 302 a "Guardar en Google Wallet"
//
// Se abre con un enlace normal desde la página del ticket (el iPhone necesita
// una navegación directa para ofrecer "Agregar a Wallet"), por eso no exige
// JWT. Expone lo mismo que /ticket/:id: el UUID del ticket funciona como
// llave, y get_public_ticket solo devuelve tickets pagados, sin cédula,
// teléfono ni comprobante. Límite: 30 pedidos por minuto por IP.
//
// Sin los secrets de Apple o de Google responde 503 y la web no muestra el
// botón (VITE_WALLET_APPLE / VITE_WALLET_GOOGLE). Ver pkpass.ts y
// google_wallet.ts para la lista de secrets.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { appUrl, rateLimited } from "../_shared/http.ts"
import { escapeHtml } from "../_shared/notify.ts"
import { applePassJson, googleClass, googleObject, type PublicTicket, shortId, walletReady } from "../_shared/wallet.ts"
import { appleSignerFromEnv, buildPkpass } from "../_shared/pkpass.ts"
import { googleSaveUrl, googleSignerFromEnv } from "../_shared/google_wallet.ts"
import { PASS_IMAGES } from "./images.ts"

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const env = (k: string) => Deno.env.get(k)

// Respuesta para el navegador: página mínima en español con enlace al ticket.
function page(status: number, title: string, text: string, back: string): Response {
  const link = back ? `<p><a href="${escapeHtml(back)}">Volver a mi ticket</a></p>` : ""
  const html = `<!doctype html><html lang="es"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title>
<body style="font-family:system-ui,sans-serif;max-width:28rem;margin:4rem auto;padding:0 1.5rem;color:#111827">
<h1 style="font-size:1.25rem">${escapeHtml(title)}</h1><p style="color:#4b5563">${escapeHtml(text)}</p>${link}</body></html>`
  return new Response(html, {
    status,
    headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" },
  })
}

serve(async (req) => {
  if (req.method !== "GET") return new Response("Método no permitido.", { status: 405 })

  const url = new URL(req.url)
  const id = url.searchParams.get("id") ?? ""
  const platform = url.searchParams.get("p") ?? ""
  const base = appUrl(req)
  const ticketUrl = base && UUID_RE.test(id) ? `${base}/ticket/${id}` : ""

  if (!UUID_RE.test(id) || (platform !== "apple" && platform !== "google")) {
    return page(400, "Enlace no válido", "Abre el pase desde la página de tu ticket.", base)
  }

  const supabase = createClient(env("SUPABASE_URL")!, env("SUPABASE_SERVICE_ROLE_KEY")!)

  if (await rateLimited(supabase, req, "wallet-pass", 30)) {
    return page(429, "Demasiados intentos", "Espera un minuto y vuelve a intentarlo.", ticketUrl)
  }

  try {
    const { data, error } = await supabase.rpc("get_public_ticket", { p_id: id })
    if (error) throw new Error(`get_public_ticket: ${error.message}`)
    const ticket = data as PublicTicket | null
    if (!walletReady(ticket)) {
      return page(404, "Ticket no disponible",
        "El ticket no existe o el pago todavía no fue verificado por el vendedor.", ticketUrl)
    }

    if (platform === "apple") {
      const signer = appleSignerFromEnv(env)
      if (!signer) return page(503, "Apple Wallet no disponible", "Todavía no está activado. Usa el código QR de tu ticket.", ticketUrl)
      const pass = applePassJson(ticket, signer, ticketUrl)
      const file = await buildPkpass(pass, PASS_IMAGES, signer)
      return new Response(file as Uint8Array<ArrayBuffer>, {
        headers: {
          "Content-Type": "application/vnd.apple.pkpass",
          "Content-Disposition": `attachment; filename="chivaspass-${shortId(ticket.id)}.pkpass"`,
          "Cache-Control": "no-store",
        },
      })
    }

    const signer = googleSignerFromEnv(env)
    if (!signer) return page(503, "Google Wallet no disponible", "Todavía no está activado. Usa el código QR de tu ticket.", ticketUrl)
    const logoUrl = env("WALLET_LOGO_URL") || `${base || "https://chivaspass.com"}/img/brand/icon-512.png`
    const saveUrl = await googleSaveUrl(
      signer,
      googleClass(signer.issuerId),
      googleObject(ticket, signer.issuerId, { logoUrl, ticketUrl }),
      base ? [base] : [],
    )
    return new Response(null, { status: 302, headers: { Location: saveUrl, "Cache-Control": "no-store" } })
  } catch (e) {
    console.error("[wallet-pass]", platform, (e as Error).message)
    return page(500, "No pudimos crear el pase", "Intenta de nuevo en un momento o usa el código QR de tu ticket.", ticketUrl)
  }
})
