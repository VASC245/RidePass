-- ================================================================
-- Rendimiento de RLS e índices (avisos del linter de Supabase, 11 nov 2026)
--
-- 1. Las políticas llamaban auth.uid() y my_role() una vez POR FILA. Con
--    (select ...) Postgres las evalúa una sola vez por consulta. La lógica
--    de permisos es idéntica: solo cambia cuándo se calcula.
-- 2. Índices para las llaves foráneas que no tenían (borrados en cascada y
--    joins de saldos y comprobantes).
-- ================================================================

ALTER POLICY "agency_balance: select" ON public.agency_balance
  USING ((select auth.uid()) = agency_id);

ALTER POLICY "assigned: conductor actualiza" ON public.assigned_chivas
  USING (EXISTS ( SELECT 1 FROM public.drivers d WHERE ((d.chiva_id = assigned_chivas.chiva_id) AND (d.user_id = (select auth.uid())))))
  WITH CHECK (EXISTS ( SELECT 1 FROM public.drivers d WHERE ((d.chiva_id = assigned_chivas.chiva_id) AND (d.user_id = (select auth.uid())))));

ALTER POLICY "assigned: conductor lee" ON public.assigned_chivas
  USING (EXISTS ( SELECT 1 FROM public.drivers d WHERE ((d.chiva_id = assigned_chivas.chiva_id) AND (d.user_id = (select auth.uid())))));

ALTER POLICY "assigned: dueño gestiona" ON public.assigned_chivas
  USING ((select auth.uid()) = owner_id)
  WITH CHECK (((select auth.uid()) = owner_id) AND ((select public.my_role()) = 'dueño'::text) AND (EXISTS ( SELECT 1 FROM public.tours t WHERE ((t.id = assigned_chivas.tour_id) AND (t.user_id = (select auth.uid()))))) AND (EXISTS ( SELECT 1 FROM public.chivas c WHERE ((c.id = assigned_chivas.chiva_id) AND (c.user_id = (select auth.uid()))))));

ALTER POLICY "bevents: dueño gestiona" ON public.business_events
  USING ((select auth.uid()) = owner_id)
  WITH CHECK (((select auth.uid()) = owner_id) AND (EXISTS ( SELECT 1 FROM public.businesses b WHERE ((b.id = business_events.business_id) AND (b.owner_id = (select auth.uid()))))));

ALTER POLICY "btickets: owner select" ON public.business_tickets
  USING ((select auth.uid()) = owner_id);

ALTER POLICY "businesses: dueño gestiona" ON public.businesses
  USING ((select auth.uid()) = owner_id)
  WITH CHECK (((select auth.uid()) = owner_id) AND ((select public.my_role()) = 'negocio'::text));

ALTER POLICY "chivas: dueño gestiona" ON public.chivas
  USING ((select auth.uid()) = user_id)
  WITH CHECK (((select auth.uid()) = user_id) AND ((select public.my_role()) = 'dueño'::text));

ALTER POLICY "drivers: conductor lee lo suyo" ON public.drivers
  USING ((select auth.uid()) = user_id);

ALTER POLICY "drivers: dueño gestiona" ON public.drivers
  USING ((select auth.uid()) = owner_id)
  WITH CHECK (((select auth.uid()) = owner_id) AND ((chiva_id IS NULL) OR (EXISTS ( SELECT 1 FROM public.chivas c WHERE ((c.id = drivers.chiva_id) AND (c.user_id = (select auth.uid())))))) AND ((user_id IS NULL) OR public.is_conductor(user_id)));

ALTER POLICY "owner_balance: select" ON public.owner_balance
  USING ((select auth.uid()) = owner_id);

ALTER POLICY "settings: user manages own" ON public.panel_settings
  USING ((select auth.uid()) = user_id);

ALTER POLICY "pending: select owner" ON public.pending_payments
  USING ((select auth.uid()) = owner_id);

ALTER POLICY "sales: select owner" ON public.sales_simple
  USING (((select auth.uid()) = owner_id) OR ((select auth.uid()) = agency_id));

ALTER POLICY "subs: user reads own" ON public.subscriptions
  USING ((select auth.uid()) = user_id);

ALTER POLICY "tours: dueño gestiona" ON public.tours
  USING ((select auth.uid()) = user_id)
  WITH CHECK (((select auth.uid()) = user_id) AND ((select public.my_role()) = 'dueño'::text));

ALTER POLICY "users: select propio" ON public.users
  USING ((select auth.uid()) = id);

ALTER POLICY "users: update propio" ON public.users
  USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);


CREATE INDEX IF NOT EXISTS idx_agency_balance_assigned   ON public.agency_balance (assigned_chiva_id);
CREATE INDEX IF NOT EXISTS idx_agency_balance_comprobante ON public.agency_balance (comprobante_id);
CREATE INDEX IF NOT EXISTS idx_owner_balance_assigned    ON public.owner_balance (assigned_chiva_id);
CREATE INDEX IF NOT EXISTS idx_owner_balance_comprobante ON public.owner_balance (comprobante_id);
CREATE INDEX IF NOT EXISTS idx_invite_codes_used_by      ON public.owner_invite_codes (used_by);
CREATE INDEX IF NOT EXISTS idx_pending_agency            ON public.pending_payments (agency_id);
CREATE INDEX IF NOT EXISTS idx_pending_verified_by       ON public.pending_payments (verified_by);
