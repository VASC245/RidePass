-- ================================================================
-- Bloqueo por plan: un vendedor sin plan vigente no vende.
--
-- Tarifas (decididas el 13 sep 2026):
--   dueño    → plan 'chiva': $40 al mes o $400 al año POR CHIVA
--   negocio  → 'establecimiento' $25 (hasta 1.000 entradas/mes)
--              'establecimiento_plus' $40 (sin límite)
--   agencia  → gratis hasta 30 tickets/mes; 'promotor' $15 sin límite
--
-- Dueños y establecimientos nuevos tienen 30 días de prueba
-- (users.trial_ends_at). Los que ya existían reciben 30 días desde hoy.
--
-- El bloqueo es un trigger en sales_simple y business_tickets: cubre
-- reserve_tour_seats, create_business_ticket y cualquier insert futuro.
-- Los planes se activan desde administración con activate_subscription().
-- ================================================================

INSERT INTO public.app_settings (key, value, description) VALUES
  ('plan_trial_days',            '30',   'Días de prueba gratis para dueños y establecimientos nuevos'),
  ('plan_establecimiento_limit', '1000', 'Entradas al mes incluidas en el plan Establecimiento'),
  ('plan_promotor_free_limit',   '30',   'Tickets al mes que un promotor vende sin plan')
ON CONFLICT (key) DO NOTHING;

-- ---- Prueba gratis ----
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz
  DEFAULT (now() + make_interval(days => public.setting_int('plan_trial_days', 30)));
UPDATE public.users
   SET trial_ends_at = now() + make_interval(days => public.setting_int('plan_trial_days', 30))
 WHERE trial_ends_at IS NULL;

CREATE OR REPLACE FUNCTION public.protect_user_privileges()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.is_api_client() THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'No puedes cambiar tu rol.' USING ERRCODE = '42501';
    END IF;
    IF NEW.plan IS DISTINCT FROM OLD.plan OR NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at THEN
      RAISE EXCEPTION 'El plan solo se cambia desde administración.' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ---- Suscripciones con las tarifas nuevas ----
ALTER TABLE public.subscriptions DROP CONSTRAINT IF EXISTS subscriptions_plan_check;
ALTER TABLE public.subscriptions ALTER COLUMN plan DROP DEFAULT;
ALTER TABLE public.subscriptions ADD CONSTRAINT subscriptions_plan_check
  CHECK (plan IN ('chiva', 'establecimiento', 'establecimiento_plus', 'promotor'));
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS billing text NOT NULL DEFAULT 'mensual' CHECK (billing IN ('mensual', 'anual')),
  ADD COLUMN IF NOT EXISTS units   int  NOT NULL DEFAULT 1 CHECK (units >= 1);

-- Inicio del mes en curso, hora de Ecuador
CREATE OR REPLACE FUNCTION public.plan_month_start()
RETURNS timestamptz LANGUAGE sql STABLE AS $$
  SELECT date_trunc('month', now() AT TIME ZONE 'America/Guayaquil') AT TIME ZONE 'America/Guayaquil';
$$;

-- ¿Tiene plan pagado vigente o prueba gratis? Barato: se usa en RLS.
CREATE OR REPLACE FUNCTION public.seller_plan_active(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
           SELECT 1 FROM public.subscriptions s
            WHERE s.user_id = p_user AND s.status = 'activo'
              AND (s.expires_at IS NULL OR s.expires_at > now()))
      OR coalesce((SELECT u.trial_ends_at > now() FROM public.users u WHERE u.id = p_user), false);
$$;
REVOKE ALL ON FUNCTION public.seller_plan_active(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seller_plan_active(uuid) TO anon, authenticated, service_role;

-- Estado completo del plan de un vendedor. p_quantity = lo que intenta
-- vender ahora (asientos o entradas); can_sell responde si puede.
CREATE OR REPLACE FUNCTION public.seller_plan(p_user uuid, p_quantity int DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_role    text;
  v_trial   timestamptz;
  v_sub     public.subscriptions%ROWTYPE;
  v_has_sub boolean;
  v_month   timestamptz := public.plan_month_start();
  v_status  text;
  v_limit   int;
  v_used    int := 0;
  v_chivas  int := 0;
  v_reason  text;
BEGIN
  SELECT role, trial_ends_at INTO v_role, v_trial FROM public.users WHERE id = p_user;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'sin_plan', 'can_sell', false, 'reason', 'PLAN_INACTIVE');
  END IF;

  SELECT * INTO v_sub FROM public.subscriptions
   WHERE user_id = p_user AND status = 'activo' AND (expires_at IS NULL OR expires_at > now());
  v_has_sub := FOUND;

  IF v_role = 'dueño' THEN
    SELECT count(*) INTO v_chivas FROM public.chivas WHERE user_id = p_user;
    IF v_has_sub AND v_sub.plan = 'chiva' THEN
      v_status := 'activo';
      IF v_chivas > v_sub.units THEN v_reason := 'PLAN_UNITS'; END IF;
    ELSIF v_trial > now() THEN
      v_status := 'prueba';
    ELSE
      v_status := 'vencido'; v_reason := 'PLAN_INACTIVE';
    END IF;

  ELSIF v_role = 'negocio' THEN
    SELECT coalesce(sum(quantity), 0) INTO v_used FROM public.business_tickets
     WHERE owner_id = p_user AND payment_status <> 'rechazado' AND created_at >= v_month;
    IF v_has_sub AND v_sub.plan IN ('establecimiento', 'establecimiento_plus') THEN
      v_status := 'activo';
      IF v_sub.plan = 'establecimiento' THEN
        v_limit := public.setting_int('plan_establecimiento_limit', 1000);
      END IF;
    ELSIF v_trial > now() THEN
      v_status := 'prueba';
    ELSE
      v_status := 'vencido'; v_reason := 'PLAN_INACTIVE';
    END IF;

  ELSIF v_role = 'agencia' THEN
    SELECT coalesce(sum(public.sale_seat_count(seats)), 0) INTO v_used FROM public.sales_simple
     WHERE agency_id = p_user AND status <> 'cancelado' AND created_at >= v_month;
    IF v_has_sub AND v_sub.plan = 'promotor' THEN
      v_status := 'activo';
    ELSE
      v_status := 'gratis';
      v_limit := public.setting_int('plan_promotor_free_limit', 30);
    END IF;

  ELSE
    v_status := 'sin_plan'; v_reason := 'PLAN_INACTIVE';
  END IF;

  -- Con p_quantity = 0 pregunta si puede vender al menos uno más
  IF v_reason IS NULL AND v_limit IS NOT NULL AND v_used + greatest(p_quantity, 1) > v_limit THEN
    v_reason := 'PLAN_LIMIT';
  END IF;

  RETURN jsonb_build_object(
    'role',            v_role,
    'status',          v_status,
    'plan',            CASE WHEN v_has_sub THEN v_sub.plan END,
    'billing',         CASE WHEN v_has_sub THEN v_sub.billing END,
    'units',           CASE WHEN v_has_sub THEN v_sub.units END,
    'expires_at',      CASE WHEN v_has_sub THEN v_sub.expires_at END,
    'trial_ends_at',   v_trial,
    'monthly_limit',   v_limit,
    'used_this_month', v_used,
    'chivas',          v_chivas,
    'can_sell',        v_reason IS NULL,
    'reason',          v_reason
  );
END;
$$;
REVOKE ALL ON FUNCTION public.seller_plan(uuid, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.seller_plan(uuid, int) TO service_role;

-- El panel consulta solo su propio plan
CREATE OR REPLACE FUNCTION public.my_plan()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.seller_plan(auth.uid(), 0);
$$;
REVOKE ALL ON FUNCTION public.my_plan() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_plan() TO authenticated, service_role;

-- ---- El bloqueo ----
CREATE OR REPLACE FUNCTION public.assert_can_sell(p_user uuid, p_quantity int)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v jsonb := public.seller_plan(p_user, p_quantity);
BEGIN
  IF NOT (v->>'can_sell')::boolean THEN
    RAISE EXCEPTION '%', v->>'reason' USING ERRCODE = 'P0001';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.assert_can_sell(uuid, int) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.enforce_seller_plan()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_TABLE_NAME = 'sales_simple' THEN
    PERFORM public.assert_can_sell(NEW.owner_id, public.sale_seat_count(NEW.seats));
    IF NEW.agency_id IS NOT NULL THEN
      PERFORM public.assert_can_sell(NEW.agency_id, public.sale_seat_count(NEW.seats));
    END IF;
  ELSE
    PERFORM public.assert_can_sell(NEW.owner_id, NEW.quantity);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.enforce_seller_plan() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_enforce_seller_plan ON public.sales_simple;
CREATE TRIGGER trg_enforce_seller_plan
  BEFORE INSERT ON public.sales_simple
  FOR EACH ROW EXECUTE FUNCTION public.enforce_seller_plan();

DROP TRIGGER IF EXISTS trg_enforce_seller_plan ON public.business_tickets;
CREATE TRIGGER trg_enforce_seller_plan
  BEFORE INSERT ON public.business_tickets
  FOR EACH ROW EXECUTE FUNCTION public.enforce_seller_plan();

-- ---- Sin plan, la oferta deja de verse en la página pública ----
CREATE OR REPLACE FUNCTION public.seller_is_public(p_owner_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce((SELECT public_listing FROM public.panel_settings WHERE user_id = p_owner_id), true)
     AND public.seller_plan_active(p_owner_id);
$$;

DROP POLICY IF EXISTS "businesses: lectura pública" ON public.businesses;
CREATE POLICY "businesses: lectura pública" ON public.businesses FOR SELECT
  USING (active = true AND public.seller_plan_active(owner_id));

-- ---- Administración: activar o renovar un plan ----
-- Uso (SQL editor):
--   SELECT public.activate_subscription('correo@vendedor.com', 'chiva', 'mensual', 2, 80, 'TRX-123');
-- Si el plan sigue vigente, el periodo nuevo se suma al final del actual.
CREATE OR REPLACE FUNCTION public.activate_subscription(
  p_email       text,
  p_plan        text,
  p_billing     text    DEFAULT 'mensual',
  p_units       int     DEFAULT 1,
  p_amount      numeric DEFAULT NULL,
  p_payment_ref text    DEFAULT NULL
)
RETURNS public.subscriptions LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user uuid;
  v_role text;
  v_from timestamptz;
  v_row  public.subscriptions;
BEGIN
  SELECT id, role INTO v_user, v_role FROM public.users WHERE lower(email) = lower(trim(p_email));
  IF NOT FOUND THEN RAISE EXCEPTION 'USER_NOT_FOUND'; END IF;

  IF NOT (   (v_role = 'dueño'   AND p_plan = 'chiva')
          OR (v_role = 'negocio' AND p_plan IN ('establecimiento', 'establecimiento_plus'))
          OR (v_role = 'agencia' AND p_plan = 'promotor')) THEN
    RAISE EXCEPTION 'PLAN_NOT_FOR_ROLE: % no aplica al rol %', p_plan, v_role;
  END IF;

  SELECT greatest(now(), expires_at) INTO v_from
    FROM public.subscriptions
   WHERE user_id = v_user AND status = 'activo' AND expires_at > now();
  v_from := coalesce(v_from, now());

  INSERT INTO public.subscriptions (user_id, plan, billing, units, status, started_at, expires_at, amount_paid, payment_ref)
  VALUES (v_user, p_plan, p_billing, p_units, 'activo', now(),
          v_from + CASE WHEN p_billing = 'anual' THEN interval '1 year' ELSE interval '1 month' END,
          p_amount, p_payment_ref)
  ON CONFLICT (user_id) DO UPDATE SET
    plan        = EXCLUDED.plan,
    billing     = EXCLUDED.billing,
    units       = EXCLUDED.units,
    status      = 'activo',
    expires_at  = EXCLUDED.expires_at,
    amount_paid = EXCLUDED.amount_paid,
    payment_ref = EXCLUDED.payment_ref
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$$;
REVOKE ALL ON FUNCTION public.activate_subscription(text, text, text, int, numeric, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.activate_subscription(text, text, text, int, numeric, text) TO service_role;
