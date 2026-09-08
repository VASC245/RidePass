-- ================================================================
-- ChivaPass — Expiración de reservas, límites de tasa e índices de escala
--
--   1. expire_pending_reservations(): libera asientos y cupos de reservas
--      que nunca se completaron o que el vendedor no verificó a tiempo.
--      Se ejecuta cada 5 minutos con pg_cron.
--   2. Rate limiting por clave (IP + endpoint) para las edge functions.
--   3. Índices compuestos para las consultas más frecuentes con volumen.
--   4. Limpieza periódica de tablas de soporte.
--
-- Idempotente.
-- ================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ================================================================
-- 1. Parámetros y expiración de reservas
-- ================================================================
-- Configuración editable sin redeploy (solo service_role / dashboard).
CREATE TABLE IF NOT EXISTS public.app_settings (
  key         text PRIMARY KEY,
  value       text NOT NULL,
  description text,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

INSERT INTO public.app_settings (key, value, description) VALUES
  ('reservation_no_proof_minutes', '15',
   'Minutos que se mantiene una reserva pendiente SIN comprobante (pago con tarjeta interrumpido) antes de liberarla'),
  ('reservation_unverified_hours', '24',
   'Horas que se mantiene una reserva CON comprobante sin verificar antes de liberarla'),
  ('reservation_release_before_departure_minutes', '60',
   'Si faltan menos de estos minutos para la salida y el comprobante sigue sin verificar, se libera')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.setting_int(p_key text, p_default int)
RETURNS int LANGUAGE sql STABLE AS $$
  SELECT coalesce((SELECT value::int FROM public.app_settings WHERE key = p_key), p_default);
$$;

-- Marca el motivo en el comprobante y cancela la venta liberando asientos.
CREATE OR REPLACE FUNCTION public.expire_pending_reservations()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_no_proof   int := public.setting_int('reservation_no_proof_minutes', 15);
  v_unverified int := public.setting_int('reservation_unverified_hours', 24);
  v_before_dep int := public.setting_int('reservation_release_before_departure_minutes', 60);
  v_sale       record;
  v_sales      int := 0;
  v_tickets    int := 0;
BEGIN
  -- a) Ventas de tour pendientes
  FOR v_sale IN
    SELECT s.id, s.assigned_chiva_id,
           EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.sale_id = s.id AND p.estado = 'pendiente') AS has_proof,
           ac.departure_at
      FROM public.sales_simple s
      JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
     WHERE s.status = 'pendiente'
       AND (
         -- sin comprobante: pago con tarjeta que nunca terminó
         (NOT EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.sale_id = s.id)
            AND s.created_at < now() - make_interval(mins => v_no_proof))
         -- con comprobante pero nadie lo verificó
         OR (EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.sale_id = s.id AND p.estado = 'pendiente')
            AND (s.created_at < now() - make_interval(hours => v_unverified)
                 OR ac.departure_at < now() + make_interval(mins => v_before_dep)))
       )
  LOOP
    UPDATE public.pending_payments
       SET estado = 'rechazado', verified_at = now()
     WHERE sale_id = v_sale.id AND estado = 'pendiente';
    PERFORM public.cancel_sale(v_sale.id);
    v_sales := v_sales + 1;
  END LOOP;

  -- b) Tickets de evento pendientes sin comprobante (tarjeta interrumpida)
  WITH expired AS (
    UPDATE public.business_tickets
       SET payment_status = 'rechazado'
     WHERE payment_status = 'pendiente'
       AND payment_proof_path IS NULL
       AND created_at < now() - make_interval(mins => v_no_proof)
     RETURNING event_id
  )
  SELECT count(*) INTO v_tickets FROM expired;

  -- c) Tickets de evento con comprobante que nadie verificó
  WITH expired AS (
    UPDATE public.business_tickets t
       SET payment_status = 'rechazado'
      FROM public.business_events e
     WHERE e.id = t.event_id
       AND t.payment_status = 'pendiente'
       AND t.payment_proof_path IS NOT NULL
       AND (t.created_at < now() - make_interval(hours => v_unverified)
            OR e.event_date < now() + make_interval(mins => v_before_dep))
     RETURNING t.event_id
  )
  SELECT v_tickets + count(*) INTO v_tickets FROM expired;

  -- Reabrir eventos que quedaron 'agotado' y ahora tienen cupo
  UPDATE public.business_events e
     SET status = 'activo'
   WHERE e.status = 'agotado'
     AND e.event_date >= now()
     AND (SELECT coalesce(sum(quantity), 0) FROM public.business_tickets t
           WHERE t.event_id = e.id AND t.payment_status <> 'rechazado') < e.capacity;

  -- Cerrar salidas y eventos ya pasados
  UPDATE public.assigned_chivas SET status = 'finalizado'
   WHERE status IN ('pendiente', 'en_curso') AND departure_at < now() - interval '6 hours';
  UPDATE public.business_events SET status = 'finalizado'
   WHERE status IN ('activo', 'agotado') AND event_date < now() - interval '6 hours';

  RETURN jsonb_build_object('sales_released', v_sales, 'tickets_released', v_tickets, 'ran_at', now());
END;
$$;

REVOKE ALL ON FUNCTION public.expire_pending_reservations() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_pending_reservations() TO service_role;

-- ================================================================
-- 2. Rate limiting (ventana fija por clave)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.rate_limits (
  key          text        NOT NULL,
  window_start timestamptz NOT NULL,
  hits         int         NOT NULL DEFAULT 1,
  PRIMARY KEY (key, window_start)
);
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Devuelve true si la petición está dentro del límite. Cuenta la petición.
CREATE OR REPLACE FUNCTION public.check_rate_limit(p_key text, p_limit int, p_window_seconds int)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_window timestamptz := to_timestamp(floor(extract(epoch FROM now()) / p_window_seconds) * p_window_seconds);
  v_hits   int;
BEGIN
  INSERT INTO public.rate_limits (key, window_start, hits)
  VALUES (p_key, v_window, 1)
  ON CONFLICT (key, window_start) DO UPDATE SET hits = public.rate_limits.hits + 1
  RETURNING hits INTO v_hits;
  RETURN v_hits <= p_limit;
END;
$$;
REVOKE ALL ON FUNCTION public.check_rate_limit(text, int, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_rate_limit(text, int, int) TO service_role;

CREATE OR REPLACE FUNCTION public.cleanup_support_tables()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  DELETE FROM public.rate_limits WHERE window_start < now() - interval '1 day';
  DELETE FROM public.payment_sessions WHERE status IN ('pending', 'error') AND created_at < now() - interval '7 days';
$$;
REVOKE ALL ON FUNCTION public.cleanup_support_tables() FROM PUBLIC, anon, authenticated;

-- ================================================================
-- 3. Índices para volumen
-- ================================================================
-- Disponibilidad de asientos por salida (grilla pública y reservas)
CREATE INDEX IF NOT EXISTS idx_seats_assigned_status   ON public.seats(assigned_chiva_id, status);
-- Listado público: próximas salidas activas
CREATE INDEX IF NOT EXISTS idx_assigned_upcoming       ON public.assigned_chivas(departure_at) WHERE status IN ('pendiente', 'en_curso');
-- Paneles: ventas por dueño/agencia en rango de fechas
CREATE INDEX IF NOT EXISTS idx_sales_owner_created     ON public.sales_simple(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_agency_created    ON public.sales_simple(agency_id, created_at DESC) WHERE agency_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sales_pending_created   ON public.sales_simple(created_at) WHERE status = 'pendiente';
-- Comprobantes pendientes por dueño
CREATE INDEX IF NOT EXISTS idx_pending_owner_estado    ON public.pending_payments(owner_id, estado, created_at DESC);
-- Cupo de eventos y panel de negocio
CREATE INDEX IF NOT EXISTS idx_btickets_event_status   ON public.business_tickets(event_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_btickets_owner_created  ON public.business_tickets(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_btickets_customer_email ON public.business_tickets(lower(customer_email));
-- Eventos activos próximos por negocio
CREATE INDEX IF NOT EXISTS idx_bevents_business_date   ON public.business_events(business_id, event_date) WHERE status = 'activo';
-- Sesiones de pago por ticket
CREATE INDEX IF NOT EXISTS idx_payment_sessions_created ON public.payment_sessions(created_at);

-- ================================================================
-- 4. Programación con pg_cron
-- ================================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'chivapass_expire_reservations') THEN
    PERFORM cron.unschedule('chivapass_expire_reservations');
  END IF;
  PERFORM cron.schedule('chivapass_expire_reservations', '*/5 * * * *',
    $job$ SELECT public.expire_pending_reservations(); $job$);

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'chivapass_cleanup_support') THEN
    PERFORM cron.unschedule('chivapass_cleanup_support');
  END IF;
  PERFORM cron.schedule('chivapass_cleanup_support', '17 3 * * *',
    $job$ SELECT public.cleanup_support_tables(); $job$);
END;
$$;
