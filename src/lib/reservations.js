// Llamadas a las edge functions de venta. Centraliza el manejo de errores
// para que todos los flujos (público, agencia, dueño) muestren el mensaje
// que devuelve el servidor.

const readError = async (error, fallback) => {
  try {
    const body = await error?.context?.json?.();
    if (body?.message) return body.message;
  } catch { /* sin cuerpo JSON */ }
  return fallback;
};

const invoke = async (supabase, fn, body, fallback) => {
  const { data, error } = await supabase.functions.invoke(fn, { body });
  if (error) throw new Error(await readError(error, fallback));
  if (!data?.success) throw new Error(data?.message || fallback);
  return data;
};

// Reserva de tour sin tarjeta.
//   { assignedChivaId, seats, customer, proofNumber?, proofPath?, paymentMethod? }
export const reserveTour = (supabase, payload) =>
  invoke(supabase, "public-reserve", { type: "tour", payload }, "No se pudo registrar la reserva.");

// Reserva de evento sin tarjeta.
//   { eventId, quantity, customer, proofNumber, proofPath }
export const reserveEvent = (supabase, payload) =>
  invoke(supabase, "public-reserve", { type: "business", payload }, "No se pudo registrar la reserva.");

// Cobro con tarjeta (token de Kushki ya generado en el navegador).
export const chargeCard = (supabase, type, token, payload) =>
  invoke(supabase, "kushki-charge", { token, type, payload }, "No se pudo procesar el pago.");

// Datos bancarios del vendedor para mostrar en el checkout.
export const sellerPaymentInfo = async (supabase, ownerId) => {
  if (!ownerId) return null;
  const { data } = await supabase.rpc("get_seller_payment_info", { p_owner_id: ownerId });
  return data ?? null;
};
