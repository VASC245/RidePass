-- ================================================================
-- Correcciones detectadas al correr el checklist en producción
--   1. handle_new_user: marcaba el código de invitación como usado ANTES
--      de crear la fila en public.users → violaba la FK y el registro de
--      dueño con código fallaba. Ahora inserta primero y marca después.
--   2. search_path fijo en funciones auxiliares (advisor de Supabase).
--   3. Las RPC del panel/escáner no deben ser ejecutables por anon.
-- ================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  requested  text := coalesce(NEW.raw_user_meta_data->>'role', 'agencia');
  final_role text := 'agencia';
  invite     text := NEW.raw_user_meta_data->>'owner_code';
  use_invite boolean := false;
BEGIN
  IF requested IN ('agencia', 'negocio', 'conductor', 'cliente') THEN
    final_role := requested;
  ELSIF requested = 'dueño' AND invite IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.owner_invite_codes WHERE code = invite AND used_by IS NULL
  ) THEN
    final_role := 'dueño';
    use_invite := true;
  END IF;

  INSERT INTO public.users (id, full_name, email, role)
  VALUES (
    NEW.id,
    coalesce(NEW.raw_user_meta_data->>'full_name', split_part(coalesce(NEW.email, ''), '@', 1)),
    coalesce(NEW.email, NEW.id::text || '@sin-correo.local'),
    final_role
  )
  ON CONFLICT (id) DO NOTHING;

  IF use_invite THEN
    UPDATE public.owner_invite_codes SET used_by = NEW.id, used_at = now()
     WHERE code = invite AND used_by IS NULL;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_api_client()
RETURNS boolean LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT coalesce(auth.role(), '') IN ('anon', 'authenticated');
$$;

CREATE OR REPLACE FUNCTION public.sale_seat_count(p_seats jsonb)
RETURNS int LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT CASE
    WHEN p_seats IS NULL THEN 0
    WHEN jsonb_typeof(p_seats) = 'array' THEN jsonb_array_length(p_seats)
    WHEN jsonb_typeof(p_seats) = 'string' THEN coalesce(jsonb_array_length((p_seats #>> '{}')::jsonb), 0)
    ELSE 0 END;
$$;

CREATE OR REPLACE FUNCTION public.setting_int(p_key text, p_default int)
RETURNS int LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT coalesce((SELECT value::int FROM public.app_settings WHERE key = p_key), p_default);
$$;

-- Solo usuarios con sesión (el GRANT a authenticated ya existe)
REVOKE ALL ON FUNCTION public.board_sale(text)                   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.use_business_ticket(text)          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.verify_pending_payment(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.review_business_ticket(uuid, text) FROM PUBLIC, anon;
-- Públicas a propósito (ticket por enlace y datos bancarios del vendedor),
-- pero sin el EXECUTE implícito a PUBLIC
REVOKE ALL ON FUNCTION public.get_public_ticket(uuid)            FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_seller_payment_info(uuid)      FROM PUBLIC;
REVOKE ALL ON FUNCTION public.my_role()                          FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_api_client()                    FROM PUBLIC;
REVOKE ALL ON FUNCTION public.sale_seat_count(jsonb)             FROM PUBLIC;
REVOKE ALL ON FUNCTION public.setting_int(text, int)             FROM PUBLIC, anon, authenticated;
