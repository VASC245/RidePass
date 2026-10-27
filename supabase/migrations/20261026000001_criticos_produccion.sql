-- ================================================================
-- Arreglos críticos antes de salir a producción (auditoría 26 oct 2026)
--
--  1. Transferencias: se cierran con el mismo margen con que el cron las
--     libera antes de la salida. Antes se vendía hasta la hora exacta y el
--     cron anulaba la reserva minutos después de que el turista pagó.
--  2. Cron de expiración: ya no cancela una venta que el dueño (o la
--     pasarela) confirmó mientras corría.
--  3. Entradas de negocio: solo pasan de 'pendiente' a verificado/rechazado.
--  4. users.email no se edita desde la API y es único sin distinguir
--     mayúsculas (la administración busca vendedores por correo).
--  5. Fuera las políticas que entregaban compras (con cédula y teléfono) a
--     quien inicie sesión con el correo del comprador, y la de insertar
--     perfiles a mano. El portal del cliente usa get_my_tickets().
--  6. Registro de agencias y negocios con código de invitación, igual que
--     los dueños. Sin código válido la cuenta queda como cliente.
--  7. Embarque: el QR solo sirve cerca de la hora de su salida.
--  8. Cambiar la capacidad de una chiva ajusta los asientos de sus salidas
--     próximas; una salida con ventas ya no cambia de tour, chiva ni hora.
--  9. Precios de eventos con mínimo y dos decimales; un comprobante no se
--     reutiliza en dos entradas.
-- 10. Comprobantes: la subida anónima directa al bucket se cierra. Ahora la
--     edge function public-reserve entrega una URL firmada de subida.
-- ================================================================

-- ─────────────── 1. Transferencias con margen antes de la salida ───────────────
CREATE OR REPLACE FUNCTION public.reserve_tour_seats(p_assigned_chiva_id uuid, p_seats integer[], p_customer jsonb, p_agency_id uuid DEFAULT NULL::uuid, p_status text DEFAULT 'pendiente'::text, p_payment_method text DEFAULT 'transferencia'::text, p_payment_ref text DEFAULT NULL::text)
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
  v_amount := v_price * array_length(p_seats, 1);
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

CREATE OR REPLACE FUNCTION public.create_business_ticket(p_event_id uuid, p_quantity integer, p_customer jsonb, p_status text DEFAULT 'pendiente'::text, p_proof_number text DEFAULT NULL::text, p_proof_path text DEFAULT NULL::text)
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
  IF p_proof_path IS NOT NULL
     AND v_ev.event_date - now() < make_interval(mins => public.setting_int('reservation_release_before_departure_minutes', 60)) THEN
    RAISE EXCEPTION 'TRANSFER_CLOSED';
  END IF;

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

-- ─────────────── 2. Cron sin pisar confirmaciones ───────────────
-- Cada UPDATE vuelve a exigir el estado pendiente: si el dueño verificó el
-- comprobante (o la pasarela confirmó) mientras el cron corría, la fila ya
-- no coincide y la venta pagada queda intacta.
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
  FOR v_sale IN
    SELECT s.id
      FROM public.sales_simple s
      JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
     WHERE s.status = 'pendiente'
       AND (
         (NOT EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.sale_id = s.id)
            AND s.created_at < now() - make_interval(mins => v_no_proof))
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

  WITH expired AS (
    UPDATE public.business_tickets
       SET payment_status = 'rechazado'
     WHERE payment_status = 'pendiente'
       AND payment_proof_path IS NULL
       AND created_at < now() - make_interval(mins => v_no_proof)
     RETURNING event_id
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

  RETURN jsonb_build_object('sales_released', v_sales, 'tickets_released', v_tickets, 'ran_at', now());
END;
$$;

-- ─────────────── 3. Entradas de negocio: solo desde 'pendiente' ───────────────
-- Antes se podía pasar una entrada cobrada a 'rechazado' (y salía del estado
-- de cuenta) o revivir una rechazada sin mirar el cupo.
CREATE OR REPLACE FUNCTION public.set_business_ticket_status(p_ticket_id uuid, p_status text, p_payment_ref text DEFAULT NULL::text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cur text; v_event uuid;
BEGIN
  IF p_status NOT IN ('verificado', 'rechazado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;
  SELECT payment_status, event_id INTO v_cur, v_event
    FROM public.business_tickets WHERE id = p_ticket_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'TICKET_NOT_FOUND'; END IF;
  IF v_cur = p_status THEN RETURN; END IF;
  IF v_cur <> 'pendiente' THEN RAISE EXCEPTION 'INVALID_TRANSITION'; END IF;

  UPDATE public.business_tickets
     SET payment_status = p_status,
         payment_number = coalesce(p_payment_ref, payment_number)
   WHERE id = p_ticket_id;
  IF p_status = 'rechazado' THEN
    UPDATE public.business_events SET status = 'activo'
     WHERE id = v_event AND status = 'agotado' AND event_date >= now();
  END IF;
END;
$$;

-- ─────────────── 4. users.email protegido y único sin mayúsculas ───────────────
CREATE OR REPLACE FUNCTION public.protect_user_privileges()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.is_api_client() THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'No puedes cambiar tu rol.' USING ERRCODE = '42501';
    END IF;
    IF NEW.plan IS DISTINCT FROM OLD.plan OR NEW.trial_ends_at IS DISTINCT FROM OLD.trial_ends_at THEN
      RAISE EXCEPTION 'El plan solo se cambia desde administración.' USING ERRCODE = '42501';
    END IF;
    IF NEW.email IS DISTINCT FROM OLD.email THEN
      RAISE EXCEPTION 'El correo no se cambia desde aquí.' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_key ON public.users (lower(email));

-- ─────────────── 5. Políticas por correo y alta manual de perfiles ───────────────
DROP POLICY IF EXISTS "btickets: customer email view" ON public.business_tickets;
DROP POLICY IF EXISTS "sales: customer email view"    ON public.sales_simple;
DROP POLICY IF EXISTS "users: insert registro"        ON public.users;

-- ─────────────── 6. Códigos de invitación por rol ───────────────
ALTER TABLE public.owner_invite_codes
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'dueño';
DO $$ BEGIN
  ALTER TABLE public.owner_invite_codes
    ADD CONSTRAINT owner_invite_codes_role_check CHECK (role IN ('dueño', 'agencia', 'negocio'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Conductor y cliente se registran libres (el conductor no ve nada hasta
-- que un dueño lo asigna). Dueño, agencia y negocio necesitan un código
-- del mismo rol sin usar; si no, la cuenta queda como cliente.
-- FOR UPDATE: dos registros simultáneos con el mismo código no lo consumen
-- ambos (el segundo vuelve a leer used_by ya lleno).
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  requested  text := coalesce(NEW.raw_user_meta_data->>'role', 'cliente');
  final_role text := 'cliente';
  invite     text := nullif(trim(coalesce(NEW.raw_user_meta_data->>'invite_code',
                                          NEW.raw_user_meta_data->>'owner_code', '')), '');
  code_role  text;
BEGIN
  IF requested IN ('cliente', 'conductor') THEN
    final_role := requested;
  ELSIF requested IN ('dueño', 'agencia', 'negocio') AND invite IS NOT NULL THEN
    SELECT role INTO code_role FROM public.owner_invite_codes
     WHERE code = invite AND used_by IS NULL
     FOR UPDATE;
    IF code_role = requested THEN final_role := requested; END IF;
  END IF;

  INSERT INTO public.users (id, full_name, email, role)
  VALUES (
    NEW.id,
    coalesce(NEW.raw_user_meta_data->>'full_name', split_part(coalesce(NEW.email, ''), '@', 1)),
    coalesce(NEW.email, NEW.id::text || '@sin-correo.local'),
    final_role
  )
  ON CONFLICT (id) DO NOTHING;

  IF final_role IN ('dueño', 'agencia', 'negocio') THEN
    UPDATE public.owner_invite_codes SET used_by = NEW.id, used_at = now()
     WHERE code = invite AND used_by IS NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- El formulario de registro avisa antes de crear la cuenta si el código no
-- sirve. Los códigos llevan 40 bits aleatorios: no se pueden adivinar.
CREATE OR REPLACE FUNCTION public.invite_code_valid(p_code text, p_role text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.owner_invite_codes
     WHERE code = trim(p_code) AND role = p_role AND used_by IS NULL
  );
$$;
REVOKE ALL ON FUNCTION public.invite_code_valid(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invite_code_valid(text, text) TO anon, authenticated;

-- Administración (SQL editor): SELECT public.create_invite_code('agencia');
CREATE OR REPLACE FUNCTION public.create_invite_code(p_role text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_code text;
BEGIN
  IF p_role NOT IN ('dueño', 'agencia', 'negocio') THEN RAISE EXCEPTION 'INVALID_ROLE'; END IF;
  v_code := CASE p_role WHEN 'dueño' THEN 'DUENO' WHEN 'agencia' THEN 'AGENCIA' ELSE 'NEGOCIO' END
            || '-' || upper(substr(md5(gen_random_uuid()::text), 1, 10));
  INSERT INTO public.owner_invite_codes (code, role) VALUES (v_code, p_role);
  RETURN v_code;
END;
$$;
REVOKE ALL ON FUNCTION public.create_invite_code(text) FROM PUBLIC, anon, authenticated;

-- ─────────────── 7. Embarque cerca de la hora de salida ───────────────
CREATE OR REPLACE FUNCTION public.board_sale(p_qr text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_sale_id  uuid;
  v_sale     record;
  v_allowed  boolean;
  v_boarded  int[];
  v_count    int;
  v_when     text;
BEGIN
  BEGIN
    v_sale_id := (p_qr::jsonb->>'sale_id')::uuid;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_QR', 'message', 'QR inválido.');
  END;
  SELECT s.id, s.status, s.assigned_chiva_id, s.owner_id, s.customer_name, s.seats, s.boarded_at,
         t.title AS tour_title, ac.chiva_id, ac.departure_at, ac.status AS departure_status
    INTO v_sale
    FROM public.sales_simple s
    JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
    LEFT JOIN public.tours t ON t.id = s.tour_id
   WHERE s.id = v_sale_id
   FOR UPDATE OF s;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'message', 'Ticket no encontrado.');
  END IF;
  v_allowed := v_sale.owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.drivers d WHERE d.chiva_id = v_sale.chiva_id AND d.user_id = auth.uid());
  IF NOT v_allowed THEN
    RETURN jsonb_build_object('ok', false, 'code', 'FORBIDDEN', 'message', 'Este ticket no pertenece a tus salidas.');
  END IF;
  IF v_sale.status <> 'pagado' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_PAID', 'message',
      CASE WHEN v_sale.status = 'pendiente' THEN 'El pago aún no fue verificado.' ELSE 'Esta venta fue cancelada.' END);
  END IF;

  -- Un QR de otra salida de la misma chiva (o de ayer) no sirve hoy.
  v_when := to_char(v_sale.departure_at AT TIME ZONE 'America/Guayaquil', 'DD/MM "a las" HH24:MI');
  IF v_sale.departure_status = 'finalizado' OR v_sale.departure_at < now() - interval '6 hours' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'DEPARTURE_PAST',
      'message', 'Este ticket era para la salida del ' || v_when || ', que ya terminó.',
      'customer', v_sale.customer_name, 'tour', v_sale.tour_title);
  END IF;
  IF v_sale.departure_at > now() + interval '3 hours' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'WRONG_DEPARTURE',
      'message', 'Este ticket es para la salida del ' || v_when || '.',
      'customer', v_sale.customer_name, 'tour', v_sale.tour_title);
  END IF;

  UPDATE public.seats SET status = 'abordado'
   WHERE sale_id = v_sale_id AND status = 'pagado';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  SELECT array_agg(seat_number ORDER BY seat_number) INTO v_boarded
    FROM public.seats WHERE sale_id = v_sale_id AND status = 'abordado';
  IF v_count = 0 THEN
    IF v_sale.boarded_at IS NOT NULL THEN
      RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_BOARDED', 'message', 'Este ticket ya fue usado.',
        'seats', to_jsonb(coalesce(v_boarded, '{}')), 'customer', v_sale.customer_name, 'tour', v_sale.tour_title);
    END IF;
    RETURN jsonb_build_object('ok', false, 'code', 'NO_SEATS', 'message', 'No hay asientos por abordar en este ticket.');
  END IF;
  UPDATE public.sales_simple SET boarded_at = coalesce(boarded_at, now()), updated_at = now() WHERE id = v_sale_id;
  RETURN jsonb_build_object('ok', true, 'seats', to_jsonb(v_boarded),
    'customer', v_sale.customer_name, 'tour', v_sale.tour_title);
END;
$$;

-- ─────────────── 8. Capacidad de la chiva y cambios de salida ───────────────
CREATE OR REPLACE FUNCTION public.sync_seats_on_capacity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.capacity = OLD.capacity THEN RETURN NEW; END IF;

  IF EXISTS (
    SELECT 1 FROM public.seats s
      JOIN public.assigned_chivas ac ON ac.id = s.assigned_chiva_id
     WHERE ac.chiva_id = NEW.id AND ac.status IN ('pendiente', 'en_curso')
       AND s.seat_number > NEW.capacity AND s.status <> 'disponible'
  ) THEN
    RAISE EXCEPTION 'No puedes bajar la capacidad a %: hay asientos vendidos o reservados por encima de ese número en salidas próximas.', NEW.capacity;
  END IF;

  DELETE FROM public.seats s
   USING public.assigned_chivas ac
   WHERE ac.id = s.assigned_chiva_id
     AND ac.chiva_id = NEW.id AND ac.status IN ('pendiente', 'en_curso')
     AND s.seat_number > NEW.capacity AND s.status = 'disponible';

  INSERT INTO public.seats (assigned_chiva_id, seat_number, status)
  SELECT ac.id, g, 'disponible'
    FROM public.assigned_chivas ac
   CROSS JOIN generate_series(1, NEW.capacity) g
   WHERE ac.chiva_id = NEW.id AND ac.status IN ('pendiente', 'en_curso')
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_seats_on_capacity ON public.chivas;
CREATE TRIGGER trg_sync_seats_on_capacity
  AFTER UPDATE OF capacity ON public.chivas
  FOR EACH ROW EXECUTE FUNCTION public.sync_seats_on_capacity();

-- Una salida con ventas vivas no cambia de tour, chiva ni hora: los
-- tickets ya emitidos dirían otra cosa y nadie avisa a los pasajeros.
-- Sin ventas, cambiar de chiva rehace los asientos con la nueva capacidad.
CREATE OR REPLACE FUNCTION public.guard_departure_changes()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_cap int;
BEGIN
  IF (NEW.tour_id, NEW.chiva_id, NEW.departure_at) IS NOT DISTINCT FROM (OLD.tour_id, OLD.chiva_id, OLD.departure_at) THEN
    RETURN NEW;
  END IF;
  IF EXISTS (SELECT 1 FROM public.sales_simple WHERE assigned_chiva_id = OLD.id AND status IN ('pendiente', 'pagado')) THEN
    RAISE EXCEPTION 'Esta salida ya tiene ventas: no se puede cambiar el tour, la chiva ni la hora. Crea una salida nueva.';
  END IF;
  IF NEW.chiva_id IS DISTINCT FROM OLD.chiva_id THEN
    SELECT capacity INTO v_cap FROM public.chivas WHERE id = NEW.chiva_id;
    DELETE FROM public.seats WHERE assigned_chiva_id = NEW.id;
    INSERT INTO public.seats (assigned_chiva_id, seat_number, status)
    SELECT NEW.id, g, 'disponible' FROM generate_series(1, coalesce(v_cap, 40)) g;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_departure_changes ON public.assigned_chivas;
CREATE TRIGGER trg_guard_departure_changes
  BEFORE UPDATE OF tour_id, chiva_id, departure_at ON public.assigned_chivas
  FOR EACH ROW EXECUTE FUNCTION public.guard_departure_changes();

REVOKE ALL ON FUNCTION public.sync_seats_on_capacity()  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_departure_changes() FROM PUBLIC, anon, authenticated;

-- ─────────────── 9. Precios de eventos y comprobantes únicos ───────────────
DO $$ BEGIN
  ALTER TABLE public.business_events
    ADD CONSTRAINT business_events_price_range CHECK (price >= 0.50 AND price <= 1000 AND price = round(price, 2));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE public.tours
    ADD CONSTRAINT tours_base_price_cents CHECK (base_price = round(base_price, 2));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE UNIQUE INDEX IF NOT EXISTS business_tickets_proof_path_key
  ON public.business_tickets (payment_proof_path) WHERE payment_proof_path IS NOT NULL;

-- ─────────────── 10. Bucket de comprobantes sin subida anónima ───────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'storage')
     AND to_regclass('storage.objects') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "comprobantes: upload" ON storage.objects';
  END IF;
END $$;

-- Avisos del linter de Supabase
ALTER FUNCTION public.plan_month_start() SET search_path = public;
ALTER FUNCTION public.current_period()   SET search_path = public;
