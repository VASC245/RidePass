-- Cierre de fugas detectadas en la auditoría del 13 sep 2026.
-- Todas las políticas RLS validaban el dueño de la fila, pero no que las
-- claves foráneas (tour, chiva, negocio) también fueran suyas. Además la
-- tabla seats exponía sale_id a anónimos, lo que permitía clonar tickets
-- vía get_public_ticket.

-- ================================================================
-- 1. seats: los clientes API ya no ven sale_id (solo el mapa de asientos)
-- ================================================================
REVOKE SELECT ON public.seats FROM anon, authenticated;
GRANT SELECT (id, assigned_chiva_id, seat_number, status) ON public.seats TO anon, authenticated;

-- ================================================================
-- 2. Privilegios que ninguna app necesita desde PostgREST
-- ================================================================
REVOKE TRUNCATE, TRIGGER, REFERENCES ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE, TRIGGER, REFERENCES ON TABLES FROM anon, authenticated;

-- ================================================================
-- 3. Helper: ¿este usuario es conductor?  (definer para no depender de RLS)
-- ================================================================
CREATE OR REPLACE FUNCTION public.is_conductor(p_user uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.users WHERE id = p_user AND role = 'conductor');
$$;
REVOKE ALL ON FUNCTION public.is_conductor(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_conductor(uuid) TO authenticated, service_role;

-- ================================================================
-- 4. assigned_chivas: la salida solo puede usar un tour y una chiva propios
-- ================================================================
DROP POLICY IF EXISTS "assigned: dueño gestiona" ON public.assigned_chivas;
CREATE POLICY "assigned: dueño gestiona" ON public.assigned_chivas FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (
    auth.uid() = owner_id
    AND EXISTS (SELECT 1 FROM public.tours  t WHERE t.id = tour_id  AND t.user_id = auth.uid())
    AND EXISTS (SELECT 1 FROM public.chivas c WHERE c.id = chiva_id AND c.user_id = auth.uid())
  );

-- ================================================================
-- 5. drivers: solo chivas propias y solo usuarios con rol conductor
-- ================================================================
DROP POLICY IF EXISTS "drivers: dueño gestiona" ON public.drivers;
CREATE POLICY "drivers: dueño gestiona" ON public.drivers FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (
    auth.uid() = owner_id
    AND (chiva_id IS NULL OR EXISTS (SELECT 1 FROM public.chivas c WHERE c.id = chiva_id AND c.user_id = auth.uid()))
    AND (user_id IS NULL OR public.is_conductor(user_id))
  );

-- ================================================================
-- 6. users: un dueño ya no lista a todos los conductores de la plataforma.
--    Busca por correo exacto con find_conductor().
-- ================================================================
DROP POLICY IF EXISTS "users: dueño ve conductores" ON public.users;

CREATE OR REPLACE FUNCTION public.find_conductor(p_email text)
RETURNS TABLE (id uuid, full_name text, email text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u.id, u.full_name, u.email
  FROM public.users u
  WHERE public.my_role() = 'dueño'
    AND u.role = 'conductor'
    AND lower(u.email) = lower(trim(p_email))
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.find_conductor(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.find_conductor(text) TO authenticated, service_role;

-- ================================================================
-- 7. businesses / business_events: solo rol negocio y solo negocio propio
-- ================================================================
DROP POLICY IF EXISTS "businesses: dueño gestiona" ON public.businesses;
CREATE POLICY "businesses: dueño gestiona" ON public.businesses FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id AND public.my_role() = 'negocio');

DROP POLICY IF EXISTS "bevents: dueño gestiona" ON public.business_events;
CREATE POLICY "bevents: dueño gestiona" ON public.business_events FOR ALL
  USING (auth.uid() = owner_id)
  WITH CHECK (
    auth.uid() = owner_id
    AND EXISTS (SELECT 1 FROM public.businesses b WHERE b.id = business_id AND b.owner_id = auth.uid())
  );

-- ================================================================
-- 8. Sin UPDATE directo sobre tickets ni comprobantes: siempre por RPC
--    (review_business_ticket / verify_pending_payment liberan cupos y
--    registran saldos; un UPDATE directo los dejaría inconsistentes).
-- ================================================================
DROP POLICY IF EXISTS "btickets: owner update" ON public.business_tickets;
DROP POLICY IF EXISTS "pending: update owner"  ON public.pending_payments;

-- ================================================================
-- 9. Datos bancarios solo de vendedores con listado público
-- ================================================================
CREATE OR REPLACE FUNCTION public.get_seller_payment_info(p_owner_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT CASE
    WHEN NOT public.seller_is_public(p_owner_id) THEN '{}'::jsonb
    ELSE coalesce(
      (SELECT jsonb_build_object(
        'bank_name', bank_name, 'bank_account', bank_account, 'bank_owner', bank_owner,
        'bank_type', bank_type, 'notes', notes, 'business_name', business_name)
       FROM public.panel_settings WHERE user_id = p_owner_id),
      '{}'::jsonb
    ) || public.seller_controls(p_owner_id) || jsonb_build_object('hours_open_now', public.seller_hours_open(p_owner_id))
  END;
$$;
