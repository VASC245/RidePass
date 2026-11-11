// Prepara un cobro con tarjeta en PayPhone con Split de Pagos.
// El monto y el reparto SIEMPRE salen de la base de datos.
//
// Entrada (igual que kushki-charge, sin token de tarjeta):
//   { type: 'tour',     payload: { assignedChivaId, seats: number[], customer } }
//   { type: 'business', payload: { eventId, quantity, customer } }
// Salida: { success, payUrl, clientTransactionId }
//
// Orden:
//   1. Sesión 'pending' con un clientTransactionId nuevo (provider_token UNIQUE).
//   2. Reserva en BD en estado 'pendiente' con payment_method 'tarjeta'.
//   3. Receptores del split desde la base (payphone_split_recipients) y
//      cálculo en centavos con el tope seller <= total - comisión PayPhone.
//   4. transferTo cifrado y Prepare en PayPhone. Si algo falla, se libera la
//      reserva y no se cobra nada.
// El cobro se confirma en payphone-confirm cuando el comprador vuelve.
//
// Secrets: PAYPHONE_TOKEN, PAYPHONE_STORE_ID, PAYPHONE_ENCRYPTION_KEY
// Opcional: PAYPHONE_SPLIT_AMOUNT_AS=number (si PayPhone pide Amount numérico)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { appUrl, corsFor, jsonResponse, mapDbError, parseCustomer, parseSeats, rateLimited } from "../_shared/http.ts"
import { encryptTransferTo, newClientTransactionId, planSplit, preparePayment, transferToJson } from "../_shared/payphone.ts"

const SPLIT_MESSAGES: Record<string, string> = {
  MULTI_RECIPIENT_DISABLED: "Esta venta todavía no se puede pagar con PayPhone. Elige otro método de pago.",
  SPLIT_EXCEEDS_AVAILABLE: "Esta venta no se puede pagar con PayPhone. Elige otro método de pago.",
  INVALID_RECIPIENT: "El vendedor tiene mal configurada su cuenta PayPhone. Elige otro método de pago.",
  NO_RECIPIENTS: "El vendedor no recibe pagos con PayPhone. Elige otro método de pago.",
}

serve(async (req) => {
  const cors = corsFor(req)
  const json = jsonResponse(cors)
  if (req.method === "OPTIONS") return new Response(null, { headers: cors })
  if (req.method !== "POST") return json({ success: false, message: "Método no permitido." }, 405)

  try {
    const token = Deno.env.get("PAYPHONE_TOKEN")
    const storeId = Deno.env.get("PAYPHONE_STORE_ID")
    const encKey = Deno.env.get("PAYPHONE_ENCRYPTION_KEY")
    const base = appUrl(req)
    if (!token || !storeId || !encKey || !base) {
      return json({ success: false, message: "Pago con PayPhone no configurado." }, 503)
    }
    const amountAs = Deno.env.get("PAYPHONE_SPLIT_AMOUNT_AS") === "number" ? "number" : "string"

    const { type, payload } = await req.json().catch(() => ({}))
    const kind = type === "tour" ? "tour" : type === "business" ? "business" : null
    if (!kind || !payload) return json({ success: false, message: "Solicitud incompleta." }, 400)

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    // Mismo límite que el cobro con Kushki: 10 intentos por IP cada 10 minutos.
    if (await rateLimited(supabase, req, "charge", 10, 600)) {
      return json({ success: false, message: "Demasiados intentos de pago. Espera unos minutos." }, 429)
    }

    // ── Validar entrada antes de crear nada ──
    const customer = parseCustomer(payload.customer)
    if (!customer) return json({ success: false, message: "Datos del comprador incompletos o inválidos." }, 400)
    const seats = kind === "tour" ? parseSeats(payload.seats) : null
    const qty = kind === "business" ? Number(payload.quantity) : 0
    if (kind === "tour" && (!payload.assignedChivaId || !seats)) {
      return json({ success: false, message: "Datos del tour incompletos." }, 400)
    }
    if (kind === "business" && (!payload.eventId || !Number.isInteger(qty) || qty < 1 || qty > 50)) {
      return json({ success: false, message: "Datos del evento incompletos." }, 400)
    }

    // ── 1. Sesión pending ──
    const clientTx = newClientTransactionId()
    const { data: session, error: sErr } = await supabase.from("payment_sessions").insert({
      ticket_type: kind,
      amount: 0,
      provider: "payphone",
      provider_token: clientTx,
      status: "pending",
      metadata: { customer_email: customer.email },
    }).select("id").single()
    if (sErr || !session) return json({ success: false, message: "No se pudo iniciar el pago." }, 500)

    const sessionId = session.id
    let meta: Record<string, unknown> = { customer_email: customer.email }
    const setSession = (patch: Record<string, unknown>) => {
      if (patch.metadata) meta = { ...meta, ...(patch.metadata as Record<string, unknown>) }
      return supabase.from("payment_sessions")
        .update({ ...patch, metadata: meta, updated_at: new Date().toISOString() })
        .eq("id", sessionId)
    }
    const fail = async (status: "error" | "declined", detail: Record<string, unknown>, message: string, http: number) => {
      await setSession({ status, metadata: detail })
      return json({ success: false, message }, http)
    }

    // ── 2. Reserva pendiente ──
    const rpc = kind === "tour"
      ? await supabase.rpc("reserve_tour_seats", {
          p_assigned_chiva_id: String(payload.assignedChivaId),
          p_seats: seats,
          p_customer: customer,
          p_agency_id: null,
          p_status: "pendiente",
          p_payment_method: "tarjeta",
          p_payment_ref: null,
        })
      : await supabase.rpc("create_business_ticket", {
          p_event_id: String(payload.eventId),
          p_quantity: qty,
          p_customer: customer,
          p_status: "pendiente",
          p_proof_number: null,
          p_proof_path: null,
        })
    if (rpc.error || !rpc.data) {
      const mapped = mapDbError(rpc.error?.message ?? "")
      return await fail("error", { error: rpc.error?.message }, mapped.message, mapped.status)
    }
    const reservation = rpc.data as Record<string, unknown>
    const ticketId = String(kind === "tour" ? reservation.sale_id : reservation.ticket_id)
    const total = Number(reservation.total_charged ?? reservation.amount)
    await setSession({ ticket_id: ticketId, amount: total })

    const release = async () => {
      if (kind === "tour") await supabase.rpc("cancel_sale", { p_sale_id: ticketId })
      else await supabase.rpc("set_business_ticket_status", { p_ticket_id: ticketId, p_status: "rechazado" })
    }

    // ── 3. Split desde la base ──
    const rec = await supabase.rpc("payphone_split_recipients", { p_ticket_type: kind, p_ticket_id: ticketId })
    if (rec.error || !rec.data) {
      await release()
      const mapped = mapDbError(rec.error?.message ?? "")
      return await fail("error", { error: rec.error?.message ?? "split_recipients" }, mapped.message, mapped.status)
    }
    const { data: pctRow } = await supabase.from("app_settings").select("value").eq("key", "payphone_commission_pct").maybeSingle()
    const commissionPct = Number(pctRow?.value ?? 5.75)

    const split = planSplit(total, commissionPct, rec.data.recipients ?? [], false)
    if (!split.ok) {
      await release()
      console.error("payphone split:", split.error, split.detail)
      return await fail("error", { error: split.error, split_detail: split.detail },
        SPLIT_MESSAGES[split.error] ?? "No se pudo preparar el pago.", 409)
    }

    // ── 4. Prepare en PayPhone ──
    let prepared
    try {
      const transferTo = await encryptTransferTo(transferToJson(split.plan, amountAs), encKey)
      prepared = await preparePayment({
        token,
        storeId,
        clientTransactionId: clientTx,
        totalCents: split.plan.total_cents,
        reference: kind === "tour"
          ? `chivaspass · ${reservation.tour_title}`
          : `chivaspass · ${reservation.event_title}`,
        responseUrl: `${base}/pago/resultado`,
        cancellationUrl: `${base}/pago/resultado?cancelado=1&tx=${clientTx}`,
        email: customer.email,
        transferTo,
      })
    } catch (e) {
      await release()
      console.error("payphone prepare:", (e as Error).message)
      return await fail("error", { error: (e as Error).message },
        "No se pudo contactar a PayPhone. No se realizó ningún cobro.", 502)
    }

    if (!prepared.ok) {
      await release()
      console.error("payphone prepare rechazado:", prepared.status, JSON.stringify(prepared.body))
      return await fail("error", { error: "prepare_failed", prepare_status: prepared.status, prepare_body: prepared.body },
        "PayPhone no aceptó el pago. No se realizó ningún cobro.", 502)
    }

    await setSession({
      metadata: {
        payphone_payment_id: prepared.paymentId,
        split: { ...split.plan, recipients: split.plan.recipients.map((r) => ({ role: r.role, type: r.type, amount_cents: r.amount_cents })) },
        // Para emitir el ticket y notificar al confirmar
        customer,
        seats,
        quantity: kind === "tour" ? seats!.length : qty,
        reservation,
      },
    })

    return json({ success: true, payUrl: prepared.payWithCard, clientTransactionId: clientTx })
  } catch (err) {
    console.error("payphone-prepare:", (err as Error).message)
    return json({ success: false, message: "Error interno al preparar el pago." }, 500)
  }
})
