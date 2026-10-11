-- ================================================================
-- Estado de cuenta mensual del vendedor (dueño de chiva o establecimiento)
--
-- El cargo por servicio de las ventas web es de chivaspass:
--   tarjeta       → la pasarela lo retiene al cobrar; no se debe nada.
--   transferencia → el turista paga precio + cargo a la cuenta del vendedor;
--                   ese cargo se liquida a chivaspass cada mes.
--   efectivo / promotores → no llevan cargo.
--
-- El periodo es un mes calendario en hora de Ecuador y se paga hasta el día
-- 'statement_due_day' del mes siguiente. Los pagos del vendedor se registran
-- desde administración con register_fee_payment().
-- ================================================================

INSERT INTO public.app_settings (key, value, description) VALUES
  ('statement_due_day', '10', 'Día del mes siguiente hasta el que se paga el estado de cuenta')
ON CONFLICT (key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.fee_payments (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  period      date        NOT NULL CHECK (period = date_trunc('month', period)::date),
  amount      numeric     NOT NULL CHECK (amount > 0),
  payment_ref text,
  paid_at     timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_fee_payments_owner_period ON public.fee_payments(owner_id, period);

ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fee_payments: lee los suyos" ON public.fee_payments;
CREATE POLICY "fee_payments: lee los suyos" ON public.fee_payments FOR SELECT
  USING ((SELECT auth.uid()) = owner_id);
REVOKE ALL ON public.fee_payments FROM anon, authenticated;
GRANT SELECT ON public.fee_payments TO authenticated;

-- Mes en curso (primer día) en hora de Ecuador
CREATE OR REPLACE FUNCTION public.current_period()
RETURNS date LANGUAGE sql STABLE AS $$
  SELECT date_trunc('month', now() AT TIME ZONE 'America/Guayaquil')::date;
$$;

CREATE OR REPLACE FUNCTION public.seller_statement(p_user uuid, p_period date DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_period   date := date_trunc('month', coalesce(p_period, public.current_period()))::date;
  v_from     timestamptz := v_period::timestamp AT TIME ZONE 'America/Guayaquil';
  v_to       timestamptz := (v_period + interval '1 month')::timestamp AT TIME ZONE 'America/Guayaquil';
  v_due      date := (v_period + interval '1 month')::date + (public.setting_int('statement_due_day', 10) - 1);
  v_methods  jsonb;
  v_lines    jsonb;
  v_owed     numeric;
  v_card     numeric;
  v_paid     numeric;
  v_payments jsonb;
  v_status   text;
BEGIN
  -- Ventas pagadas del periodo: tours (libro owner_balance) y atracciones
  WITH ventas AS (
    SELECT ob.created_at AS fecha, 'tour'::text AS kind, coalesce(t.title, 'Tour') AS concepto,
           s.customer_name AS cliente, ob.boletos_vendidos AS cantidad, ob.monto_total AS monto,
           coalesce(ob.platform_fee, 0) AS cargo,
           coalesce(ob.payment_method, s.payment_method, 'transferencia') AS metodo,
           s.payment_ref AS ref
      FROM public.owner_balance ob
      LEFT JOIN public.sales_simple s ON s.id = ob.sale_id
      LEFT JOIN public.tours t ON t.id = s.tour_id
     WHERE ob.owner_id = p_user AND ob.created_at >= v_from AND ob.created_at < v_to
    UNION ALL
    SELECT bt.created_at, 'evento', coalesce(e.title, 'Evento'),
           bt.customer_name, bt.quantity, bt.total_price,
           coalesce(bt.platform_fee, 0),
           CASE WHEN bt.payment_proof_path IS NULL THEN 'tarjeta' ELSE 'transferencia' END,
           bt.payment_number
      FROM public.business_tickets bt
      LEFT JOIN public.business_events e ON e.id = bt.event_id
     WHERE bt.owner_id = p_user AND bt.payment_status = 'verificado'
       AND bt.created_at >= v_from AND bt.created_at < v_to
  )
  SELECT
    coalesce((SELECT jsonb_agg(jsonb_build_object('metodo', metodo, 'ventas', n, 'cantidad', q, 'monto', m, 'cargo', f) ORDER BY metodo)
                FROM (SELECT metodo, count(*) AS n, sum(cantidad) AS q, sum(monto) AS m, sum(cargo) AS f
                        FROM ventas GROUP BY metodo) g), '[]'::jsonb),
    coalesce((SELECT jsonb_agg(jsonb_build_object('fecha', fecha, 'kind', kind, 'concepto', concepto, 'cliente', cliente,
                                                  'cantidad', cantidad, 'monto', monto, 'cargo', cargo, 'ref', ref) ORDER BY fecha)
                FROM ventas WHERE metodo = 'transferencia' AND cargo > 0), '[]'::jsonb),
    coalesce((SELECT sum(cargo) FROM ventas WHERE metodo = 'transferencia'), 0),
    coalesce((SELECT sum(cargo) FROM ventas WHERE metodo = 'tarjeta'), 0)
  INTO v_methods, v_lines, v_owed, v_card;

  SELECT coalesce(sum(amount), 0),
         coalesce(jsonb_agg(jsonb_build_object('fecha', paid_at, 'monto', amount, 'ref', payment_ref) ORDER BY paid_at), '[]'::jsonb)
    INTO v_paid, v_payments
    FROM public.fee_payments
   WHERE owner_id = p_user AND period = v_period;

  v_status := CASE
    WHEN v_period >= public.current_period()                 THEN 'en_curso'
    WHEN v_owed = 0 AND v_paid = 0                           THEN 'sin_cargos'
    WHEN v_paid >= v_owed                                    THEN 'pagado'
    WHEN (now() AT TIME ZONE 'America/Guayaquil')::date > v_due THEN 'vencido'
    ELSE 'pendiente'
  END;

  RETURN jsonb_build_object(
    'period',     v_period,
    'due_date',   v_due,
    'status',     v_status,
    'methods',    v_methods,
    'lines',      v_lines,
    'fees_owed',  v_owed,
    'fees_card',  v_card,
    'paid',       v_paid,
    'payments',   v_payments,
    'balance',    v_owed - v_paid
  );
END;
$$;
REVOKE ALL ON FUNCTION public.seller_statement(uuid, date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.seller_statement(uuid, date) TO service_role;

-- El panel: estado de cuenta propio de un mes
CREATE OR REPLACE FUNCTION public.my_statement(p_period date DEFAULT NULL)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.seller_statement(auth.uid(), p_period);
$$;
REVOKE ALL ON FUNCTION public.my_statement(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_statement(date) TO authenticated, service_role;

-- El panel: resumen de los últimos 12 meses con movimiento
CREATE OR REPLACE FUNCTION public.my_statement_history()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'period', st->>'period', 'status', st->>'status',
           'fees_owed', (st->>'fees_owed')::numeric, 'paid', (st->>'paid')::numeric,
           'balance', (st->>'balance')::numeric) ORDER BY st->>'period' DESC), '[]'::jsonb)
    FROM (
      SELECT public.seller_statement(auth.uid(), (public.current_period() - make_interval(months => i))::date) AS st
        FROM generate_series(0, 11) AS i
    ) h
   WHERE st->>'status' = 'en_curso'
      OR jsonb_array_length(st->'methods') > 0
      OR (st->>'paid')::numeric > 0;
$$;
REVOKE ALL ON FUNCTION public.my_statement_history() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_statement_history() TO authenticated, service_role;

-- ---- Administración ----
-- Registrar un pago del vendedor:
--   SELECT public.register_fee_payment('correo@vendedor.com', '2026-10-01', 12.50, 'TRX-555');
CREATE OR REPLACE FUNCTION public.register_fee_payment(
  p_email       text,
  p_period      date,
  p_amount      numeric,
  p_payment_ref text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user   uuid;
  v_period date := date_trunc('month', coalesce(p_period, public.current_period()))::date;
BEGIN
  SELECT id INTO v_user FROM public.users WHERE lower(email) = lower(trim(p_email));
  IF NOT FOUND THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'INVALID_AMOUNT'; END IF;

  INSERT INTO public.fee_payments (owner_id, period, amount, payment_ref)
  VALUES (v_user, v_period, p_amount, p_payment_ref);

  RETURN public.seller_statement(v_user, v_period) - 'lines' - 'methods';
END;
$$;
REVOKE ALL ON FUNCTION public.register_fee_payment(text, date, numeric, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.register_fee_payment(text, date, numeric, text) TO service_role;

-- Quién debe qué en un mes:
--   SELECT * FROM public.statements_overview('2026-10-01');
CREATE OR REPLACE FUNCTION public.statements_overview(p_period date DEFAULT NULL)
RETURNS TABLE (email text, nombre text, rol text, cargos numeric, pagado numeric, saldo numeric, estado text, vence date)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u.email, u.full_name, u.role,
         (x.st->>'fees_owed')::numeric, (x.st->>'paid')::numeric, (x.st->>'balance')::numeric,
         x.st->>'status', (x.st->>'due_date')::date
    FROM public.users u
   CROSS JOIN LATERAL (SELECT public.seller_statement(u.id, p_period) AS st) x
   WHERE u.role IN ('dueño', 'negocio')
     AND ((x.st->>'fees_owed')::numeric > 0 OR (x.st->>'paid')::numeric > 0)
   ORDER BY (x.st->>'balance')::numeric DESC;
$$;
REVOKE ALL ON FUNCTION public.statements_overview(date) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.statements_overview(date) TO service_role;
