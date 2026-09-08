-- ================================================================
-- ChivasPass — Planes de suscripción
-- ================================================================

-- Agregar columna plan a users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS plan text NOT NULL DEFAULT 'free'
  CHECK (plan IN ('free', 'basico', 'pro'));

-- Tabla de suscripciones activas
CREATE TABLE IF NOT EXISTS public.subscriptions (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,
  plan         text        NOT NULL DEFAULT 'free' CHECK (plan IN ('free','basico','pro')),
  status       text        NOT NULL DEFAULT 'activo' CHECK (status IN ('activo','vencido','cancelado')),
  started_at   timestamptz NOT NULL DEFAULT now(),
  expires_at   timestamptz,
  payment_ref  text,
  amount_paid  numeric,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "subs: user reads own"    ON public.subscriptions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "subs: service manages"  ON public.subscriptions FOR ALL   USING (auth.uid() = user_id);

GRANT SELECT ON public.subscriptions TO authenticated;
GRANT SELECT ON public.users TO authenticated;
