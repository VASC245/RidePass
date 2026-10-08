-- Solo el rol dueño puede crear o modificar chivas, tours y salidas.
-- Antes bastaba con ser dueño de la fila (auth.uid() = user_id), así que un
-- cliente, agencia o negocio podía publicar oferta en el marketplace.
alter policy "chivas: dueño gestiona" on public.chivas
  with check (auth.uid() = user_id and public.my_role() = 'dueño');

alter policy "tours: dueño gestiona" on public.tours
  with check (auth.uid() = user_id and public.my_role() = 'dueño');

alter policy "assigned: dueño gestiona" on public.assigned_chivas
  with check (
    auth.uid() = owner_id
    and public.my_role() = 'dueño'
    and exists (select 1 from public.tours t  where t.id = assigned_chivas.tour_id  and t.user_id = auth.uid())
    and exists (select 1 from public.chivas c where c.id = assigned_chivas.chiva_id and c.user_id = auth.uid())
  );

-- Un mismo archivo de comprobante no puede respaldar dos reservas, aunque
-- lleguen al mismo tiempo (la validación en la edge function no es atómica).
create unique index if not exists pending_payments_comprobante_path_key
  on public.pending_payments (comprobante_path)
  where comprobante_path is not null;
