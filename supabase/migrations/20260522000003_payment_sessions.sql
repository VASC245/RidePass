-- ================================================================
-- ChivasPass — Sesiones de pago con tarjeta (Kushki)
-- ================================================================

CREATE TABLE IF NOT EXISTS public.payment_sessions (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id           uuid,
  ticket_type         text        NOT NULL CHECK (ticket_type IN ('chiva', 'business')),
  amount              numeric     NOT NULL,
  currency            text        NOT NULL DEFAULT 'USD',
  provider            text        NOT NULL DEFAULT 'kushki',
  provider_token      text,
  provider_charge_id  text,
  status              text        NOT NULL DEFAULT 'pending'
                                  CHECK (status IN ('pending','approved','declined','error')),
  metadata            jsonb,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_sessions_ticket ON public.payment_sessions(ticket_id);
CREATE INDEX IF NOT EXISTS idx_payment_sessions_status ON public.payment_sessions(status);

ALTER TABLE public.payment_sessions ENABLE ROW LEVEL SECURITY;

-- Solo el service_role (Edge Functions) puede insertar/leer sesiones de pago
-- El frontend NUNCA toca esta tabla directamente
CREATE POLICY "payment_sessions: service only" ON public.payment_sessions
  USING (false) WITH CHECK (false);

-- ================================================================
-- Acceso público a tickets verificados (por UUID = no adivinable)
-- Necesario para que el link de WhatsApp funcione sin login
-- ================================================================
CREATE POLICY "btickets: public view verified"
  ON public.business_tickets
  FOR SELECT
  USING (payment_status = 'verificado');
