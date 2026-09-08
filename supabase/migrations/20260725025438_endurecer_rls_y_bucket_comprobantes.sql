-- Migración aplicada a mano en producción el 25 jul 2026 (traída al repo el
-- 7 sep 2026 para que el historial local y el remoto coincidan).
-- Las políticas que crea las elimina después 20260907000000_security_hardening.
drop policy if exists "seats: update abierto" on public.seats;
create policy "seats: update autenticados"
  on public.seats for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "sales: insert abierto" on public.sales_simple;
create policy "sales: insert propio"
  on public.sales_simple for insert
  to authenticated
  with check (auth.uid() = owner_id or auth.uid() = agency_id);

create policy "sales: update owner o agencia"
  on public.sales_simple for update
  to authenticated
  using (auth.uid() = owner_id or auth.uid() = agency_id);

drop policy if exists "pending: insert abierto" on public.pending_payments;
create policy "pending: insert propio"
  on public.pending_payments for insert
  to authenticated
  with check (auth.uid() = owner_id or auth.uid() = agency_id);

drop policy if exists "btickets: insert abierto" on public.business_tickets;
create policy "btickets: insert owner"
  on public.business_tickets for insert
  to authenticated
  with check (auth.uid() = owner_id);

DO $storage$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='storage' AND table_name='buckets' AND column_name='public') THEN
    UPDATE storage.buckets SET public = false WHERE id = 'comprobantes';
    EXECUTE 'DROP POLICY IF EXISTS "comprobantes: lectura pública" ON storage.objects';
    EXECUTE $p$CREATE POLICY "comprobantes: lectura autenticados"
      ON storage.objects FOR SELECT TO authenticated
      USING (bucket_id = 'comprobantes')$p$;
  END IF;
END;
$storage$;

revoke execute on function public.create_seats_for_assigned_chiva() from anon, authenticated;
revoke execute on function public.handle_new_user() from anon, authenticated;
