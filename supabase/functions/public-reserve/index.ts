// Reserva de tours y eventos SIN tarjeta (transferencia o efectivo).
// Única vía de escritura para ventas: las tablas ya no aceptan inserts
// desde el navegador. Toda la lógica de asientos/cupos vive en las
// funciones SQL reserve_tour_seats / create_business_ticket (atómicas).
//
// Entrada:
//   { type: 'upload-url', payload: { fileName, contentType, turnstileToken? } }
//   { type: 'tour',     payload: { assignedChivaId, seats: number[], customer, proofNumber?, proofPath?, paymentMethod? } }
//   { type: 'business', payload: { eventId, quantity, customer, proofNumber?, proofPath? } }
//
// El bucket 'comprobantes' ya no acepta subidas directas: el navegador pide
// aquí una URL firmada (con captcha y límite por IP para el público) y sube
// el archivo con ella. Así cada reserva por transferencia cuesta un captcha.
//
// Quién llama y qué pasa:
//   - Invitado / cliente (anon o rol cliente): requiere comprobante → venta 'pendiente'.
//   - Agencia (JWT con rol agencia): requiere comprobante → venta 'pendiente' con agency_id.
//   - Dueño de la salida (JWT rol dueño, paymentMethod 'efectivo'): venta 'pagado' directa.
//
// Respuesta: { success, saleId | ticketId, amount, qrPayload, ticketUrl, status }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import {
  appUrl, corsFor, jsonResponse, mapDbError, parseCustomer, parseSeats, rateLimited, verifyTurnstile,
} from "../_shared/http.ts"
import { notifyAll, type TicketInfo } from "../_shared/notify.ts"

type Caller = { id: string; role: string; fullName: string } | null

const PANEL_ROLES = ["dueño", "agencia", "negocio", "conductor"]
const PROOF_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "application/pdf": "pdf",
}
// Un turista no necesita más asientos por reserva; las agencias y el dueño sí.
const PUBLIC_MAX_SEATS = 20

serve(async (req) => {
  const cors = corsFor(req)
  const json = jsonResponse(cors)
  if (req.method === "OPTIONS") return new Response(null, { headers: cors })
  if (req.method !== "POST") return json({ success: false, message: "Método no permitido." }, 405)

  try {
    const { type, payload } = await req.json()
    if (!type || !payload) return json({ success: false, message: "Solicitud incompleta." }, 400)

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    // ── Identificar quién llama (opcional) ──
    const caller = await resolveCaller(req, supabase)
    const panelUser = Boolean(caller && PANEL_ROLES.includes(caller.role))

    // ══════════════════ URL FIRMADA PARA EL COMPROBANTE ══════════════════
    if (type === "upload-url") {
      if (await rateLimited(supabase, req, "upload", panelUser ? 60 : 8, 600)) {
        return json({ success: false, message: "Demasiados intentos desde esta conexión. Espera unos minutos." }, 429)
      }
      if (!panelUser && !(await verifyTurnstile(req, payload.turnstileToken))) {
        return json({ success: false, message: "No pudimos verificar que no eres un robot. Recarga la página e intenta de nuevo." }, 403)
      }
      const ext = PROOF_TYPES[String(payload.contentType ?? "")]
      if (!ext) return json({ success: false, message: "Sube una imagen (JPG, PNG, WEBP) o un PDF." }, 400)

      const prefix = caller ? caller.id : "public"
      const path = `comprobantes/${prefix}_${crypto.randomUUID()}.${ext}`
      const { data: signed, error: signErr } = await supabase.storage
        .from("comprobantes").createSignedUploadUrl(path)
      if (signErr || !signed) {
        console.error("createSignedUploadUrl:", signErr?.message)
        return json({ success: false, message: "No se pudo preparar la subida. Intenta de nuevo." }, 500)
      }
      return json({ success: true, path, token: signed.token })
    }

    // ── Límite: 10 reservas por IP cada 10 minutos y 30 al día ──
    if (
      await rateLimited(supabase, req, "reserve", panelUser ? 60 : 10, 600) ||
      (!panelUser && await rateLimited(supabase, req, "reserve-day", 30, 86400))
    ) {
      return json({ success: false, message: "Demasiadas reservas desde esta conexión. Espera unos minutos." }, 429)
    }

    const proofNumber = String(payload.proofNumber ?? "").trim().slice(0, 60)
    const proofPath   = String(payload.proofPath ?? "").trim()
    const hasProof    = Boolean(proofNumber && proofPath && proofPath.startsWith("comprobantes/"))

    // El comprobante debe existir en el bucket y no haberse usado en otra
    // reserva: sin esto se podían bloquear asientos con rutas inventadas.
    if (hasProof) {
      const check = await validateProof(supabase, proofPath)
      if (check) return json({ success: false, message: check }, 400)
    }

    // ══════════════════ TOUR EN CHIVA ══════════════════
    if (type === "tour") {
      const seats    = parseSeats(payload.seats, panelUser ? 60 : PUBLIC_MAX_SEATS)
      const customer = parseCustomer(payload.customer)
      const assignedChivaId = String(payload.assignedChivaId ?? "")
      if (!assignedChivaId || !seats || !customer) {
        return json({ success: false, message: "Datos de la reserva incompletos o inválidos." }, 400)
      }

      // ¿Venta en efectivo del propio dueño?
      let cashSale = false
      if (caller?.role === "dueño" && payload.paymentMethod === "efectivo") {
        const { data: ac } = await supabase
          .from("assigned_chivas").select("owner_id").eq("id", assignedChivaId).maybeSingle()
        cashSale = ac?.owner_id === caller.id
        if (!cashSale) return json({ success: false, message: "Esta salida no es tuya." }, 403)
      }

      if (!cashSale && !hasProof) {
        return json({ success: false, message: "Falta el número o el archivo del comprobante." }, 400)
      }

      const agencyId = caller?.role === "agencia" ? caller.id : null

      const { data: sale, error } = await supabase.rpc("reserve_tour_seats", {
        p_assigned_chiva_id: assignedChivaId,
        p_seats:             seats,
        p_customer:          customer,
        p_agency_id:         agencyId,
        p_status:            cashSale ? "pagado" : "pendiente",
        p_payment_method:    cashSale ? "efectivo" : "transferencia",
        p_payment_ref:       cashSale ? null : proofNumber,
      })
      if (error || !sale) {
        const mapped = mapDbError(error?.message ?? "")
        console.error("reserve_tour_seats:", error?.message)
        return json({ success: false, message: mapped.message }, mapped.status)
      }

      if (!cashSale) {
        const { error: ppErr } = await supabase.from("pending_payments").insert({
          assigned_chiva_id:  assignedChivaId,
          owner_id:           sale.owner_id,
          agency_id:          agencyId,
          numero_comprobante: proofNumber,
          comprobante_path:   proofPath,
          comprobante_url:    proofPath,
          estado:             "pendiente",
          agency_name:        agencyId ? caller!.fullName : `${customer.name} (público)`,
          boletos_vendidos:   seats.length,
          monto_owner:        sale.amount,
          monto_agencia:      0,
          sale_id:            sale.sale_id,
        })
        if (ppErr) {
          // Sin comprobante registrado la venta no se puede verificar: revertir.
          console.error("pending_payments insert:", ppErr.message)
          await supabase.rpc("cancel_sale", { p_sale_id: sale.sale_id })
          return json({ success: false, message: "No se pudo registrar el comprobante. Intenta de nuevo." }, 500)
        }
      }

      const ticketUrl = appUrl(req) ? `${appUrl(req)}/ticket/${sale.sale_id}` : ""
      const info: TicketInfo = {
        kind: "tour",
        status: cashSale ? "pagado" : "pendiente",
        customer,
        title: sale.tour_title,
        place: sale.chiva_name,
        date:  sale.departure_at,
        seats,
        quantity: seats.length,
        amount: Number(sale.total_charged ?? sale.amount),
        subtotal: Number(sale.amount),
        fee: Number(sale.fee ?? 0),
        paymentLabel: cashSale ? "Efectivo" : `Transferencia · ${proofNumber}`,
        ticketUrl,
      }
      await notifyAll(supabase, sale.owner_id, info)

      return json({
        success: true,
        saleId: sale.sale_id,
        amount: Number(sale.amount),
        fee: Number(sale.fee ?? 0),
        total: Number(sale.total_charged ?? sale.amount),
        qrPayload: sale.qr_payload,
        ticketUrl,
        status: info.status,
      })
    }

    // ══════════════════ EVENTO DE NEGOCIO ══════════════════
    if (type === "business") {
      const qty      = Number(payload.quantity)
      const customer = parseCustomer(payload.customer)
      const eventId  = String(payload.eventId ?? "")
      if (!eventId || !Number.isInteger(qty) || qty < 1 || qty > (panelUser ? 50 : PUBLIC_MAX_SEATS) || !customer) {
        return json({ success: false, message: "Datos de la reserva incompletos o inválidos." }, 400)
      }
      if (!hasProof) {
        return json({ success: false, message: "Falta el número o el archivo del comprobante." }, 400)
      }

      const { data: tk, error } = await supabase.rpc("create_business_ticket", {
        p_event_id:     eventId,
        p_quantity:     qty,
        p_customer:     customer,
        p_status:       "pendiente",
        p_proof_number: proofNumber,
        p_proof_path:   proofPath,
      })
      if (error || !tk) {
        const mapped = mapDbError(error?.message ?? "")
        console.error("create_business_ticket:", error?.message)
        return json({ success: false, message: mapped.message }, mapped.status)
      }

      const ticketUrl = appUrl(req) ? `${appUrl(req)}/ticket/${tk.ticket_id}` : ""
      const info: TicketInfo = {
        kind: "business",
        status: "pendiente",
        customer,
        title: tk.event_title,
        place: tk.business_name,
        date:  tk.event_date,
        quantity: qty,
        amount: Number(tk.total_charged ?? tk.amount),
        subtotal: Number(tk.amount),
        fee: Number(tk.fee ?? 0),
        paymentLabel: `Transferencia · ${proofNumber}`,
        ticketUrl,
      }
      await notifyAll(supabase, tk.owner_id, info)

      return json({
        success: true,
        ticketId: tk.ticket_id,
        amount: Number(tk.amount),
        fee: Number(tk.fee ?? 0),
        total: Number(tk.total_charged ?? tk.amount),
        qrPayload: tk.qr_payload,
        ticketUrl,
        status: "pendiente",
      })
    }

    return json({ success: false, message: "Tipo de reserva no soportado." }, 400)
  } catch (err) {
    console.error("public-reserve:", (err as Error).message)
    return json({ success: false, message: "Error interno al procesar la reserva." }, 500)
  }
})

// Devuelve un mensaje de error si el comprobante no es válido, o null si lo es.
// deno-lint-ignore no-explicit-any
async function validateProof(supabase: any, proofPath: string): Promise<string | null> {
  if (proofPath.length > 200 || proofPath.includes("..")) return "Ruta del comprobante inválida."
  const { error } = await supabase.storage.from("comprobantes").createSignedUrl(proofPath, 60)
  if (error) return "No encontramos el archivo del comprobante. Súbelo de nuevo."
  const [pp, bt] = await Promise.all([
    supabase.from("pending_payments").select("id").eq("comprobante_path", proofPath).limit(1),
    supabase.from("business_tickets").select("id").eq("payment_proof_path", proofPath).limit(1),
  ])
  if (pp.data?.length || bt.data?.length) return "Este comprobante ya fue usado en otra reserva."
  return null
}

// Lee el JWT del usuario (si lo hay) y devuelve su rol desde public.users.
// deno-lint-ignore no-explicit-any
async function resolveCaller(req: Request, supabase: any): Promise<Caller> {
  const auth = req.headers.get("authorization") ?? ""
  const jwt = auth.replace(/^Bearer\s+/i, "").trim()
  if (!jwt || jwt === Deno.env.get("SUPABASE_ANON_KEY")) return null
  const { data, error } = await supabase.auth.getUser(jwt)
  if (error || !data?.user) return null
  const { data: profile } = await supabase
    .from("users").select("id, role, full_name").eq("id", data.user.id).maybeSingle()
  if (!profile) return null
  return { id: String(profile.id), role: String(profile.role), fullName: String(profile.full_name ?? "") }
}
