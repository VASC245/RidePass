-- ================================================================
-- Sobreprecio de agencias (11 nov 2026)
--
-- Una agencia vende un tour al precio que ella decide (desde el precio
-- del dueño hasta el triple, máx. $1000). El turista paga ese precio, el
-- dueño recibe su precio y la agencia se queda con la diferencia:
--   total_sale  = precio de la agencia × asientos
--   owner_gain  = precio del dueño × asientos (lo que la agencia le transfiere)
--   agency_gain = total_sale − owner_gain
-- Antes agency_gain siempre era 0. Los saldos (owner_balance,
-- agency_balance) y el estado de cuenta ya usan owner_gain/agency_gain.
--
-- Se borra la firma de 7 parámetros: con las dos firmas PostgREST no
-- sabría cuál llamar desde las edge functions.
-- ================================================================

DROP FUNCTION IF EXISTS public.reserve_tour_seats(uuid, integer[], jsonb, uuid, text, text, text);

CREATE FUNCTION public.reserve_tour_seats(p_assigned_chiva_id uuid, p_seats integer[], p_customer jsonb, p_agency_id uuid DEFAULT NULL::uuid, p_status text DEFAULT 'pendiente'::text, p_payment_method text DEFAULT 'transferencia'::text, p_payment_ref text DEFAULT NULL::text, p_agency_price numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ac       record;
  v_ctl      jsonb;
  v_price    numeric;
  v_unit     numeric;
  v_owner_amount numeric;
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
    -- El cron libera las transferencias sin verificar a este margen de la
    -- salida: venderlas dentro de él era cobrar y anular el asiento.
    IF p_payment_method = 'transferencia'
       AND v_ac.departure_at - now() < make_interval(mins => public.setting_int('reservation_release_before_departure_minutes', 60)) THEN
      RAISE EXCEPTION 'TRANSFER_CLOSED';
    END IF;
  ELSIF NOT (v_ctl->>'accept_cash')::boolean THEN
    RAISE EXCEPTION 'METHOD_DISABLED';
  END IF;

  v_price  := coalesce(v_ac.base_price, 0);
  IF v_price <= 0 THEN RAISE EXCEPTION 'TOUR_WITHOUT_PRICE'; END IF;

  -- Sobreprecio de agencia: el dueño recibe su precio y la agencia se
  -- queda con la diferencia. Tope del triple para frenar errores de tipeo.
  IF p_agency_price IS NOT NULL THEN
    IF p_agency_id IS NULL THEN RAISE EXCEPTION 'AGENCY_PRICE_NOT_AGENCY'; END IF;
    IF p_agency_price <> round(p_agency_price, 2)
       OR p_agency_price < v_price
       OR p_agency_price > least(v_price * 3, 1000) THEN
      RAISE EXCEPTION 'AGENCY_PRICE_INVALID';
    END IF;
  END IF;
  v_unit         := coalesce(p_agency_price, v_price);
  v_owner_amount := v_price * array_length(p_seats, 1);
  v_amount       := v_unit  * array_length(p_seats, 1);
  v_fee := CASE WHEN p_agency_id IS NULL AND NOT v_owner_cash THEN public.platform_fee(v_amount) ELSE 0 END;

  INSERT INTO public.sales_simple (
    assigned_chiva_id, tour_id, owner_id, agency_id, seats,
    sale_price, total_sale, owner_gain, agency_gain, status,
    customer_name, customer_cedula, customer_phone, customer_email, customer_address,
    payment_method, payment_ref, platform_fee, total_charged
  ) VALUES (
    v_ac.id, v_ac.tour_id, v_ac.owner_id, p_agency_id, to_jsonb(p_seats),
    v_unit, v_amount, v_owner_amount, v_amount - v_owner_amount, p_status,
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
    'unit_price', v_unit, 'owner_price', v_price, 'owner_id', v_ac.owner_id,
    'owner_amount', v_owner_amount, 'agency_amount', v_amount - v_owner_amount,
    'tour_title', v_ac.tour_title, 'chiva_name', v_ac.chiva_name, 'departure_at', v_ac.departure_at,
    'qr_payload', jsonb_build_object('type', 'chiva_sale', 'sale_id', v_sale_id)::text
  );
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_tour_seats(uuid, integer[], jsonb, uuid, text, text, text, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_tour_seats(uuid, integer[], jsonb, uuid, text, text, text, numeric) TO service_role;
