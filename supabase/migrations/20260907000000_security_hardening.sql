-- ================================================================
-- ChivaPass — Endurecimiento de seguridad y flujo de ventas
--
-- Qué hace esta migración:
--   1. Cierra las políticas RLS abiertas (asientos, ventas, comprobantes,
--      tickets) que permitían escribir con la anon key sin pasar por las
--      edge functions.
--   2. Protege role/plan en users y valida el rol al registrarse.
--   3. Vuelve privado el bucket de comprobantes y quita las lecturas
--      públicas de panel_settings y business_tickets.
--   4. Añade columnas de cliente, método de pago y QR a sales_simple,
--      y sale_id a seats para vincular asiento ↔ venta.
--   5. Crea las funciones SQL atómicas que usan las edge functions y el
--      panel: reserva de asientos, confirmación/cancelación, tickets de
--      eventos con control de cupo, embarque y validación de entradas.
--
-- Es idempotente: se puede volver a ejecutar sin romper nada.
-- ================================================================


-- ================================================================
-- 1. POLÍTICAS ABIERTAS → fuera
-- ================================================================
DROP POLICY IF EXISTS "seats: update abierto"        ON public.seats;
DROP POLICY IF EXISTS "sales: insert abierto"        ON public.sales_simple;
DROP POLICY IF EXISTS "pending: insert abierto"      ON public.pending_payments;
DROP POLICY IF EXISTS "btickets: insert abierto"     ON public.business_tickets;
DROP POLICY IF EXISTS "btickets: public view verified" ON public.business_tickets;
DROP POLICY IF EXISTS "subs: service manages"        ON public.subscriptions;
DROP POLICY IF EXISTS "settings: public read"        ON public.panel_settings;
DROP POLICY IF EXISTS "drivers: autenticados"        ON public.drivers;

-- Políticas que existen en el proyecto real pero no en las migraciones del
-- repo (se crearon a mano). Todas permiten escribir sin pasar por las
-- edge functions, así que también se retiran.
DROP POLICY IF EXISTS "seats: update autenticados"    ON public.seats;
DROP POLICY IF EXISTS "sales: insert propio"          ON public.sales_simple;
DROP POLICY IF EXISTS "sales: update owner o agencia" ON public.sales_simple;
DROP POLICY IF EXISTS "pending: insert propio"        ON public.pending_payments;
DROP POLICY IF EXISTS "btickets: insert owner"        ON public.business_tickets;

-- El titular no puede reasignar owner_id al actualizar un comprobante
DROP POLICY IF EXISTS "pending: update owner" ON public.pending_payments;
CREATE POLICY "pending: update owner" ON public.pending_payments FOR UPDATE
  USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

-- users: el propio usuario solo puede tocar su fila (role/plan se protegen abajo)
DROP POLICY IF EXISTS "users: update propio" ON public.users;
CREATE POLICY "users: update propio" ON public.users FOR UPDATE
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- Los balances los escribe solo el servidor
DROP POLICY IF EXISTS "owner_balance: insert"  ON public.owner_balance;
DROP POLICY IF EXISTS "agency_balance: insert" ON public.agency_balance;

REVOKE SELECT ON public.panel_settings FROM anon;


-- ================================================================
-- 2. PROTECCIÓN DE ROLE / PLAN
-- ================================================================
-- Devuelve true cuando la llamada viene de un cliente de la API
-- (anon o authenticated). service_role, el dashboard y los triggers
-- internos no cuentan como cliente.
CREATE OR REPLACE FUNCTION public.is_api_client()
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT coalesce(auth.role(), '') IN ('anon', 'authenticated');
$$;

CREATE OR REPLACE FUNCTION public.protect_user_privileges()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.is_api_client() THEN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
      RAISE EXCEPTION 'No puedes cambiar tu rol.' USING ERRCODE = '42501';
    END IF;
    IF NEW.plan IS DISTINCT FROM OLD.plan THEN
      RAISE EXCEPTION 'El plan solo se cambia desde administración.' USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_privileges ON public.users;
CREATE TRIGGER trg_protect_user_privileges
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.protect_user_privileges();

-- Códigos de invitación para registrarse como dueño.
-- Insertar uno con:  INSERT INTO public.owner_invite_codes (code) VALUES ('...');
CREATE TABLE IF NOT EXISTS public.owner_invite_codes (
  code        text        PRIMARY KEY,
  used_by     uuid        REFERENCES public.users(id) ON DELETE SET NULL,
  used_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.owner_invite_codes ENABLE ROW LEVEL SECURITY;
-- Sin políticas: solo service_role / funciones SECURITY DEFINER la leen.

-- Registro: el rol viene del metadata pero se valida.
--   agencia | negocio | conductor | cliente → libres
--   dueño → requiere owner_code válido y sin usar; si no, cae a 'agencia'
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  requested text := coalesce(NEW.raw_user_meta_data->>'role', 'agencia');
  final_role text := 'agencia';
  invite text := NEW.raw_user_meta_data->>'owner_code';
BEGIN
  IF requested IN ('agencia', 'negocio', 'conductor', 'cliente') THEN
    final_role := requested;
  ELSIF requested = 'dueño' THEN
    IF invite IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.owner_invite_codes WHERE code = invite AND used_by IS NULL
    ) THEN
      final_role := 'dueño';
      UPDATE public.owner_invite_codes SET used_by = NEW.id, used_at = now() WHERE code = invite;
    END IF;
  END IF;

  INSERT INTO public.users (id, full_name, email, role)
  VALUES (
    NEW.id,
    coalesce(NEW.raw_user_meta_data->>'full_name', split_part(coalesce(NEW.email, ''), '@', 1)),
    coalesce(NEW.email, NEW.id::text || '@sin-correo.local'),
    final_role
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Mantener el trigger existente apuntando a la nueva versión
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ================================================================
-- 3. ESQUEMA: columnas nuevas y checks
-- ================================================================
-- Datos del comprador, método de pago y QR en la venta
ALTER TABLE public.sales_simple
  ADD COLUMN IF NOT EXISTS customer_name    text,
  ADD COLUMN IF NOT EXISTS customer_cedula  text,
  ADD COLUMN IF NOT EXISTS customer_phone   text,
  ADD COLUMN IF NOT EXISTS customer_email   text,
  ADD COLUMN IF NOT EXISTS customer_address text,
  ADD COLUMN IF NOT EXISTS payment_method   text NOT NULL DEFAULT 'transferencia',
  ADD COLUMN IF NOT EXISTS payment_ref      text,
  ADD COLUMN IF NOT EXISTS qr_payload       text,
  ADD COLUMN IF NOT EXISTS boarded_at       timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at       timestamptz NOT NULL DEFAULT now();

-- NOT VALID: aplica a filas nuevas sin fallar si hay ventas antiguas con otro estado
ALTER TABLE public.sales_simple DROP CONSTRAINT IF EXISTS sales_simple_status_check;
ALTER TABLE public.sales_simple ADD CONSTRAINT sales_simple_status_check
  CHECK (status IN ('pendiente', 'pagado', 'cancelado')) NOT VALID;

ALTER TABLE public.sales_simple DROP CONSTRAINT IF EXISTS sales_simple_payment_method_check;
ALTER TABLE public.sales_simple ADD CONSTRAINT sales_simple_payment_method_check
  CHECK (payment_method IN ('transferencia', 'tarjeta', 'efectivo'));

CREATE UNIQUE INDEX IF NOT EXISTS uq_sales_qr_payload ON public.sales_simple(qr_payload) WHERE qr_payload IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_sales_assigned ON public.sales_simple(assigned_chiva_id);
CREATE INDEX IF NOT EXISTS idx_sales_customer_email ON public.sales_simple(lower(customer_email));

-- Vínculo asiento ↔ venta
ALTER TABLE public.seats ADD COLUMN IF NOT EXISTS sale_id uuid REFERENCES public.sales_simple(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_seats_sale ON public.seats(sale_id);

-- payment_sessions: aceptar 'tour' y 'plan', idempotencia por token, estado de revisión
ALTER TABLE public.payment_sessions DROP CONSTRAINT IF EXISTS payment_sessions_ticket_type_check;
ALTER TABLE public.payment_sessions ADD CONSTRAINT payment_sessions_ticket_type_check
  CHECK (ticket_type IN ('chiva', 'tour', 'business', 'plan'));

ALTER TABLE public.payment_sessions DROP CONSTRAINT IF EXISTS payment_sessions_status_check;
ALTER TABLE public.payment_sessions ADD CONSTRAINT payment_sessions_status_check
  CHECK (status IN ('pending', 'approved', 'declined', 'error', 'needs_review'));

ALTER TABLE public.payment_sessions ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_sessions_token ON public.payment_sessions(provider_token) WHERE provider_token IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_sessions_charge ON public.payment_sessions(provider_charge_id) WHERE provider_charge_id IS NOT NULL;

-- Comprobantes: quién y cuándo verificó
ALTER TABLE public.pending_payments
  ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS verified_at timestamptz;

-- drivers: el código actual usa estas columnas; se alinean si faltan
ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS user_id  uuid REFERENCES public.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS owner_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS chiva_id uuid REFERENCES public.chivas(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS email    text;
CREATE INDEX IF NOT EXISTS idx_drivers_owner ON public.drivers(owner_id);
CREATE INDEX IF NOT EXISTS idx_drivers_user  ON public.drivers(user_id);
CREATE INDEX IF NOT EXISTS idx_drivers_chiva ON public.drivers(chiva_id);

DROP POLICY IF EXISTS "drivers: dueño gestiona"        ON public.drivers;
DROP POLICY IF EXISTS "drivers: conductor lee lo suyo" ON public.drivers;
CREATE POLICY "drivers: dueño gestiona" ON public.drivers FOR ALL
  USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "drivers: conductor lee lo suyo" ON public.drivers FOR SELECT
  USING (auth.uid() = user_id);

-- Rol del usuario actual sin pasar por RLS (evita recursión en políticas de users)
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$;
GRANT EXECUTE ON FUNCTION public.my_role() TO anon, authenticated;

-- El dueño busca conductores por nombre para asignarlos
DROP POLICY IF EXISTS "users: dueño ve conductores" ON public.users;
CREATE POLICY "users: dueño ve conductores" ON public.users FOR SELECT
  USING (role = 'conductor' AND public.my_role() = 'dueño');

-- conductorTours usa finished_at
ALTER TABLE public.assigned_chivas ADD COLUMN IF NOT EXISTS finished_at timestamptz;

-- Índices de FKs que faltaban
CREATE INDEX IF NOT EXISTS idx_assigned_tour  ON public.assigned_chivas(tour_id);
CREATE INDEX IF NOT EXISTS idx_assigned_chiva ON public.assigned_chivas(chiva_id);
CREATE INDEX IF NOT EXISTS idx_sales_tour     ON public.sales_simple(tour_id);
CREATE INDEX IF NOT EXISTS idx_btickets_qr    ON public.business_tickets(qr_payload);

-- El trigger de asientos fija search_path
CREATE OR REPLACE FUNCTION public.create_seats_for_assigned_chiva()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  cap int;
BEGIN
  SELECT capacity INTO cap FROM public.chivas WHERE id = NEW.chiva_id;
  FOR i IN 1..coalesce(cap, 40) LOOP
    INSERT INTO public.seats (assigned_chiva_id, seat_number, status)
    VALUES (NEW.id, i, 'disponible')
    ON CONFLICT DO NOTHING;
  END LOOP;
  RETURN NEW;
END;
$$;

-- El conductor asignado a la chiva puede cambiar el estado de la salida
DROP POLICY IF EXISTS "assigned: conductor actualiza" ON public.assigned_chivas;
CREATE POLICY "assigned: conductor actualiza" ON public.assigned_chivas FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.drivers d WHERE d.chiva_id = assigned_chivas.chiva_id AND d.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.drivers d WHERE d.chiva_id = assigned_chivas.chiva_id AND d.user_id = auth.uid()));

-- El cliente logueado ve sus compras de tours por correo (como en business_tickets)
DROP POLICY IF EXISTS "sales: customer email view" ON public.sales_simple;
CREATE POLICY "sales: customer email view" ON public.sales_simple FOR SELECT
  USING (auth.email() IS NOT NULL AND lower(customer_email) = lower(auth.email()));


-- ================================================================
-- 4. STORAGE: bucket privado
--    (guardado en un DO: el Postgres local del CI no tiene storage-api)
-- ================================================================
DO $storage$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='storage' AND table_name='buckets' AND column_name='public') THEN
    UPDATE storage.buckets SET public = false WHERE id = 'comprobantes';

    EXECUTE 'DROP POLICY IF EXISTS "comprobantes: lectura pública"      ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "comprobantes: lectura autenticados" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "comprobantes: upload abierto"       ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "comprobantes: upload"               ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "comprobantes: lee el vendedor"      ON storage.objects';

    -- Subida: cualquiera (invitados incluidos), solo dentro de la carpeta comprobantes/
    EXECUTE $p$CREATE POLICY "comprobantes: upload"
      ON storage.objects FOR INSERT
      WITH CHECK (bucket_id = 'comprobantes' AND (storage.foldername(name))[1] = 'comprobantes')$p$;

    -- Lectura: solo el dueño/negocio al que pertenece el comprobante (URLs firmadas)
    EXECUTE $p$CREATE POLICY "comprobantes: lee el vendedor"
      ON storage.objects FOR SELECT
      USING (
        bucket_id = 'comprobantes' AND (
          EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.comprobante_path = storage.objects.name AND p.owner_id = auth.uid())
          OR EXISTS (SELECT 1 FROM public.business_tickets t WHERE t.payment_proof_path = storage.objects.name AND t.owner_id = auth.uid())
        )
      )$p$;
  END IF;
END;
$storage$;


-- ================================================================
-- 5. FUNCIONES ATÓMICAS
--    Las que reciben datos de compra las llama SOLO el service_role
--    (edge functions). Las de panel/escáner las llama el usuario
--    autenticado y validan pertenencia dentro.
-- ================================================================

-- Ventas antiguas guardaron seats como texto JSON dentro del jsonb; esta
-- función cuenta asientos en ambos formatos.
CREATE OR REPLACE FUNCTION public.sale_seat_count(p_seats jsonb)
RETURNS int LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_seats IS NULL THEN 0
    WHEN jsonb_typeof(p_seats) = 'array' THEN jsonb_array_length(p_seats)
    WHEN jsonb_typeof(p_seats) = 'string' THEN coalesce(jsonb_array_length((p_seats #>> '{}')::jsonb), 0)
    ELSE 0 END;
$$;

-- ---- 5.1 Reservar asientos + crear venta (todo o nada) ----
CREATE OR REPLACE FUNCTION public.reserve_tour_seats(
  p_assigned_chiva_id uuid,
  p_seats             int[],
  p_customer          jsonb,
  p_agency_id         uuid DEFAULT NULL,
  p_status            text DEFAULT 'pendiente',   -- 'pendiente' | 'pagado'
  p_payment_method    text DEFAULT 'transferencia',
  p_payment_ref       text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ac       record;
  v_price    numeric;
  v_amount   numeric;
  v_sale_id  uuid;
  v_locked   int;
  v_seat_status text;
BEGIN
  IF p_seats IS NULL OR array_length(p_seats, 1) IS NULL THEN
    RAISE EXCEPTION 'SEATS_REQUIRED';
  END IF;
  IF p_status NOT IN ('pendiente', 'pagado') THEN
    RAISE EXCEPTION 'INVALID_STATUS';
  END IF;

  -- Bloquea la salida: serializa reservas concurrentes sobre la misma chiva
  SELECT ac.id, ac.owner_id, ac.tour_id, ac.departure_at, ac.status,
         t.title AS tour_title, t.base_price, c.name AS chiva_name
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
    -- Revierte todo (insert de venta incluido)
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

-- ---- 5.2 Confirmar / cancelar venta ----
CREATE OR REPLACE FUNCTION public.confirm_sale(p_sale_id uuid, p_payment_ref text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.sales_simple
     SET status = 'pagado',
         payment_ref = coalesce(p_payment_ref, payment_ref),
         updated_at = now()
   WHERE id = p_sale_id AND status <> 'cancelado';
  IF NOT FOUND THEN RAISE EXCEPTION 'SALE_NOT_FOUND'; END IF;

  UPDATE public.seats SET status = 'pagado'
   WHERE sale_id = p_sale_id AND status = 'reservado';
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_sale(p_sale_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.sales_simple SET status = 'cancelado', updated_at = now()
   WHERE id = p_sale_id;
  UPDATE public.seats SET status = 'disponible', sale_id = NULL
   WHERE sale_id = p_sale_id AND status IN ('reservado', 'pagado');
END;
$$;

-- ---- 5.3 Ticket de evento con control de cupo ----
CREATE OR REPLACE FUNCTION public.create_business_ticket(
  p_event_id     uuid,
  p_quantity     int,
  p_customer     jsonb,
  p_status       text DEFAULT 'pendiente',   -- 'pendiente' | 'verificado'
  p_proof_number text DEFAULT NULL,
  p_proof_path   text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ev      record;
  v_sold    int;
  v_amount  numeric;
  v_id      uuid;
  v_qr      text;
BEGIN
  IF p_quantity IS NULL OR p_quantity < 1 THEN RAISE EXCEPTION 'QUANTITY_REQUIRED'; END IF;
  IF p_status NOT IN ('pendiente', 'verificado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;

  SELECT e.id, e.title, e.price, e.capacity, e.status, e.event_date, e.business_id,
         b.name AS business_name, b.owner_id
    INTO v_ev
    FROM public.business_events e
    JOIN public.businesses b ON b.id = e.business_id
   WHERE e.id = p_event_id
   FOR UPDATE OF e;

  IF NOT FOUND THEN RAISE EXCEPTION 'EVENT_NOT_FOUND'; END IF;
  IF v_ev.status <> 'activo' THEN RAISE EXCEPTION 'EVENT_INACTIVE'; END IF;
  IF v_ev.event_date < now() THEN RAISE EXCEPTION 'EVENT_PAST'; END IF;

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

CREATE OR REPLACE FUNCTION public.set_business_ticket_status(p_ticket_id uuid, p_status text, p_payment_ref text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_event uuid;
BEGIN
  IF p_status NOT IN ('pendiente', 'verificado', 'rechazado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;
  UPDATE public.business_tickets
     SET payment_status = p_status,
         payment_number = coalesce(p_payment_ref, payment_number)
   WHERE id = p_ticket_id
   RETURNING event_id INTO v_event;
  IF NOT FOUND THEN RAISE EXCEPTION 'TICKET_NOT_FOUND'; END IF;

  -- Si se libera cupo, reabrir el evento
  IF p_status = 'rechazado' THEN
    UPDATE public.business_events SET status = 'activo'
     WHERE id = v_event AND status = 'agotado' AND event_date >= now();
  END IF;
END;
$$;

-- ---- 5.4 Verificación de comprobantes desde el panel del dueño ----
CREATE OR REPLACE FUNCTION public.verify_pending_payment(p_payment_id uuid, p_estado text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_pay record;
BEGIN
  IF p_estado NOT IN ('verificado', 'rechazado') THEN RAISE EXCEPTION 'INVALID_STATUS'; END IF;

  SELECT * INTO v_pay FROM public.pending_payments WHERE id = p_payment_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PAYMENT_NOT_FOUND'; END IF;
  IF v_pay.owner_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501';
  END IF;
  IF v_pay.estado <> 'pendiente' THEN RAISE EXCEPTION 'ALREADY_PROCESSED'; END IF;

  UPDATE public.pending_payments
     SET estado = p_estado, verified_by = auth.uid(), verified_at = now()
   WHERE id = p_payment_id;

  IF v_pay.sale_id IS NOT NULL THEN
    IF p_estado = 'verificado' THEN
      PERFORM public.confirm_sale(v_pay.sale_id, v_pay.numero_comprobante);
      INSERT INTO public.owner_balance (owner_id, assigned_chiva_id, comprobante_id, boletos_vendidos, monto_total)
      SELECT s.owner_id, s.assigned_chiva_id, v_pay.id, public.sale_seat_count(s.seats), s.owner_gain
        FROM public.sales_simple s WHERE s.id = v_pay.sale_id;
      IF v_pay.agency_id IS NOT NULL THEN
        INSERT INTO public.agency_balance (agency_id, assigned_chiva_id, comprobante_id, boletos_vendidos, monto_total)
        SELECT v_pay.agency_id, s.assigned_chiva_id, v_pay.id, public.sale_seat_count(s.seats), s.agency_gain
          FROM public.sales_simple s WHERE s.id = v_pay.sale_id;
      END IF;
    ELSE
      PERFORM public.cancel_sale(v_pay.sale_id);
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'estado', p_estado, 'sale_id', v_pay.sale_id);
END;
$$;

-- El negocio aprueba/rechaza tickets de eventos (misma lógica de cupo)
CREATE OR REPLACE FUNCTION public.review_business_ticket(p_ticket_id uuid, p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_owner uuid;
BEGIN
  SELECT owner_id INTO v_owner FROM public.business_tickets WHERE id = p_ticket_id;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'TICKET_NOT_FOUND'; END IF;
  IF v_owner IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'FORBIDDEN' USING ERRCODE = '42501'; END IF;
  PERFORM public.set_business_ticket_status(p_ticket_id, p_status);
  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$$;

-- ---- 5.5 Embarque de un QR de tour (dueño de la salida o conductor de la chiva) ----
CREATE OR REPLACE FUNCTION public.board_sale(p_qr text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_sale_id  uuid;
  v_sale     record;
  v_allowed  boolean;
  v_boarded  int[];
  v_count    int;
BEGIN
  BEGIN
    v_sale_id := (p_qr::jsonb->>'sale_id')::uuid;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'code', 'INVALID_QR', 'message', 'QR inválido.');
  END;

  SELECT s.id, s.status, s.assigned_chiva_id, s.owner_id, s.customer_name, s.seats, s.boarded_at,
         t.title AS tour_title, ac.chiva_id
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

-- ---- 5.6 Uso de entrada de evento (atómico: un solo escaneo gana) ----
CREATE OR REPLACE FUNCTION public.use_business_ticket(p_qr text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_tk record;
BEGIN
  UPDATE public.business_tickets
     SET used = true
   WHERE qr_payload = p_qr
     AND owner_id = auth.uid()
     AND payment_status = 'verificado'
     AND used = false
   RETURNING id, customer_name, quantity, event_id INTO v_tk;

  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'ticket_id', v_tk.id, 'customer', v_tk.customer_name,
      'quantity', v_tk.quantity,
      'event', (SELECT title FROM public.business_events WHERE id = v_tk.event_id));
  END IF;

  -- Diagnóstico de por qué no entró
  SELECT id, customer_name, quantity, payment_status, used, owner_id, event_id
    INTO v_tk FROM public.business_tickets WHERE qr_payload = p_qr;

  IF NOT FOUND OR v_tk.owner_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_FOUND', 'message', 'Ticket no encontrado o no pertenece a tu negocio.');
  END IF;
  IF v_tk.payment_status <> 'verificado' THEN
    RETURN jsonb_build_object('ok', false, 'code', 'NOT_PAID', 'message', 'El pago no ha sido verificado.',
      'customer', v_tk.customer_name, 'quantity', v_tk.quantity);
  END IF;
  RETURN jsonb_build_object('ok', false, 'code', 'ALREADY_USED', 'message', 'Esta entrada ya fue usada.',
    'customer', v_tk.customer_name, 'quantity', v_tk.quantity);
END;
$$;

-- ---- 5.7 Ticket público por id (solo campos del ticket, sin cédula ni teléfono) ----
CREATE OR REPLACE FUNCTION public.get_public_ticket(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public AS $$
DECLARE v jsonb;
BEGIN
  SELECT jsonb_build_object(
    'kind', 'business', 'id', t.id, 'customer_name', t.customer_name,
    'quantity', t.quantity, 'total', t.total_price, 'qr_payload', t.qr_payload, 'used', t.used,
    'title', e.title, 'date', e.event_date, 'place', b.name
  ) INTO v
  FROM public.business_tickets t
  JOIN public.business_events e ON e.id = t.event_id
  JOIN public.businesses b ON b.id = t.business_id
  WHERE t.id = p_id AND t.payment_status = 'verificado';
  IF v IS NOT NULL THEN RETURN v; END IF;

  SELECT jsonb_build_object(
    'kind', 'tour', 'id', s.id, 'customer_name', s.customer_name,
    'quantity', public.sale_seat_count(s.seats), 'seats', s.seats, 'total', s.total_sale,
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

-- ---- 5.8 Datos bancarios de UN vendedor para el checkout ----
CREATE OR REPLACE FUNCTION public.get_seller_payment_info(p_owner_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT jsonb_build_object(
    'bank_name', bank_name, 'bank_account', bank_account, 'bank_owner', bank_owner,
    'bank_type', bank_type, 'notes', notes, 'business_name', business_name
  )
  FROM public.panel_settings WHERE user_id = p_owner_id;
$$;

-- ---- Permisos de ejecución ----
REVOKE ALL ON FUNCTION public.reserve_tour_seats(uuid, int[], jsonb, uuid, text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.confirm_sale(uuid, text)                                        FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.cancel_sale(uuid)                                               FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_business_ticket(uuid, int, jsonb, text, text, text)     FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.set_business_ticket_status(uuid, text, text)                    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.protect_user_privileges()                                       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user()                                               FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.reserve_tour_seats(uuid, int[], jsonb, uuid, text, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.confirm_sale(uuid, text)                                        TO service_role;
GRANT EXECUTE ON FUNCTION public.cancel_sale(uuid)                                               TO service_role;
GRANT EXECUTE ON FUNCTION public.create_business_ticket(uuid, int, jsonb, text, text, text)     TO service_role;
GRANT EXECUTE ON FUNCTION public.set_business_ticket_status(uuid, text, text)                    TO service_role;

GRANT EXECUTE ON FUNCTION public.verify_pending_payment(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_business_ticket(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.board_sale(text)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.use_business_ticket(text)          TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_ticket(uuid)            TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_seller_payment_info(uuid)      TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_api_client()                    TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sale_seat_count(jsonb)             TO anon, authenticated, service_role;
