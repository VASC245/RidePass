-- Cargo por servicio al comprador en ventas web (8 % + $0,30, redondeado a
-- 5 centavos). El vendedor recibe su precio íntegro; el cargo lo paga el
-- turista y se cobra igual en tarjeta y transferencia. No aplica a ventas
-- en efectivo del dueño ni a ventas de promotores/agencias.
--
-- Cálculo siempre en la base de datos: el navegador solo lo muestra.

INSERT INTO public.app_settings (key, value, description) VALUES
  ('platform_fee_pct',         '8',  'Cargo por servicio al comprador: porcentaje sobre el precio del vendedor'),
  ('platform_fee_fixed_cents', '30', 'Cargo por servicio al comprador: parte fija en centavos')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.platform_fee(p_amount numeric)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT CASE
    WHEN p_amount IS NULL OR p_amount <= 0 THEN 0
    ELSE round(
      (p_amount * public.setting_int('platform_fee_pct', 8) / 100.0
       + public.setting_int('platform_fee_fixed_cents', 30) / 100.0) / 0.05
    ) * 0.05
  END;
$$;
REVOKE ALL ON FUNCTION public.platform_fee(numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.platform_fee(numeric) TO anon, authenticated, service_role;

ALTER TABLE public.sales_simple     ADD COLUMN IF NOT EXISTS platform_fee  numeric NOT NULL DEFAULT 0;
ALTER TABLE public.sales_simple     ADD COLUMN IF NOT EXISTS total_charged numeric;
ALTER TABLE public.business_tickets ADD COLUMN IF NOT EXISTS platform_fee  numeric NOT NULL DEFAULT 0;
ALTER TABLE public.business_tickets ADD COLUMN IF NOT EXISTS total_charged numeric;
UPDATE public.sales_simple     SET total_charged = total_sale  WHERE total_charged IS NULL;
UPDATE public.business_tickets SET total_charged = total_price WHERE total_charged IS NULL;

ALTER TABLE public.owner_balance  ADD COLUMN IF NOT EXISTS platform_fee  numeric NOT NULL DEFAULT 0;
ALTER TABLE public.owner_balance  ADD COLUMN IF NOT EXISTS fee_collected boolean NOT NULL DEFAULT false;
ALTER TABLE public.agency_balance ADD COLUMN IF NOT EXISTS platform_fee  numeric NOT NULL DEFAULT 0;

-- ================================================================
-- reserve_tour_seats: calcula y guarda el cargo
-- ================================================================
CREATE OR REPLACE FUNCTION public.reserve_tour_seats(
  p_assigned_chiva_id uuid, p_seats integer[], p_customer jsonb,
  p_agency_id uuid DEFAULT NULL, p_status text DEFAULT 'pendiente',
  p_payment_method text DEFAULT 'transferencia', p_payment_ref text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ac       record;
  v_ctl      jsonb;
  v_price    numeric;
  v_amount   numeric;
  v_fee      numeric;
  v_sale_id  uuid;
  v_locked   int;
  v_seat_status text;
  v_owner_cash boolean;
BEGIN
  IF p_seats IS NULL OR array_length(p_seats, 1) IS NULL THEN RAISE EXCEPTION 'SEATS_REQUIRED'; END IF;
  IF p_status NOT IN ('pendiente', 'pagado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;
  IF p_payment_method NOT IN ('transferencia', 'tarjeta', 'efectivo') THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;

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
  IF v_ac.status NOT IN ('pendiente', 'en_curso') OR v_ac.departure_at < now() THEN RAISE EXCEPTION 'TOUR_UNAVAILABLE'; END IF;

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
  -- Cargo por servicio solo en ventas web del público (ni efectivo ni agencia)
  v_fee := CASE WHEN p_agency_id IS NULL AND NOT v_owner_cash THEN public.platform_fee(v_amount) ELSE 0 END;

  INSERT INTO public.sales_simple (
    assigned_chiva_id, tour_id, owner_id, agency_id, seats,
    sale_price, total_sale, owner_gain, agency_gain, status,
    customer_name, customer_cedula, customer_phone, customer_email, customer_address,
    payment_method, payment_ref, platform_fee, total_charged
  ) VALUES (
    v_ac.id, v_ac.tour_id, v_ac.owner_id, p_agency_id, to_jsonb(p_seats),
    v_price, v_amount, v_amount, 0, p_status,
    p_customer->>'name', p_customer->>'cedula', p_customer->>'phone',
    lower(p_customer->>'email'), p_customer->>'address',
    p_payment_method, p_payment_ref, v_fee, v_amount + v_fee
  ) RETURNING id INTO v_sale_id;

  UPDATE public.sales_simple SET qr_payload = jsonb_build_object('type', 'chiva_sale', 'sale_id', v_sale_id)::text WHERE id = v_sale_id;

  v_seat_status := CASE WHEN p_status = 'pagado' THEN 'pagado' ELSE 'reservado' END;
  UPDATE public.seats SET status = v_seat_status, sale_id = v_sale_id
   WHERE assigned_chiva_id = p_assigned_chiva_id AND seat_number = ANY(p_seats) AND status = 'disponible';
  GET DIAGNOSTICS v_locked = ROW_COUNT;
  IF v_locked <> array_length(p_seats, 1) THEN RAISE EXCEPTION 'SEATS_UNAVAILABLE'; END IF;

  RETURN jsonb_build_object(
    'sale_id', v_sale_id, 'amount', v_amount, 'fee', v_fee, 'total_charged', v_amount + v_fee,
    'unit_price', v_price, 'owner_id', v_ac.owner_id,
    'tour_title', v_ac.tour_title, 'chiva_name', v_ac.chiva_name, 'departure_at', v_ac.departure_at,
    'qr_payload', jsonb_build_object('type', 'chiva_sale', 'sale_id', v_sale_id)::text
  );
END;
$$;

-- ================================================================
-- create_business_ticket: las entradas de atracciones solo se venden en la
-- web, así que el cargo aplica siempre.
-- ================================================================
CREATE OR REPLACE FUNCTION public.create_business_ticket(
  p_event_id uuid, p_quantity integer, p_customer jsonb,
  p_status text DEFAULT 'pendiente', p_proof_number text DEFAULT NULL, p_proof_path text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ev record; v_ctl jsonb; v_sold int; v_amount numeric; v_fee numeric; v_id uuid; v_qr text;
BEGIN
  IF p_quantity IS NULL OR p_quantity < 1 THEN RAISE EXCEPTION 'QUANTITY_REQUIRED'; END IF;
  IF p_status NOT IN ('pendiente', 'verificado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;

  SELECT e.id, e.title, e.price, e.capacity, e.status, e.event_date, e.business_id,
         b.name AS business_name, b.owner_id, b.active AS business_active
    INTO v_ev
    FROM public.business_events e JOIN public.businesses b ON b.id = e.business_id
   WHERE e.id = p_event_id FOR UPDATE OF e;

  IF NOT FOUND THEN RAISE EXCEPTION 'EVENT_NOT_FOUND'; END IF;
  IF NOT v_ev.business_active THEN RAISE EXCEPTION 'SALES_CLOSED'; END IF;
  IF v_ev.status <> 'activo' THEN RAISE EXCEPTION 'EVENT_INACTIVE'; END IF;
  IF v_ev.event_date < now() THEN RAISE EXCEPTION 'EVENT_PAST'; END IF;

  v_ctl := public.seller_controls(v_ev.owner_id);
  IF p_proof_path IS NULL AND NOT (v_ctl->>'accept_cards')::boolean THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
  IF p_proof_path IS NOT NULL AND NOT (v_ctl->>'accept_transfers')::boolean THEN RAISE EXCEPTION 'METHOD_DISABLED'; END IF;
  IF NOT public.seller_hours_open(v_ev.owner_id) THEN RAISE EXCEPTION 'OUTSIDE_HOURS'; END IF;

  SELECT coalesce(sum(quantity), 0) INTO v_sold FROM public.business_tickets WHERE event_id = p_event_id AND payment_status <> 'rechazado';
  IF v_sold + p_quantity > v_ev.capacity THEN RAISE EXCEPTION 'CAPACITY_EXCEEDED'; END IF;

  v_amount := v_ev.price * p_quantity;
  v_fee    := public.platform_fee(v_amount);
  v_id := gen_random_uuid();
  v_qr := jsonb_build_object('type', 'business_ticket', 'ticket_id', v_id)::text;

  INSERT INTO public.business_tickets (
    id, event_id, business_id, owner_id, customer_name, customer_email, customer_cedula, customer_phone,
    quantity, unit_price, total_price, payment_proof_path, payment_proof_url, payment_number, payment_status, qr_payload,
    platform_fee, total_charged
  ) VALUES (
    v_id, v_ev.id, v_ev.business_id, v_ev.owner_id,
    p_customer->>'name', lower(p_customer->>'email'), p_customer->>'cedula', p_customer->>'phone',
    p_quantity, v_ev.price, v_amount, p_proof_path, p_proof_path, p_proof_number, p_status, v_qr,
    v_fee, v_amount + v_fee
  );

  IF v_sold + p_quantity >= v_ev.capacity THEN UPDATE public.business_events SET status = 'agotado' WHERE id = p_event_id; END IF;

  RETURN jsonb_build_object(
    'ticket_id', v_id, 'amount', v_amount, 'fee', v_fee, 'total_charged', v_amount + v_fee,
    'unit_price', v_ev.price, 'owner_id', v_ev.owner_id,
    'business_name', v_ev.business_name, 'event_title', v_ev.title, 'event_date', v_ev.event_date, 'qr_payload', v_qr
  );
END;
$$;

-- ================================================================
-- Libro de saldos: guarda el cargo y si ya quedó cobrado (tarjeta) o
-- pendiente de compensar en el estado de cuenta (transferencia).
-- ================================================================
CREATE OR REPLACE FUNCTION public.record_sale_balance()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_comprobante uuid;
BEGIN
  IF NEW.status = 'pagado' AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'pagado') THEN
    SELECT id INTO v_comprobante FROM public.pending_payments
     WHERE sale_id = NEW.id ORDER BY created_at DESC LIMIT 1;

    INSERT INTO public.owner_balance (owner_id, assigned_chiva_id, comprobante_id, boletos_vendidos, monto_total,
                                      sale_id, payment_method, platform_fee, fee_collected)
    VALUES (NEW.owner_id, NEW.assigned_chiva_id, v_comprobante, public.sale_seat_count(NEW.seats),
            coalesce(NEW.owner_gain, NEW.total_sale, 0), NEW.id, NEW.payment_method,
            coalesce(NEW.platform_fee, 0), NEW.payment_method = 'tarjeta')
    ON CONFLICT (sale_id) WHERE sale_id IS NOT NULL DO NOTHING;

    IF NEW.agency_id IS NOT NULL THEN
      INSERT INTO public.agency_balance (agency_id, assigned_chiva_id, comprobante_id, boletos_vendidos, monto_total, sale_id, payment_method)
      VALUES (NEW.agency_id, NEW.assigned_chiva_id, v_comprobante, public.sale_seat_count(NEW.seats),
              coalesce(NEW.agency_gain, 0), NEW.id, NEW.payment_method)
      ON CONFLICT (sale_id) WHERE sale_id IS NOT NULL DO NOTHING;
    END IF;

  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pagado' AND NEW.status IN ('cancelado', 'rechazado', 'expirado') THEN
    DELETE FROM public.owner_balance  WHERE sale_id = NEW.id;
    DELETE FROM public.agency_balance WHERE sale_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

-- ================================================================
-- Ticket público y Mis entradas: total = lo que pagó el comprador
-- ================================================================
CREATE OR REPLACE FUNCTION public.get_public_ticket(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public AS $$
DECLARE v jsonb;
BEGIN
  SELECT jsonb_build_object(
    'kind', 'business', 'id', t.id, 'customer_name', t.customer_name,
    'quantity', t.quantity, 'subtotal', t.total_price, 'fee', t.platform_fee,
    'total', coalesce(t.total_charged, t.total_price),
    'qr_payload', t.qr_payload, 'used', t.used,
    'title', e.title, 'date', e.event_date, 'place', b.name
  ) INTO v
  FROM public.business_tickets t
  JOIN public.business_events e ON e.id = t.event_id
  JOIN public.businesses b ON b.id = t.business_id
  WHERE t.id = p_id AND t.payment_status = 'verificado';
  IF v IS NOT NULL THEN RETURN v; END IF;

  SELECT jsonb_build_object(
    'kind', 'tour', 'id', s.id, 'customer_name', s.customer_name,
    'quantity', public.sale_seat_count(s.seats), 'seats', s.seats,
    'subtotal', s.total_sale, 'fee', s.platform_fee, 'total', coalesce(s.total_charged, s.total_sale),
    'qr_payload', s.qr_payload, 'used', s.boarded_at IS NOT NULL,
    'title', tr.title, 'date', ac.departure_at, 'place', c.name
  ) INTO v
  FROM public.sales_simple s
  JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
  LEFT JOIN public.tours tr ON tr.id = s.tour_id
  LEFT JOIN public.chivas c ON c.id = ac.chiva_id
  WHERE s.id = p_id AND s.status = 'pagado';
  RETURN v;
END;
$$;

DROP FUNCTION IF EXISTS public.get_my_tickets();
CREATE FUNCTION public.get_my_tickets()
RETURNS TABLE (
  kind text, id uuid, title text, place text, date timestamptz,
  quantity integer, seats jsonb, subtotal numeric, fee numeric, total numeric, ref text,
  status text, used boolean, created_at timestamptz
)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT 'business', t.id, e.title, b.name, e.event_date,
         t.quantity, NULL::jsonb, t.total_price, t.platform_fee, coalesce(t.total_charged, t.total_price), t.payment_number,
         t.payment_status, coalesce(t.used, false), t.created_at
  FROM public.business_tickets t
  LEFT JOIN public.business_events e ON e.id = t.event_id
  LEFT JOIN public.businesses b ON b.id = t.business_id
  WHERE auth.email() IS NOT NULL AND lower(t.customer_email) = lower(auth.email())
  UNION ALL
  SELECT 'tour', s.id, tr.title, c.name, ac.departure_at,
         public.sale_seat_count(s.seats), s.seats, s.total_sale, s.platform_fee, coalesce(s.total_charged, s.total_sale), s.payment_ref,
         CASE s.status WHEN 'pendiente' THEN 'pendiente'
                       WHEN 'pagado' THEN 'verificado'
                       WHEN 'abordado' THEN 'verificado'
                       ELSE 'rechazado' END,
         (s.status = 'abordado' OR s.boarded_at IS NOT NULL), s.created_at
  FROM public.sales_simple s
  LEFT JOIN public.tours tr ON tr.id = s.tour_id
  LEFT JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
  LEFT JOIN public.chivas c ON c.id = ac.chiva_id
  WHERE auth.email() IS NOT NULL AND lower(s.customer_email) = lower(auth.email())
  ORDER BY created_at DESC
$$;
REVOKE ALL ON FUNCTION public.get_my_tickets() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_tickets() TO authenticated, service_role;
