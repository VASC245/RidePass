// Confirma un cobro de PayPhone cuando el comprador vuelve a /pago/resultado.
//
// Entrada:
//   { id: number, clientTransactionId: string }     ← parámetros de responseUrl
//   { clientTransactionId: string, cancelled: true } ← el comprador canceló
//
// Idempotente: se puede llamar varias veces (recargas). Una sola llamada a
// la vez procesa cada sesión (payphone_claim_session). Si la sesión ya está
// aprobada devuelve el mismo ticket.
//
// Orden:
//   1. Reclamar la sesión y leer el estado de la reserva en la misma operación.
//   2. Si la reserva ya no está pendiente (el cron la liberó) NO se confirma en
//      PayPhone: sin confirmación, PayPhone revierte el cobro en 5 minutos.
//   3. V2/Confirm desde el servidor. Aprobada y con el monto esperado →
//      confirmar en BD, sesión 'approved', notificar. Cancelada → liberar.
//   4. Cobro aprobado pero falla la BD → 'needs_review' con la referencia.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { appUrl, corsFor, jsonResponse, rateLimited } from "../_shared/http.ts"
import { notifyAll, type TicketInfo } from "../_shared/notify.ts"
import { confirmPayment, safeConfirmBody } from "../_shared/payphone.ts"

const TX_RE = /^[a-f0-9]{32}$/

serve(async (req) => {
  const cors = corsFor(req)
  const json = jsonResponse(cors)
  if (req.method === "OPTIONS") return new Response(null, { headers: cors })
  if (req.method !== "POST") return json({ success: false, message: "Método no permitido." }, 405)

  try {
    const token = Deno.env.get("PAYPHONE_TOKEN")
    if (!token) return json({ success: false, message: "Pago con PayPhone no configurado." }, 503)

    const body = await req.json().catch(() => ({}))
    const clientTx = String(body.clientTransactionId ?? "").toLowerCase()
    const payphoneId = Number(body.id)
    const cancelled = body.cancelled === true
    if (!TX_RE.test(clientTx) || (!cancelled && (!Number.isSafeInteger(payphoneId) || payphoneId <= 0))) {
      return json({ success: false, message: "Enlace de pago inválido." }, 400)
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    )

    if (await rateLimited(supabase, req, "payphone-confirm", 30, 600)) {
      return json({ success: false, message: "Demasiados intentos. Espera unos minutos y recarga la página." }, 429)
    }

    // ── 1. Reclamar ──
    const { data: claim, error: cErr } = await supabase.rpc("payphone_claim_session", { p_client_tx: clientTx })
    if (cErr || !claim) {
      console.error("payphone claim:", cErr?.message)
      return json({ success: false, retry: true, message: "No pudimos revisar tu pago. Recarga la página en un momento." }, 500)
    }

    const s = claim.session as Record<string, unknown> | undefined
    const m = (s?.metadata ?? {}) as Record<string, unknown>
    const kind = s?.ticket_type === "business" ? "business" : "tour"
    const ticketId = String(s?.ticket_id ?? "")

    switch (claim.state) {
      case "not_found":
        return json({ success: false, message: "No encontramos este pago." }, 404)
      case "busy":
        return json({ success: false, retry: true, message: "Estamos confirmando tu pago. Recarga en unos segundos." }, 409)
      case "approved":
        return json(successBody(kind, ticketId, s!, m, true))
      case "needs_review":
        return json(reviewBody(s?.provider_charge_id), 500)
      case "declined":
        return json({ success: false, message: "El pago no se completó. No se te cobró nada." }, 402)
      case "error":
        return json({ success: false, message: m.error === "abandoned" || m.error === "reservation_expired"
          ? "Tu reserva venció antes de confirmar el pago. Si PayPhone te cobró, el cobro se revierte solo en minutos."
          : "No se pudo completar el pago. No se te cobró nada." }, 409)
    }
    if (claim.state !== "claimed" || !s) {
      return json({ success: false, message: "Estado de pago desconocido." }, 500)
    }

    const sessionId = String(s.id)
    let meta = m
    const setSession = (patch: Record<string, unknown>) => {
      const { confirming_at: _drop, ...rest } = { ...meta, ...((patch.metadata ?? {}) as Record<string, unknown>) }
      meta = rest
      return supabase.from("payment_sessions")
        .update({ ...patch, metadata: meta, updated_at: new Date().toISOString() })
        .eq("id", sessionId)
    }
    const release = async () => {
      if (kind === "tour") await supabase.rpc("cancel_sale", { p_sale_id: ticketId })
      else await supabase.rpc("set_business_ticket_status", { p_ticket_id: ticketId, p_status: "rechazado" })
    }

    // ── Cancelado por el comprador ──
    if (cancelled) {
      await release()
      await setSession({ status: "declined", metadata: { cancelled_by_customer: true } })
      return json({ success: false, cancelled: true, message: "Cancelaste el pago. No se te cobró nada y los cupos quedaron libres." }, 402)
    }

    // ── 2. La reserva tiene que seguir pendiente ──
    if (claim.reservation_status !== "pendiente") {
      await setSession({ status: "error", metadata: { error: "reservation_expired", reservation_status: claim.reservation_status, payphone_id: payphoneId } })
      return json({ success: false, message: "Tu reserva venció antes de confirmar el pago, así que no lo confirmamos. Si PayPhone te cobró, el cobro se revierte solo en minutos." }, 409)
    }

    // ── 3. Confirmar en PayPhone ──
    let pp
    try {
      pp = await confirmPayment(token, payphoneId, clientTx)
    } catch (e) {
      // Sin respuesta no sabemos el resultado: soltar el reclamo para reintentar.
      console.error("payphone confirm fetch:", (e as Error).message)
      await setSession({})
      return json({ success: false, retry: true, message: "No pudimos comunicarnos con PayPhone. Recarga la página para reintentar." }, 502)
    }

    const ppBody = safeConfirmBody(pp.body)
    if (!pp.ok) {
      console.error("payphone confirm rechazado:", pp.status, JSON.stringify(ppBody))
      await setSession({ metadata: { last_confirm_error: ppBody } })
      return json({ success: false, retry: true, message: "PayPhone no confirmó el pago todavía. Recarga la página en un momento." }, 502)
    }

    const chargeId = pp.transactionId ?? String(payphoneId)

    if (!pp.approved) {
      await release()
      await setSession({ status: "declined", provider_charge_id: chargeId, metadata: { payphone: ppBody } })
      return json({ success: false, message: pp.canceled
        ? "El pago fue cancelado. No se te cobró nada."
        : "PayPhone rechazó el pago. No se te cobró nada." }, 402)
    }

    const ticketUrl = appUrl(req) ? `${appUrl(req)}/ticket/${ticketId}` : ""
    const split = (meta.split ?? {}) as Record<string, number>
    const expected = Number(split.total_cents)
    // Chequeo de consistencia. La doc dice que los montos van en centavos,
    // pero no lo confirma para la respuesta de V2/Confirm: se aceptan ambos.
    const got = Number(pp.amountCents)
    const amountOk = got === expected || Math.round(got * 100) === expected
    const txOk = !pp.clientTransactionId || pp.clientTransactionId.toLowerCase() === clientTx
    const matches = Number.isFinite(expected) && amountOk && txOk

    // ── 4. Confirmar en BD ──
    const ref = `payphone:${chargeId}`
    const confirm = !matches
      ? { error: { message: `AMOUNT_MISMATCH esperado ${expected} recibido ${pp.amountCents}` } }
      : kind === "tour"
        ? await supabase.rpc("confirm_sale", { p_sale_id: ticketId, p_payment_ref: ref })
        : await supabase.rpc("set_business_ticket_status", { p_ticket_id: ticketId, p_status: "verificado", p_payment_ref: ref })

    if (confirm.error) {
      console.error("payphone: cobro aprobado pero no se confirmó:", confirm.error.message, "tx:", chargeId)
      await setSession({
        status: "needs_review",
        provider_charge_id: chargeId,
        metadata: { payphone: ppBody, confirm_error: confirm.error.message, ticket_url: ticketUrl },
      })
      return json(reviewBody(chargeId), 500)
    }

    const reservation = (meta.reservation ?? {}) as Record<string, unknown>
    await setSession({
      status: "approved",
      provider_charge_id: chargeId,
      metadata: { payphone: ppBody, qr_payload: reservation.qr_payload, ticket_url: ticketUrl, approved_at: new Date().toISOString() },
    })

    // ── Notificar (no bloquea el resultado) ──
    const customer = meta.customer as TicketInfo["customer"]
    const subtotal = Number(reservation.amount ?? 0)
    const fee = Number(reservation.fee ?? 0)
    const amount = Number(reservation.total_charged ?? s.amount)
    const label = `Tarjeta · PayPhone ${chargeId}`
    const info: TicketInfo = kind === "tour"
      ? {
          kind: "tour", status: "pagado", customer,
          title: String(reservation.tour_title), place: String(reservation.chiva_name),
          date: String(reservation.departure_at), seats: (meta.seats as number[]) ?? [], quantity: Number(meta.quantity ?? 1),
          amount, subtotal, fee, paymentLabel: label, ticketUrl,
        }
      : {
          kind: "business", status: "pagado", customer,
          title: String(reservation.event_title), place: String(reservation.business_name),
          date: String(reservation.event_date), quantity: Number(meta.quantity ?? 1),
          amount, subtotal, fee, paymentLabel: label, ticketUrl,
        }
    if (customer?.email) await notifyAll(supabase, String(reservation.owner_id), info)

    return json(successBody(kind, ticketId, { ...s, provider_charge_id: chargeId }, meta, false))
  } catch (err) {
    console.error("payphone-confirm:", (err as Error).message)
    return json({ success: false, retry: true, message: "Error interno al confirmar el pago. Recarga la página." }, 500)
  }
})

function successBody(kind: string, ticketId: string, s: Record<string, unknown>, m: Record<string, unknown>, duplicate: boolean) {
  const r = (m.reservation ?? {}) as Record<string, unknown>
  return {
    success: true,
    duplicate,
    kind,
    saleId: kind === "tour" ? ticketId : undefined,
    ticketId: kind === "business" ? ticketId : undefined,
    chargeId: s.provider_charge_id ?? null,
    amount: Number(r.amount ?? 0),
    fee: Number(r.fee ?? 0),
    total: Number(r.total_charged ?? s.amount ?? 0),
    title: r.tour_title ?? r.event_title ?? null,
    place: r.chiva_name ?? r.business_name ?? null,
    date: r.departure_at ?? r.event_date ?? null,
    seats: m.seats ?? null,
    quantity: m.quantity ?? null,
    qrPayload: m.qr_payload ?? r.qr_payload ?? null,
    ticketUrl: m.ticket_url ?? null,
  }
}

function reviewBody(chargeId: unknown) {
  const ref = chargeId ? String(chargeId) : "sin referencia"
  return {
    success: false,
    needsReview: true,
    chargeId: chargeId ?? null,
    message: `Tu pago fue aprobado (PayPhone ${ref}) pero hubo un problema al emitir el ticket. Guarda esta referencia y contáctanos; no se te cobrará dos veces.`,
  }
}
