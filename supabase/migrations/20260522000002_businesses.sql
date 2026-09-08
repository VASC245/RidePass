-- ================================================================
-- ChivasPass — Módulo de Negocios / Atracciones Turísticas
-- ================================================================

-- Actualizar roles permitidos para incluir 'negocio'
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check
  CHECK (role IN ('dueño', 'agencia', 'conductor', 'negocio'));

-- ================================================================
-- 1. BUSINESSES — Negocios turísticos afiliados
-- ================================================================
CREATE TABLE IF NOT EXISTS public.businesses (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  description text        NOT NULL DEFAULT '',
  category    text        NOT NULL DEFAULT 'otro'
                          CHECK (category IN ('cascada','deporte','termas','restaurante','otro')),
  address     text,
  image_url   text,
  active      boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_businesses_owner    ON public.businesses(owner_id);
CREATE INDEX IF NOT EXISTS idx_businesses_category ON public.businesses(category);
CREATE INDEX IF NOT EXISTS idx_businesses_active   ON public.businesses(active);

-- ================================================================
-- 2. BUSINESS_EVENTS — Eventos / sesiones con cupos
-- ================================================================
CREATE TABLE IF NOT EXISTS public.business_events (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id      uuid        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  owner_id         uuid        NOT NULL REFERENCES public.users(id),
  title            text        NOT NULL,
  description      text        NOT NULL DEFAULT '',
  price            numeric     NOT NULL DEFAULT 0 CHECK (price >= 0),
  capacity         int         NOT NULL DEFAULT 50 CHECK (capacity > 0),
  event_date       timestamptz NOT NULL,
  duration_minutes int,
  status           text        NOT NULL DEFAULT 'activo'
                               CHECK (status IN ('activo','agotado','cancelado','finalizado')),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bevents_business ON public.business_events(business_id);
CREATE INDEX IF NOT EXISTS idx_bevents_owner    ON public.business_events(owner_id);
CREATE INDEX IF NOT EXISTS idx_bevents_date     ON public.business_events(event_date);
CREATE INDEX IF NOT EXISTS idx_bevents_status   ON public.business_events(status);

-- ================================================================
-- 3. BUSINESS_TICKETS — Tickets vendidos para eventos
-- ================================================================
CREATE TABLE IF NOT EXISTS public.business_tickets (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id            uuid        NOT NULL REFERENCES public.business_events(id),
  business_id         uuid        NOT NULL REFERENCES public.businesses(id),
  owner_id            uuid        NOT NULL REFERENCES public.users(id),
  customer_name       text        NOT NULL,
  customer_email      text        NOT NULL,
  customer_cedula     text        NOT NULL,
  customer_phone      text        NOT NULL,
  quantity            int         NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price          numeric     NOT NULL,
  total_price         numeric     NOT NULL,
  payment_proof_url   text,
  payment_proof_path  text,
  payment_number      text,
  payment_status      text        NOT NULL DEFAULT 'pendiente'
                                  CHECK (payment_status IN ('pendiente','verificado','rechazado')),
  qr_payload          text,
  used                boolean     NOT NULL DEFAULT false,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_btickets_event    ON public.business_tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_btickets_business ON public.business_tickets(business_id);
CREATE INDEX IF NOT EXISTS idx_btickets_owner    ON public.business_tickets(owner_id);
CREATE INDEX IF NOT EXISTS idx_btickets_status   ON public.business_tickets(payment_status);

-- ================================================================
-- RLS
-- ================================================================
ALTER TABLE public.businesses       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_events  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_tickets ENABLE ROW LEVEL SECURITY;

-- BUSINESSES
CREATE POLICY "businesses: dueño gestiona"   ON public.businesses FOR ALL    USING (auth.uid() = owner_id);
CREATE POLICY "businesses: lectura pública"  ON public.businesses FOR SELECT USING (active = true);

-- BUSINESS_EVENTS
CREATE POLICY "bevents: dueño gestiona"      ON public.business_events FOR ALL    USING (auth.uid() = owner_id);
CREATE POLICY "bevents: lectura pública"     ON public.business_events FOR SELECT USING (status = 'activo');

-- BUSINESS_TICKETS
CREATE POLICY "btickets: insert abierto"     ON public.business_tickets FOR INSERT WITH CHECK (true);
CREATE POLICY "btickets: owner select"       ON public.business_tickets FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "btickets: owner update"       ON public.business_tickets FOR UPDATE USING (auth.uid() = owner_id);

-- ================================================================
-- REALTIME
-- ================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.business_tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.business_events;
