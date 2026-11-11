-- ================================================================
-- Cobro con tarjeta vía PayPhone con Split de Pagos (10 nov 2026)
--
-- ChivasPass es la única tienda PayPhone que cobra. En cada venta se envía
-- transferTo con la parte del vendedor; lo que no se reparte (cargo por
-- servicio menos la comisión de PayPhone) queda en el saldo de ChivasPass.
--
--  1. panel_settings: cuenta PayPhone del vendedor (identificador + tipo).
--  2. app_settings: comisión de PayPhone, modo del split y margen de
--     confirmación. setting_numeric() para valores con decimales.
--  3. payment_sessions: el proveedor solo puede ser kushki o payphone.
--  4. seller_controls: accept_payphone (sí/no) para el checkout público. El
--     identificador NUNCA sale por las funciones públicas.
--  5. payphone_split_recipients(): receptores y montos salen de la base.
--  6. payphone_claim_session(): reclama una sesión de forma atómica para
--     que una recarga de la página de retorno no confirme dos veces.
--  7. Cron: las reservas con tarjeta tienen más margen antes de liberarse
--     (enlace de 10 min + 5 min para confirmar) y no se libera una venta
--     cuya confirmación está en curso.
--  8. payphone_sessions_overview(): listado para administración por SQL.
--
-- No cambia el estado de cuenta: las ventas PayPhone se registran con
-- payment_method = 'tarjeta', y record_sale_balance ya las marca
-- fee_collected = true; seller_statement solo cobra cargos de transferencias.
-- ================================================================

-- ─────────────── 1. Cuenta PayPhone del vendedor ───────────────
ALTER TABLE public.panel_settings
  ADD COLUMN IF NOT EXISTS payphone_identifier text,
  ADD COLUMN IF NOT EXISTS payphone_id_type    smallint;

COMMENT ON COLUMN public.panel_settings.payphone_identifier IS
  'Cuenta PayPhone que recibe el split. Tipo 3: RUC (13) o cédula (10) de PayPhone Business. Tipo 4: celular +5939XXXXXXXX de PayPhone Personal.';

-- Normaliza antes de validar: sin espacios ni guiones, vacío → NULL y el
-- celular local 09XXXXXXXX pasa a +5939XXXXXXXX.
CREATE OR REPLACE FUNCTION public.normalize_payphone_account()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  NEW.payphone_identifier := nullif(regexp_replace(coalesce(NEW.payphone_identifier, ''), '[\s-]', '', 'g'), '');
  IF NEW.payphone_identifier IS NULL THEN
    NEW.payphone_id_type := NULL;
  ELSIF NEW.payphone_id_type = 4 AND NEW.payphone_identifier ~ '^09[0-9]{8}$' THEN
    NEW.payphone_identifier := '+593' || substr(NEW.payphone_identifier, 2);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.normalize_payphone_account() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_normalize_payphone_account ON public.panel_settings;
CREATE TRIGGER trg_normalize_payphone_account
  BEFORE INSERT OR UPDATE OF payphone_identifier, payphone_id_type ON public.panel_settings
  FOR EACH ROW EXECUTE FUNCTION public.normalize_payphone_account();

ALTER TABLE public.panel_settings DROP CONSTRAINT IF EXISTS panel_settings_payphone_check;
-- coalesce: un CHECK que da NULL se considera cumplido, y un tipo NULL con
-- identificador haría NULL toda la expresión.
ALTER TABLE public.panel_settings ADD CONSTRAINT panel_settings_payphone_check CHECK (
     (payphone_identifier IS NULL AND payphone_id_type IS NULL)
  OR (coalesce(payphone_id_type, 0) = 3 AND coalesce(payphone_identifier, '') ~ '^[0-9]{10}([0-9]{3})?$')
  OR (coalesce(payphone_id_type, 0) = 4 AND coalesce(payphone_identifier, '') ~ '^\+5939[0-9]{8}$')
);

-- ─────────────── 2. Parámetros ───────────────
INSERT INTO public.app_settings (key, value, description) VALUES
  ('payphone_commission_pct', '5.75',
   'Comisión de PayPhone por cobro con tarjeta, en % del total cobrado. Se descuenta del cargo por servicio.'),
  ('payphone_split_mode', 'next_day',
   'Modo del split acordado con PayPhone: next_day (bloqueado hasta el día siguiente, permite reversos) o immediate. Solo informativo: se elige al activar el split.'),
  ('payphone_confirm_grace_minutes', '20',
   'Minutos que una reserva con tarjeta espera la confirmación antes de que el cron la libere.')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.setting_numeric(p_key text, p_default numeric)
RETURNS numeric LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT coalesce((SELECT value::numeric FROM public.app_settings WHERE key = p_key), p_default);
$$;

-- ─────────────── 3. Proveedores de pago ───────────────
ALTER TABLE public.payment_sessions DROP CONSTRAINT IF EXISTS payment_sessions_provider_check;
ALTER TABLE public.payment_sessions ADD CONSTRAINT payment_sessions_provider_check
  CHECK (provider IN ('kushki', 'payphone'));

-- ─────────────── 4. Controles del vendedor con accept_payphone ───────────────
CREATE OR REPLACE FUNCTION public.seller_controls(p_owner_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(
    (SELECT jsonb_build_object(
        'public_listing', public_listing,
        'accept_transfers', accept_transfers,
        'accept_cards', accept_cards,
        'accept_cash', accept_cash,
        'accept_payphone', accept_cards AND payphone_identifier IS NOT NULL,
        'enforce_hours', enforce_hours,
        'hours_open', to_char(hours_open, 'HH24:MI'),
        'hours_close', to_char(hours_close, 'HH24:MI'),
        'hours_note', hours_note,
        'close_sales_minutes_before', close_sales_minutes_before)
       FROM public.panel_settings WHERE user_id = p_owner_id),
    '{"public_listing":true,"accept_transfers":true,"accept_cards":true,"accept_cash":true,"accept_payphone":false,"enforce_hours":false,"hours_open":"07:00","hours_close":"19:00","hours_note":"","close_sales_minutes_before":0}'::jsonb
  );
$$;

-- ─────────────── 5. Receptores del split ───────────────
-- Devuelve { recipients: [{ role, user_id, identifier, type, amount }], has_agency }.
-- amount en dólares, tal como está en la venta (owner_gain / agency_gain /
-- total_price). La edge function lo pasa a centavos y valida el tope.
-- Si un receptor no tiene cuenta PayPhone: METHOD_DISABLED.
CREATE OR REPLACE FUNCTION public.payphone_split_recipients(p_ticket_type text, p_ticket_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_owner uuid; v_agency uuid; v_owner_amount numeric; v_agency_amount numeric;
  v_rec jsonb := '[]'::jsonb;
  v_acc record;
BEGIN
  IF p_ticket_type = 'tour' THEN
    SELECT owner_id, agency_id, coalesce(owner_gain, total_sale), coalesce(agency_gain, 0)
      INTO v_owner, v_agency, v_owner_amount, v_agency_amount
      FROM public.sales_simple WHERE id = p_ticket_id;
  ELSIF p_ticket_type = 'business' THEN
    SELECT owner_id, NULL::uuid, total_price, 0
      INTO v_owner, v_agency, v_owner_amount, v_agency_amount
      FROM public.business_tickets WHERE id = p_ticket_id;
  ELSE
    RAISE EXCEPTION 'INVALID_TYPE';
  END IF;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'SALE_NOT_FOUND'; END IF;

  SELECT payphone_identifier AS identifier, payphone_id_type AS type INTO v_acc
    FROM public.panel_settings WHERE user_id = v_owner AND accept_cards;
  IF v_acc.identifier IS NULL THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
  v_rec := v_rec || jsonb_build_object('role', 'owner', 'user_id', v_owner,
                                       'identifier', v_acc.identifier, 'type', v_acc.type, 'amount', v_owner_amount);

  -- Fase 2 (agencias): la edge function rechaza más de un receptor hasta
  -- que se active. Se arma igual para que el cálculo esté probado.
  IF v_agency IS NOT NULL AND v_agency_amount > 0 THEN
    SELECT payphone_identifier AS identifier, payphone_id_type AS type INTO v_acc
      FROM public.panel_settings WHERE user_id = v_agency;
    IF v_acc.identifier IS NULL THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
    v_rec := v_rec || jsonb_build_object('role', 'agency', 'user_id', v_agency,
                                         'identifier', v_acc.identifier, 'type', v_acc.type, 'amount', v_agency_amount);
  END IF;

  RETURN jsonb_build_object('recipients', v_rec, 'has_agency', v_agency IS NOT NULL);
END;
$$;
REVOKE ALL ON FUNCTION public.payphone_split_recipients(text, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.payphone_split_recipients(text, uuid) TO service_role;

-- ─────────────── 6. Reclamar una sesión para confirmarla ───────────────
-- Una sola llamada a la vez confirma cada sesión. Devuelve el estado:
--   not_found | approved | declined | error | needs_review | busy | claimed
-- 'claimed' incluye reservation_status: si ya no es 'pendiente', la edge
-- function NO confirma en PayPhone (sin confirmación, PayPhone revierte).
-- El reclamo vence a los 2 minutos para poder reintentar si la función cae.
CREATE OR REPLACE FUNCTION public.payphone_claim_session(p_client_tx text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_s public.payment_sessions%ROWTYPE;
  v_res text;
BEGIN
  SELECT * INTO v_s FROM public.payment_sessions
   WHERE provider = 'payphone' AND provider_token = p_client_tx
   FOR UPDATE;
  IF NOT FOUND THEN RETURN jsonb_build_object('state', 'not_found'); END IF;

  IF v_s.status <> 'pending' THEN
    RETURN jsonb_build_object('state', v_s.status, 'session', to_jsonb(v_s));
  END IF;

  IF (v_s.metadata->>'confirming_at') IS NOT NULL
     AND (v_s.metadata->>'confirming_at')::timestamptz > now() - interval '2 minutes' THEN
    RETURN jsonb_build_object('state', 'busy');
  END IF;

  IF v_s.ticket_type = 'tour' THEN
    SELECT status INTO v_res FROM public.sales_simple WHERE id = v_s.ticket_id FOR UPDATE;
  ELSE
    SELECT payment_status INTO v_res FROM public.business_tickets WHERE id = v_s.ticket_id FOR UPDATE;
  END IF;

  UPDATE public.payment_sessions
     SET metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('confirming_at', now()),
         updated_at = now()
   WHERE id = v_s.id
  RETURNING * INTO v_s;

  RETURN jsonb_build_object('state', 'claimed', 'session', to_jsonb(v_s), 'reservation_status', v_res);
END;
$$;
REVOKE ALL ON FUNCTION public.payphone_claim_session(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.payphone_claim_session(text) TO service_role;

-- ─────────────── 7. Cron con margen para tarjeta ───────────────
-- Igual a la versión del 26 oct salvo:
--   · reservas con tarjeta (sin comprobante) esperan payphone_confirm_grace_minutes
--   · no se libera una venta con confirmación PayPhone en curso
--   · las sesiones PayPhone abandonadas pasan a 'error'
CREATE OR REPLACE FUNCTION public.expire_pending_reservations()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_no_proof   int := public.setting_int('reservation_no_proof_minutes', 15);
  v_unverified int := public.setting_int('reservation_unverified_hours', 24);
  v_before_dep int := public.setting_int('reservation_release_before_departure_minutes', 60);
  v_card_grace int := greatest(public.setting_int('payphone_confirm_grace_minutes', 20),
                               public.setting_int('reservation_no_proof_minutes', 15));
  v_sale       record;
  v_sales      int := 0;
  v_tickets    int := 0;
  v_sessions   int := 0;
BEGIN
  FOR v_sale IN
    SELECT s.id
      FROM public.sales_simple s
      JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
     WHERE s.status = 'pendiente'
       AND NOT EXISTS (
         SELECT 1 FROM public.payment_sessions ps
          WHERE ps.ticket_id = s.id AND ps.provider = 'payphone' AND ps.status = 'pending'
            AND (ps.metadata->>'confirming_at')::timestamptz > now() - interval '10 minutes')
       AND (
         (NOT EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.sale_id = s.id)
            AND s.created_at < now() - make_interval(mins => CASE WHEN s.payment_method = 'tarjeta' THEN v_card_grace ELSE v_no_proof END))
         OR (EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.sale_id = s.id AND p.estado = 'pendiente')
            AND (s.created_at < now() - make_interval(hours => v_unverified)
                 OR ac.departure_at < now() + make_interval(mins => v_before_dep)))
       )
  LOOP
    UPDATE public.pending_payments
       SET estado = 'rechazado', verified_at = now()
     WHERE sale_id = v_sale.id AND estado = 'pendiente';

    UPDATE public.sales_simple SET status = 'cancelado', updated_at = now()
     WHERE id = v_sale.id AND status = 'pendiente';
    IF FOUND THEN
      UPDATE public.seats SET status = 'disponible', sale_id = NULL
       WHERE sale_id = v_sale.id AND status = 'reservado';
      v_sales := v_sales + 1;
    END IF;
  END LOOP;

  -- Entradas sin comprobante = cobro con tarjeta en curso
  WITH expired AS (
    UPDATE public.business_tickets t
       SET payment_status = 'rechazado'
     WHERE t.payment_status = 'pendiente'
       AND t.payment_proof_path IS NULL
       AND t.created_at < now() - make_interval(mins => v_card_grace)
       AND NOT EXISTS (
         SELECT 1 FROM public.payment_sessions ps
          WHERE ps.ticket_id = t.id AND ps.provider = 'payphone' AND ps.status = 'pending'
            AND (ps.metadata->>'confirming_at')::timestamptz > now() - interval '10 minutes')
     RETURNING t.event_id
  )
  SELECT count(*) INTO v_tickets FROM expired;

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

  -- Sesiones PayPhone cuya reserva ya se liberó: el comprador no volvió y
  -- PayPhone revirtió el cobro sin confirmar (5 min).
  WITH abandoned AS (
    UPDATE public.payment_sessions ps
       SET status = 'error',
           metadata = coalesce(ps.metadata, '{}'::jsonb) || jsonb_build_object('error', 'abandoned', 'expired_at', now()),
           updated_at = now()
     WHERE ps.provider = 'payphone' AND ps.status = 'pending'
       AND ps.created_at < now() - make_interval(mins => v_card_grace)
       AND (ps.ticket_id IS NULL
            OR EXISTS (SELECT 1 FROM public.sales_simple s WHERE s.id = ps.ticket_id AND s.status = 'cancelado')
            OR EXISTS (SELECT 1 FROM public.business_tickets t WHERE t.id = ps.ticket_id AND t.payment_status = 'rechazado'))
     RETURNING ps.id
  )
  SELECT count(*) INTO v_sessions FROM abandoned;

  UPDATE public.business_events e
     SET status = 'activo'
   WHERE e.status = 'agotado'
     AND e.event_date >= now()
     AND (SELECT coalesce(sum(quantity), 0) FROM public.business_tickets t
           WHERE t.event_id = e.id AND t.payment_status <> 'rechazado') < e.capacity;

  UPDATE public.assigned_chivas SET status = 'finalizado'
   WHERE status IN ('pendiente', 'en_curso') AND departure_at < now() - interval '6 hours';
  UPDATE public.business_events SET status = 'finalizado'
   WHERE status IN ('activo', 'agotado') AND event_date < now() - interval '6 hours';

  RETURN jsonb_build_object('sales_released', v_sales, 'tickets_released', v_tickets,
                            'payphone_abandoned', v_sessions, 'ran_at', now());
END;
$$;
REVOKE ALL ON FUNCTION public.expire_pending_reservations() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_pending_reservations() TO service_role;

-- ─────────────── 8. Listado para administración ───────────────
-- Uso en el SQL Editor:
--   SELECT * FROM public.payphone_sessions_overview();                 -- últimos 30 días
--   SELECT * FROM public.payphone_sessions_overview(now() - interval '7 days', 'needs_review');
CREATE OR REPLACE FUNCTION public.payphone_sessions_overview(
  p_since  timestamptz DEFAULT now() - interval '30 days',
  p_status text        DEFAULT NULL
)
RETURNS TABLE (
  creada        timestamptz,
  estado        text,
  tipo          text,
  venta_id      uuid,
  vendedor      text,
  comprador     text,
  client_tx_id  text,
  payphone_id   text,
  total         numeric,
  comision_payphone numeric,
  al_vendedor   numeric,
  cargo_neto    numeric,
  error         text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT ps.created_at, ps.status, ps.ticket_type, ps.ticket_id,
         u.email,
         ps.metadata->>'customer_email',
         ps.provider_token,
         ps.provider_charge_id,
         (ps.metadata->'split'->>'total_cents')::numeric / 100,
         (ps.metadata->'split'->>'payphone_cents')::numeric / 100,
         (ps.metadata->'split'->>'seller_cents')::numeric / 100,
         (ps.metadata->'split'->>'net_fee_cents')::numeric / 100,
         coalesce(ps.metadata->>'confirm_error', ps.metadata->>'error')
    FROM public.payment_sessions ps
    LEFT JOIN public.sales_simple s     ON ps.ticket_type = 'tour'     AND s.id = ps.ticket_id
    LEFT JOIN public.business_tickets t ON ps.ticket_type = 'business' AND t.id = ps.ticket_id
    LEFT JOIN public.users u            ON u.id = coalesce(s.owner_id, t.owner_id)
   WHERE ps.provider = 'payphone'
     AND ps.created_at >= p_since
     AND (p_status IS NULL OR ps.status = p_status)
   ORDER BY (ps.status = 'needs_review') DESC, ps.created_at DESC;
$$;
REVOKE ALL ON FUNCTION public.payphone_sessions_overview(timestamptz, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.payphone_sessions_overview(timestamptz, text) TO service_role;
