-- ================================================================
-- Controles del dueño: qué está activo, qué se vende y cuándo
--
--   tours.active               → el tour aparece y se vende (o no)
--   tours.allow_agency_sales   → las agencias pueden venderlo (o no)
--   assigned_chivas.sales_open → ventas abiertas/cerradas por salida
--   panel_settings:
--     public_listing           → mis tours aparecen en la página pública
--     accept_transfers / accept_cards / accept_cash
--     enforce_hours + hours_open/hours_close (hora de Ecuador)
--     close_sales_minutes_before → cerrar ventas N minutos antes de salir
--
-- Todo se aplica en la base de datos (reserve_tour_seats y políticas de
-- lectura pública), así que ningún cliente puede saltárselo.
-- ================================================================

ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS active             boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS allow_agency_sales boolean NOT NULL DEFAULT true;

ALTER TABLE public.assigned_chivas
  ADD COLUMN IF NOT EXISTS sales_open boolean NOT NULL DEFAULT true;

ALTER TABLE public.panel_settings
  ADD COLUMN IF NOT EXISTS public_listing             boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS accept_transfers           boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS accept_cards               boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS accept_cash                boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS enforce_hours              boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS hours_open                 time    NOT NULL DEFAULT '07:00',
  ADD COLUMN IF NOT EXISTS hours_close                time    NOT NULL DEFAULT '19:00',
  ADD COLUMN IF NOT EXISTS hours_note                 text    NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS close_sales_minutes_before int     NOT NULL DEFAULT 0 CHECK (close_sales_minutes_before >= 0);

CREATE INDEX IF NOT EXISTS idx_tours_owner_active ON public.tours(user_id) WHERE active;

-- Controles del vendedor con valores por defecto si aún no configuró nada
CREATE OR REPLACE FUNCTION public.seller_controls(p_owner_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce(
    (SELECT jsonb_build_object(
        'public_listing', public_listing,
        'accept_transfers', accept_transfers,
        'accept_cards', accept_cards,
        'accept_cash', accept_cash,
        'enforce_hours', enforce_hours,
        'hours_open', to_char(hours_open, 'HH24:MI'),
        'hours_close', to_char(hours_close, 'HH24:MI'),
        'hours_note', hours_note,
        'close_sales_minutes_before', close_sales_minutes_before)
       FROM public.panel_settings WHERE user_id = p_owner_id),
    '{"public_listing":true,"accept_transfers":true,"accept_cards":true,"accept_cash":true,"enforce_hours":false,"hours_open":"07:00","hours_close":"19:00","hours_note":"","close_sales_minutes_before":0}'::jsonb
  );
$$;
REVOKE ALL ON FUNCTION public.seller_controls(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seller_controls(uuid) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.seller_is_public(p_owner_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT coalesce((SELECT public_listing FROM public.panel_settings WHERE user_id = p_owner_id), true);
$$;
REVOKE ALL ON FUNCTION public.seller_is_public(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seller_is_public(uuid) TO anon, authenticated, service_role;

-- ¿Está abierta la venta ahora mismo según el horario del vendedor?
CREATE OR REPLACE FUNCTION public.seller_hours_open(p_owner_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  c jsonb := public.seller_controls(p_owner_id);
  t time := (now() AT TIME ZONE 'America/Guayaquil')::time;
  o time := (c->>'hours_open')::time;
  cl time := (c->>'hours_close')::time;
BEGIN
  IF NOT (c->>'enforce_hours')::boolean THEN RETURN true; END IF;
  IF o <= cl THEN RETURN t >= o AND t <= cl; END IF;
  -- horario que cruza medianoche
  RETURN t >= o OR t <= cl;
END;
$$;
REVOKE ALL ON FUNCTION public.seller_hours_open(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.seller_hours_open(uuid) TO anon, authenticated, service_role;

-- ---- Lectura pública respeta los controles ----
DROP POLICY IF EXISTS "tours: lectura pública" ON public.tours;
CREATE POLICY "tours: lectura pública" ON public.tours FOR SELECT
  USING (active AND public.seller_is_public(user_id));

DROP POLICY IF EXISTS "assigned: lectura pública" ON public.assigned_chivas;
CREATE POLICY "assigned: lectura pública" ON public.assigned_chivas FOR SELECT
  USING (
    sales_open
    AND public.seller_is_public(owner_id)
    AND EXISTS (SELECT 1 FROM public.tours t WHERE t.id = tour_id AND t.active)
  );

-- El conductor ve las salidas de su chiva aunque estén cerradas al público
DROP POLICY IF EXISTS "assigned: conductor lee" ON public.assigned_chivas;
CREATE POLICY "assigned: conductor lee" ON public.assigned_chivas FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.drivers d WHERE d.chiva_id = assigned_chivas.chiva_id AND d.user_id = auth.uid()));

-- ---- Datos para el checkout: bancarios + controles ----
CREATE OR REPLACE FUNCTION public.get_seller_payment_info(p_owner_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT coalesce(
    (SELECT jsonb_build_object(
      'bank_name', bank_name, 'bank_account', bank_account, 'bank_owner', bank_owner,
      'bank_type', bank_type, 'notes', notes, 'business_name', business_name)
     FROM public.panel_settings WHERE user_id = p_owner_id),
    '{}'::jsonb
  ) || public.seller_controls(p_owner_id) || jsonb_build_object('hours_open_now', public.seller_hours_open(p_owner_id));
$$;

-- ---- reserve_tour_seats aplica los controles ----
CREATE OR REPLACE FUNCTION public.reserve_tour_seats(
  p_assigned_chiva_id uuid,
  p_seats             int[],
  p_customer          jsonb,
  p_agency_id         uuid DEFAULT NULL,
  p_status            text DEFAULT 'pendiente',
  p_payment_method    text DEFAULT 'transferencia',
  p_payment_ref       text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ac       record;
  v_ctl      jsonb;
  v_price    numeric;
  v_amount   numeric;
  v_sale_id  uuid;
  v_locked   int;
  v_seat_status text;
  v_owner_cash boolean;
BEGIN
  IF p_seats IS NULL OR array_length(p_seats, 1) IS NULL THEN
    RAISE EXCEPTION 'SEATS_REQUIRED';
  END IF;
  IF p_status NOT IN ('pendiente', 'pagado') THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;
  IF p_payment_method NOT IN ('transferencia', 'tarjeta', 'efectivo') THEN
    RAISE EXCEPTION 'METHOD_DISABLED';
  END IF;

  -- Bloquea la salida: serializa reservas concurrentes sobre la misma chiva
  SELECT ac.id, ac.owner_id, ac.tour_id, ac.departure_at, ac.status, ac.sales_open,
         t.title AS tour_title, t.base_price, t.active AS tour_active, t.allow_agency_sales,
         c.name AS chiva_name
    INTO v_ac
    FROM public.assigned_chivas ac
    JOIN public.tours  t ON t.id = ac.tour_id
    JOIN public.chivas c ON c.id = ac.chiva_id
   WHERE ac.id = p_assigned_chiva_id
   FOR UPDATE OF ac;

  IF NOT FOUND THEN RAISE EXCEPTION 'TOUR_NOT_FOUND'; END IF;
  IF v_ac.status NOT IN ('pendiente', 'en_curso') OR v_ac.departure_at < now() THEN
    RAISE EXCEPTION 'TOUR_UNAVAILABLE';
  END IF;

  -- Controles del dueño. La venta en efectivo del propio dueño solo
  -- respeta que el tour exista y esté activo.
  v_ctl := public.seller_controls(v_ac.owner_id);
  v_owner_cash := (p_payment_method = 'efectivo');

  IF NOT v_ac.tour_active THEN RAISE EXCEPTION 'SALES_CLOSED'; END IF;
  IF NOT v_owner_cash THEN
    IF NOT v_ac.sales_open THEN RAISE EXCEPTION 'SALES_CLOSED'; END IF;
    IF (v_ctl->>'close_sales_minutes_before')::int > 0
       AND v_ac.departure_at - now() < make_interval(mins => (v_ctl->>'close_sales_minutes_before')::int) THEN
      RAISE EXCEPTION 'SALES_CLOSED';
    END IF;
    IF NOT public.seller_hours_open(v_ac.owner_id) THEN RAISE EXCEPTION 'OUTSIDE_HOURS'; END IF;
    IF p_agency_id IS NOT NULL AND NOT v_ac.allow_agency_sales THEN RAISE EXCEPTION 'AGENCY_DISABLED'; END IF;
    IF p_payment_method = 'transferencia' AND NOT (v_ctl->>'accept_transfers')::boolean THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
    IF p_payment_method = 'tarjeta'       AND NOT (v_ctl->>'accept_cards')::boolean     THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
  ELSIF NOT (v_ctl->>'accept_cash')::boolean THEN
    RAISE EXCEPTION 'METHOD_DISABLED';
  END IF;

  v_price  := coalesce(v_ac.base_price, 0);
  IF v_price <= 0 THEN RAISE EXCEPTION 'TOUR_WITHOUT_PRICE'; END IF;
  v_amount := v_price * array_length(p_seats, 1);

  INSERT INTO public.sales_simple (
    assigned_chiva_id, tour_id, owner_id, agency_id, seats,
    sale_price, total_sale, owner_gain, agency_gain, status,
    customer_name, customer_cedula, customer_phone, customer_email, customer_address,
    payment_method, payment_ref
  ) VALUES (
    v_ac.id, v_ac.tour_id, v_ac.owner_id, p_agency_id, to_jsonb(p_seats),
    v_price, v_amount, v_amount, 0, p_status,
    p_customer->>'name', p_customer->>'cedula', p_customer->>'phone',
    lower(p_customer->>'email'), p_customer->>'address',
    p_payment_method, p_payment_ref
  ) RETURNING id INTO v_sale_id;

  UPDATE public.sales_simple
     SET qr_payload = jsonb_build_object('type', 'chiva_sale', 'sale_id', v_sale_id)::text
   WHERE id = v_sale_id;

  v_seat_status := CASE WHEN p_status = 'pagado' THEN 'pagado' ELSE 'reservado' END;

  UPDATE public.seats
     SET status = v_seat_status, sale_id = v_sale_id
   WHERE assigned_chiva_id = p_assigned_chiva_id
     AND seat_number = ANY(p_seats)
     AND status = 'disponible';
  GET DIAGNOSTICS v_locked = ROW_COUNT;

  IF v_locked <> array_length(p_seats, 1) THEN
    RAISE EXCEPTION 'SEATS_UNAVAILABLE';
  END IF;

  RETURN jsonb_build_object(
    'sale_id',      v_sale_id,
    'amount',       v_amount,
    'unit_price',   v_price,
    'owner_id',     v_ac.owner_id,
    'tour_title',   v_ac.tour_title,
    'chiva_name',   v_ac.chiva_name,
    'departure_at', v_ac.departure_at,
    'qr_payload',   jsonb_build_object('type', 'chiva_sale', 'sale_id', v_sale_id)::text
  );
END;
$$;

-- Eventos de negocio: mismos controles de método de pago
CREATE OR REPLACE FUNCTION public.create_business_ticket(
  p_event_id     uuid,
  p_quantity     int,
  p_customer     jsonb,
  p_status       text DEFAULT 'pendiente',
  p_proof_number text DEFAULT NULL,
  p_proof_path   text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ev      record;
  v_ctl     jsonb;
  v_sold    int;
  v_amount  numeric;
  v_id      uuid;
  v_qr      text;
BEGIN
  IF p_quantity IS NULL OR p_quantity < 1 THEN RAISE EXCEPTION 'QUANTITY_REQUIRED'; END IF;
  IF p_status NOT IN ('pendiente', 'verificado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;

  SELECT e.id, e.title, e.price, e.capacity, e.status, e.event_date, e.business_id,
         b.name AS business_name, b.owner_id, b.active AS business_active
    INTO v_ev
    FROM public.business_events e
    JOIN public.businesses b ON b.id = e.business_id
   WHERE e.id = p_event_id
   FOR UPDATE OF e;

  IF NOT FOUND THEN RAISE EXCEPTION 'EVENT_NOT_FOUND'; END IF;
  IF NOT v_ev.business_active THEN RAISE EXCEPTION 'SALES_CLOSED'; END IF;
  IF v_ev.status <> 'activo' THEN RAISE EXCEPTION 'EVENT_INACTIVE'; END IF;
  IF v_ev.event_date < now() THEN RAISE EXCEPTION 'EVENT_PAST'; END IF;

  v_ctl := public.seller_controls(v_ev.owner_id);
  -- p_proof_path NULL = pago con tarjeta; con comprobante = transferencia
  IF p_proof_path IS NULL AND NOT (v_ctl->>'accept_cards')::boolean THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
  IF p_proof_path IS NOT NULL AND NOT (v_ctl->>'accept_transfers')::boolean THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
  IF NOT public.seller_hours_open(v_ev.owner_id) THEN RAISE EXCEPTION 'OUTSIDE_HOURS'; END IF;

  SELECT coalesce(sum(quantity), 0) INTO v_sold
    FROM public.business_tickets
   WHERE event_id = p_event_id AND payment_status <> 'rechazado';

  IF v_sold + p_quantity > v_ev.capacity THEN RAISE EXCEPTION 'CAPACITY_EXCEEDED'; END IF;

  v_amount := v_ev.price * p_quantity;
  v_id     := gen_random_uuid();
  v_qr     := jsonb_build_object('type', 'business_ticket', 'ticket_id', v_id)::text;

  INSERT INTO public.business_tickets (
    id, event_id, business_id, owner_id,
    customer_name, customer_email, customer_cedula, customer_phone,
    quantity, unit_price, total_price,
    payment_proof_path, payment_proof_url, payment_number, payment_status, qr_payload
  ) VALUES (
    v_id, v_ev.id, v_ev.business_id, v_ev.owner_id,
    p_customer->>'name', lower(p_customer->>'email'), p_customer->>'cedula', p_customer->>'phone',
    p_quantity, v_ev.price, v_amount,
    p_proof_path, p_proof_path, p_proof_number, p_status, v_qr
  );

  IF v_sold + p_quantity >= v_ev.capacity THEN
    UPDATE public.business_events SET status = 'agotado' WHERE id = p_event_id;
  END IF;

  RETURN jsonb_build_object(
    'ticket_id',     v_id,
    'amount',        v_amount,
    'unit_price',    v_ev.price,
    'owner_id',      v_ev.owner_id,
    'business_name', v_ev.business_name,
    'event_title',   v_ev.title,
    'event_date',    v_ev.event_date,
    'qr_payload',    v_qr
  );
END;
$$;

-- El conductor solo puede cambiar el estado de la salida, no los controles
CREATE OR REPLACE FUNCTION public.protect_departure_controls()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.is_api_client() AND auth.uid() IS DISTINCT FROM OLD.owner_id THEN
    NEW.sales_open   := OLD.sales_open;
    NEW.tour_id      := OLD.tour_id;
    NEW.chiva_id     := OLD.chiva_id;
    NEW.departure_at := OLD.departure_at;
    NEW.owner_id     := OLD.owner_id;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_protect_departure_controls ON public.assigned_chivas;
CREATE TRIGGER trg_protect_departure_controls
  BEFORE UPDATE ON public.assigned_chivas
  FOR EACH ROW EXECUTE FUNCTION public.protect_departure_controls();
REVOKE ALL ON FUNCTION public.protect_departure_controls() FROM PUBLIC, anon, authenticated;
