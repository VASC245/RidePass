-- ================================================================
-- ChivasPass — Esquema completo de base de datos
-- Ejecutar en: Supabase SQL Editor
-- ================================================================

-- ================================================================
-- 1. USERS — Perfiles de usuario (vinculado a auth.users)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.users (
  id          uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   text        NOT NULL,
  email       text        UNIQUE NOT NULL,
  role        text        NOT NULL DEFAULT 'agencia'
                          CHECK (role IN ('dueño', 'agencia', 'conductor')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ================================================================
-- 2. CHIVAS — Vehículos registrados por cada dueño
-- ================================================================
CREATE TABLE IF NOT EXISTS public.chivas (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text        NOT NULL,
  plate       text        NOT NULL,
  code        text        NOT NULL,
  capacity    int         NOT NULL DEFAULT 40 CHECK (capacity > 0 AND capacity <= 100),
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chivas_user ON public.chivas(user_id);

-- ================================================================
-- 3. DRIVERS — Conductores
-- ================================================================
CREATE TABLE IF NOT EXISTS public.drivers (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name   text        NOT NULL,
  phone       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ================================================================
-- 4. TOURS — Plantillas de tour (creadas por el dueño)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.tours (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text        NOT NULL,
  description text        NOT NULL DEFAULT '',
  base_price  numeric     NOT NULL DEFAULT 2 CHECK (base_price >= 0),
  duration    int         NOT NULL DEFAULT 60 CHECK (duration > 0),
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tours_user ON public.tours(user_id);

-- ================================================================
-- 5. ASSIGNED_CHIVAS — Salidas programadas (tour + chiva + hora)
--    NOTA: se usa owner_id como nombre canónico (antes user_id)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.assigned_chivas (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tour_id      uuid        NOT NULL REFERENCES public.tours(id) ON DELETE CASCADE,
  chiva_id     uuid        NOT NULL REFERENCES public.chivas(id) ON DELETE CASCADE,
  departure_at timestamptz NOT NULL,
  status       text        NOT NULL DEFAULT 'pendiente'
                           CHECK (status IN ('pendiente', 'en_curso', 'finalizado')),
  owner_id     uuid        NOT NULL REFERENCES public.users(id),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_assigned_owner     ON public.assigned_chivas(owner_id);
CREATE INDEX IF NOT EXISTS idx_assigned_departure ON public.assigned_chivas(departure_at);
CREATE INDEX IF NOT EXISTS idx_assigned_status    ON public.assigned_chivas(status);

-- ================================================================
-- 6. SEATS — Asientos por salida (generados automáticamente)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.seats (
  id                uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  assigned_chiva_id uuid  NOT NULL REFERENCES public.assigned_chivas(id) ON DELETE CASCADE,
  seat_number       int   NOT NULL,
  status            text  NOT NULL DEFAULT 'disponible'
                          CHECK (status IN ('disponible', 'pagado', 'abordado', 'reservado')),
  UNIQUE (assigned_chiva_id, seat_number)
);

CREATE INDEX IF NOT EXISTS idx_seats_assigned ON public.seats(assigned_chiva_id);

-- ================================================================
-- TRIGGER — Auto-generar asientos al crear una salida
-- ================================================================
CREATE OR REPLACE FUNCTION public.create_seats_for_assigned_chiva()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  cap int;
BEGIN
  SELECT capacity INTO cap FROM public.chivas WHERE id = NEW.chiva_id;
  FOR i IN 1..COALESCE(cap, 40) LOOP
    INSERT INTO public.seats (assigned_chiva_id, seat_number, status)
    VALUES (NEW.id, i, 'disponible')
    ON CONFLICT DO NOTHING;
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_create_seats ON public.assigned_chivas;
CREATE TRIGGER trigger_create_seats
  AFTER INSERT ON public.assigned_chivas
  FOR EACH ROW EXECUTE FUNCTION public.create_seats_for_assigned_chiva();

-- ================================================================
-- 7. SALES_SIMPLE — Registro de ventas
--    agency_id es NULL cuando la venta viene de la página pública
-- ================================================================
CREATE TABLE IF NOT EXISTS public.sales_simple (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  assigned_chiva_id uuid        NOT NULL REFERENCES public.assigned_chivas(id),
  tour_id           uuid        REFERENCES public.tours(id),
  owner_id          uuid        REFERENCES public.users(id),
  agency_id         uuid        REFERENCES public.users(id),  -- NULL = venta pública directa
  seats             jsonb       NOT NULL DEFAULT '[]',
  sale_price        numeric     NOT NULL DEFAULT 0,
  total_sale        numeric     NOT NULL DEFAULT 0,
  owner_gain        numeric     NOT NULL DEFAULT 0,
  agency_gain       numeric     NOT NULL DEFAULT 0,
  status            text        NOT NULL DEFAULT 'pagado',
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales_owner   ON public.sales_simple(owner_id);
CREATE INDEX IF NOT EXISTS idx_sales_agency  ON public.sales_simple(agency_id);
CREATE INDEX IF NOT EXISTS idx_sales_created ON public.sales_simple(created_at);
CREATE INDEX IF NOT EXISTS idx_sales_status  ON public.sales_simple(status);

-- ================================================================
-- 8. PENDING_PAYMENTS — Comprobantes de pago subidos por agencias/público
-- ================================================================
CREATE TABLE IF NOT EXISTS public.pending_payments (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  assigned_chiva_id uuid        NOT NULL REFERENCES public.assigned_chivas(id),
  owner_id          uuid        REFERENCES public.users(id),
  agency_id         uuid        REFERENCES public.users(id),
  numero_comprobante text       NOT NULL,
  comprobante_path  text        NOT NULL,
  comprobante_url   text        NOT NULL,
  estado            text        NOT NULL DEFAULT 'pendiente'
                                CHECK (estado IN ('pendiente', 'verificado', 'rechazado')),
  agency_name       text,
  boletos_vendidos  int,
  monto_agencia     numeric,
  monto_owner       numeric,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pending_owner    ON public.pending_payments(owner_id);
CREATE INDEX IF NOT EXISTS idx_pending_assigned ON public.pending_payments(assigned_chiva_id);
CREATE INDEX IF NOT EXISTS idx_pending_estado   ON public.pending_payments(estado);

-- ================================================================
-- 9. OWNER_BALANCE — Registro de ingresos del dueño (al verificar comprobante)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.owner_balance (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id          uuid        NOT NULL REFERENCES public.users(id),
  assigned_chiva_id uuid        REFERENCES public.assigned_chivas(id),
  comprobante_id    uuid        REFERENCES public.pending_payments(id),
  boletos_vendidos  int         NOT NULL DEFAULT 0,
  monto_total       numeric     NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_owner_balance_owner ON public.owner_balance(owner_id);

-- ================================================================
-- 10. AGENCY_BALANCE — Registro de comisiones de agencias
-- ================================================================
CREATE TABLE IF NOT EXISTS public.agency_balance (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_id         uuid        NOT NULL REFERENCES public.users(id),
  assigned_chiva_id uuid        REFERENCES public.assigned_chivas(id),
  comprobante_id    uuid        REFERENCES public.pending_payments(id),
  boletos_vendidos  int         NOT NULL DEFAULT 0,
  monto_total       numeric     NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agency_balance_agency ON public.agency_balance(agency_id);

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================
ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chivas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drivers          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tours            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assigned_chivas  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seats            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_simple     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pending_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.owner_balance    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agency_balance   ENABLE ROW LEVEL SECURITY;

-- ---- USERS ----
CREATE POLICY "users: select propio"   ON public.users FOR SELECT  USING (auth.uid() = id);
CREATE POLICY "users: insert registro" ON public.users FOR INSERT  WITH CHECK (auth.uid() = id);
CREATE POLICY "users: update propio"   ON public.users FOR UPDATE  USING (auth.uid() = id);

-- ---- CHIVAS ----
-- El dueño gestiona las suyas; SELECT público para la página de reservas
CREATE POLICY "chivas: dueño gestiona" ON public.chivas FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "chivas: lectura pública" ON public.chivas FOR SELECT USING (true);

-- ---- DRIVERS ----
CREATE POLICY "drivers: autenticados" ON public.drivers FOR ALL    USING (auth.uid() IS NOT NULL);

-- ---- TOURS ----
CREATE POLICY "tours: dueño gestiona"  ON public.tours FOR ALL    USING (auth.uid() = user_id);
CREATE POLICY "tours: lectura pública" ON public.tours FOR SELECT  USING (true);

-- ---- ASSIGNED_CHIVAS ----
CREATE POLICY "assigned: dueño gestiona"   ON public.assigned_chivas FOR ALL    USING (auth.uid() = owner_id);
CREATE POLICY "assigned: lectura pública"  ON public.assigned_chivas FOR SELECT USING (true);

-- ---- SEATS ----
-- SELECT público (para ver disponibilidad sin login)
CREATE POLICY "seats: lectura pública" ON public.seats FOR SELECT USING (true);
-- UPDATE abierto (agencias y página pública marcan asientos como pagados)
CREATE POLICY "seats: update abierto"  ON public.seats FOR UPDATE USING (true);

-- ---- SALES_SIMPLE ----
-- INSERT abierto (agencias + anónimos de la página pública)
CREATE POLICY "sales: insert abierto"    ON public.sales_simple FOR INSERT WITH CHECK (true);
-- SELECT: el dueño ve las de sus tours, la agencia ve las suyas
CREATE POLICY "sales: select owner"      ON public.sales_simple FOR SELECT
  USING (auth.uid() = owner_id OR auth.uid() = agency_id);

-- ---- PENDING_PAYMENTS ----
CREATE POLICY "pending: insert abierto"  ON public.pending_payments FOR INSERT WITH CHECK (true);
CREATE POLICY "pending: select owner"    ON public.pending_payments FOR SELECT
  USING (auth.uid() = owner_id);
CREATE POLICY "pending: update owner"    ON public.pending_payments FOR UPDATE
  USING (auth.uid() = owner_id);

-- ---- OWNER_BALANCE ----
CREATE POLICY "owner_balance: select"    ON public.owner_balance FOR SELECT
  USING (auth.uid() = owner_id);
CREATE POLICY "owner_balance: insert"    ON public.owner_balance FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

-- ---- AGENCY_BALANCE ----
CREATE POLICY "agency_balance: select"   ON public.agency_balance FOR SELECT
  USING (auth.uid() = agency_id);
CREATE POLICY "agency_balance: insert"   ON public.agency_balance FOR INSERT
  WITH CHECK (auth.uid() = agency_id);

-- ================================================================
-- REALTIME — Habilitar para actualizaciones en vivo
-- ================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.sales_simple;
ALTER PUBLICATION supabase_realtime ADD TABLE public.seats;
ALTER PUBLICATION supabase_realtime ADD TABLE public.pending_payments;

-- ================================================================
-- STORAGE — Bucket para comprobantes de pago
-- (guardado en un DO: el Postgres local del CI arranca sin storage-api y
--  su esquema storage no tiene estas columnas; en producción sí existen)
-- ================================================================
DO $storage$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='storage' AND table_name='buckets' AND column_name='public') THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('comprobantes', 'comprobantes', true, 5242880,
            ARRAY['image/jpeg','image/png','image/webp','application/pdf'])
    ON CONFLICT (id) DO NOTHING;

    EXECUTE $p$CREATE POLICY "comprobantes: upload abierto"
      ON storage.objects FOR INSERT
      WITH CHECK (bucket_id = 'comprobantes')$p$;

    EXECUTE $p$CREATE POLICY "comprobantes: lectura pública"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'comprobantes')$p$;
  END IF;
END;
$storage$;
