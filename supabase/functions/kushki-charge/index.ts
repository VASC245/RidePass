// Cobro con tarjeta vía Kushki (sandbox/producción según KUSHKI_ENV).
// El monto SIEMPRE sale de la base de datos; nunca del navegador.
//
// Entrada:
//   { token, type: 'tour',     payload: { assignedChivaId, seats: number[], customer } }
//   { token, type: 'business', payload: { eventId, quantity, customer } }
//
// Orden de operaciones (para que nunca haya cobro sin registro):
//   1. Sesión de pago 'pending' con el token (UNIQUE → idempotencia).
//   2. Reserva en BD en estado 'pendiente' (asientos 'reservado' / cupo tomado).
//   3. Cobro en Kushki.
//   4. Aprobado → confirmar (pagado/verificado). Rechazado → cancelar y liberar.
//      Si el paso 4 falla con el cobro ya aprobado, la sesión queda en
//      'needs_review' con el número de cargo para conciliar a mano.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { appUrl, corsFor, jsonResponse, mapDbError, parseCustomer, parseSeats, rateLimited } from "../_shared/http.ts"
import { notifyAll, type TicketInfo } from "../_shared/notify.ts"

serve(async (req) => {
  const cors = corsFor(req)
  const json = jsonResponse(cors)
  if (req.method === "OPTIONS") return new Response(null, { headers: cors })
  if (req.method !== "POST") return json({ success: false, message: "Método no permitido." }, 405)

  try {
    const { token, type, payload } = await req.json()
    if (!token || typeof token !== "string" || !type || !payload) {
      return json({ success: false, message: "Solicitud incompleta." }, 400)
    }

    const privateKey = Deno.env.get("KUSHKI_PRIVATE_KEY")
    if (!privateKey) {
      return json({ success: false, message: "Pasarela de pagos no configurada." }, 503)
    }
    const kushkiUrl = Deno.env.get("KUSHKI_ENV") === "production"
      ? "https://api.kushkipagos.com"
      : "https://api-uat.kushkipagos.com"

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    // ── Límite: 10 intentos de cobro por IP cada 10 minutos (frena pruebas de tarjetas) ──
    if (await rateLimited(supabase, req, "charge", 10, 600)) {
      return json({ success: false, message: "Demasiados intentos de pago. Espera unos minutos." }, 429)
    }

    // ── 1. Idempotencia: ¿ya vimos este token? ──
    const { data: existing } = await supabase
      .from("payment_sessions")
      .select("id, status, ticket_id, ticket_type, amount, provider_charge_id, metadata")
      .eq("provider_token", token)
      .maybeSingle()

    if (existing) {
      if (existing.status === "approved") {
        return json({
          success: true,
          duplicate: true,
          saleId:   existing.ticket_type === "tour" ? existing.ticket_id : undefined,
          ticketId: existing.ticket_type === "business" ? existing.ticket_id : undefined,
          chargeId: existing.provider_charge_id,
          amount:   Number(existing.amount),
          qrPayload: existing.metadata?.qr_payload ?? null,
          ticketUrl: existing.metadata?.ticket_url ?? null,
        })
      }
      if (existing.status === "pending") {
        return json({ success: false, message: "Este pago ya se está procesando." }, 409)
      }
      return json({ success: false, message: "Este token de pago ya fue usado. Ingresa la tarjeta de nuevo." }, 409)
    }

    const kind = type === "tour" ? "tour" : type === "business" ? "business" : null
    if (!kind) return json({ success: false, message: "Tipo de cobro no soportado." }, 400)

    // ── Validar entrada antes de crear nada ──
    const customer = parseCustomer(payload.customer)
    if (!customer) return json({ success: false, message: "Datos del comprador incompletos o inválidos." }, 400)

    const seats = kind === "tour" ? parseSeats(payload.seats) : null
    const qty   = kind === "business" ? Number(payload.quantity) : 0
    if (kind === "tour" && (!payload.assignedChivaId || !seats)) {
      return json({ success: false, message: "Datos del tour incompletos." }, 400)
    }
    if (kind === "business" && (!payload.eventId || !Number.isInteger(qty) || qty < 1 || qty > 50)) {
      return json({ success: false, message: "Datos del evento incompletos." }, 400)
    }

    // ── 1b. Sesión pending (UNIQUE provider_token) ──
    const { data: session, error: sErr } = await supabase.from("payment_sessions").insert({
      ticket_type: kind,
      amount: 0,
      provider: "kushki",
      provider_token: token,
      status: "pending",
      metadata: { customer_email: customer.email },
    }).select("id").single()
    if (sErr || !session) {
      const dup = sErr?.code === "23505"
      return json({ success: false, message: dup ? "Este pago ya se está procesando." : "No se pudo iniciar el pago." }, dup ? 409 : 500)
    }
    const sessionId = session.id
    const setSession = (patch: Record<string, unknown>) =>
      supabase.from("payment_sessions").update({ ...patch, updated_at: new Date().toISOString() }).eq("id", sessionId)

    // ── 2. Reservar en BD (pendiente) ──
    let reservation: Record<string, unknown> | null = null
    let ticketId = ""
    let amount = 0

    if (kind === "tour") {
      const { data, error } = await supabase.rpc("reserve_tour_seats", {
        p_assigned_chiva_id: String(payload.assignedChivaId),
        p_seats:             seats,
        p_customer:          customer,
        p_agency_id:         null,
        p_status:            "pendiente",
        p_payment_method:    "tarjeta",
        p_payment_ref:       null,
      })
      if (error || !data) {
        const mapped = mapDbError(error?.message ?? "")
        await setSession({ status: "error", metadata: { error: error?.message } })
        return json({ success: false, message: mapped.message }, mapped.status)
      }
      reservation = data
      ticketId = String(data.sale_id)
      amount = Number(data.amount)
    } else {
      const { data, error } = await supabase.rpc("create_business_ticket", {
        p_event_id:     String(payload.eventId),
        p_quantity:     qty,
        p_customer:     customer,
        p_status:       "pendiente",
        p_proof_number: null,
        p_proof_path:   null,
      })
      if (error || !data) {
        const mapped = mapDbError(error?.message ?? "")
        await setSession({ status: "error", metadata: { error: error?.message } })
        return json({ success: false, message: mapped.message }, mapped.status)
      }
      reservation = data
      ticketId = String(data.ticket_id)
      amount = Number(data.amount)
    }

    await setSession({ ticket_id: ticketId, amount })

    const release = async () => {
      if (kind === "tour") await supabase.rpc("cancel_sale", { p_sale_id: ticketId })
      else await supabase.rpc("set_business_ticket_status", { p_ticket_id: ticketId, p_status: "rechazado" })
    }

    // ── 3. Cobrar en Kushki ──
    let charge: { approved: boolean; body: Record<string, unknown> }
    try {
      charge = await chargeKushki(kushkiUrl, privateKey, token, amount, {
        type: kind, ticket_id: ticketId, session_id: sessionId,
      }, customer)
    } catch (e) {
      console.error("kushki fetch:", (e as Error).message)
      await release()
      await setSession({ status: "error", metadata: { error: (e as Error).message } })
      return json({ success: false, message: "No se pudo contactar a la pasarela. No se realizó ningún cobro." }, 502)
    }

    const chargeId = String(charge.body.ticketNumber ?? charge.body.transactionReference ?? "")

    if (!charge.approved) {
      await release()
      await setSession({ status: "declined", provider_charge_id: chargeId || null, metadata: charge.body })
      const msg = typeof charge.body.message === "string" ? charge.body.message : "Pago rechazado por la pasarela."
      return json({ success: false, message: msg }, 402)
    }

    // ── 4. Confirmar en BD ──
    const confirm = kind === "tour"
      ? await supabase.rpc("confirm_sale", { p_sale_id: ticketId, p_payment_ref: chargeId || "kushki" })
      : await supabase.rpc("set_business_ticket_status", { p_ticket_id: ticketId, p_status: "verificado", p_payment_ref: chargeId || "kushki" })

    const ticketUrl = appUrl(req) ? `${appUrl(req)}/ticket/${ticketId}` : ""

    if (confirm.error) {
      // Cobro aprobado pero no pudimos marcarlo: dejar rastro claro para conciliar.
      console.error("confirm after charge failed:", confirm.error.message, "charge:", chargeId)
      await setSession({
        status: "needs_review",
        provider_charge_id: chargeId || null,
        metadata: { ...charge.body, confirm_error: confirm.error.message, ticket_url: ticketUrl },
      })
      return json({
        success: false,
        needsReview: true,
        chargeId,
        message: `Tu pago fue aprobado (ref. ${chargeId}) pero hubo un problema al emitir el ticket. Guarda esta referencia y contáctanos; no se te cobrará dos veces.`,
      }, 500)
    }

    await setSession({
      status: "approved",
      provider_charge_id: chargeId || null,
      metadata: { ...charge.body, qr_payload: reservation!.qr_payload, ticket_url: ticketUrl },
    })

    // ── 5. Notificar (no bloquea el resultado) ──
    const info: TicketInfo = kind === "tour"
      ? {
          kind: "tour", status: "pagado", customer,
          title: String(reservation!.tour_title), place: String(reservation!.chiva_name),
          date: String(reservation!.departure_at), seats: seats!, quantity: seats!.length,
          amount, paymentLabel: `Tarjeta · ${chargeId || "Kushki"}`, ticketUrl,
        }
      : {
          kind: "business", status: "pagado", customer,
          title: String(reservation!.event_title), place: String(reservation!.business_name),
          date: String(reservation!.event_date), quantity: qty,
          amount, paymentLabel: `Tarjeta · ${chargeId || "Kushki"}`, ticketUrl,
        }
    await notifyAll(supabase, String(reservation!.owner_id), info)

    return json({
      success: true,
      saleId:   kind === "tour" ? ticketId : undefined,
      ticketId: kind === "business" ? ticketId : undefined,
      chargeId,
      amount,
      qrPayload: reservation!.qr_payload,
      ticketUrl,
    })
  } catch (err) {
    console.error("kushki-charge:", (err as Error).message)
    return json({ success: false, message: "Error interno al procesar el pago." }, 500)
  }
})

async function chargeKushki(
  baseUrl: string,
  privateKey: string,
  token: string,
  amount: number,
  metadata: Record<string, unknown>,
  customer: { email: string; name: string },
) {
  const res = await fetch(`${baseUrl}/card/v1/charges`, {
    method: "POST",
    headers: { "Private-Merchant-Id": privateKey, "Content-Type": "application/json" },
    body: JSON.stringify({
      token,
      amount: {
        subtotalIva: 0,
        subtotalIva0: Number(amount.toFixed(2)),
        iva: 0,
        ice: 0,
        currency: "USD",
      },
      metadata,
      contactDetails: { email: customer.email, firstName: customer.name },
      fullResponse: true,
    }),
  })
  const body = (await res.json().catch(() => ({}))) as Record<string, unknown>
  const details = (body.details ?? {}) as Record<string, unknown>
  const statusOk = !details.transactionStatus || String(details.transactionStatus).toUpperCase() === "APPROVAL"
  const approved = res.ok && statusOk && Boolean(body.ticketNumber || details.approvalCode)
  return { approved, body }
}
