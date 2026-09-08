-- ================================================================
-- ChivasPass — Configuración de panel por usuario
-- ================================================================
CREATE TABLE IF NOT EXISTS public.panel_settings (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE CASCADE,

  -- Datos de pago / transferencia
  bank_name        text        NOT NULL DEFAULT '',
  bank_account     text        NOT NULL DEFAULT '',
  bank_owner       text        NOT NULL DEFAULT '',
  bank_type        text        NOT NULL DEFAULT 'ahorros'
                               CHECK (bank_type IN ('corriente','ahorros')),

  -- Contacto
  contact_phone    text        NOT NULL DEFAULT '',
  contact_whatsapp text        NOT NULL DEFAULT '',
  contact_email    text        NOT NULL DEFAULT '',

  -- Redes sociales
  instagram        text        NOT NULL DEFAULT '',
  facebook         text        NOT NULL DEFAULT '',

  -- Personalización
  logo_url         text,
  business_name    text        NOT NULL DEFAULT '',
  notes            text        NOT NULL DEFAULT '',

  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_panel_settings_user ON public.panel_settings(user_id);

ALTER TABLE public.panel_settings ENABLE ROW LEVEL SECURITY;

-- El dueño gestiona sus propios ajustes
CREATE POLICY "settings: user manages own"
  ON public.panel_settings FOR ALL
  USING (auth.uid() = user_id);

-- Lectura pública para mostrar datos de pago en el checkout
CREATE POLICY "settings: public read"
  ON public.panel_settings FOR SELECT
  USING (true);

GRANT SELECT ON public.panel_settings TO anon, authenticated;
GRANT INSERT, UPDATE ON public.panel_settings TO authenticated;
