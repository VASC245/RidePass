-- Migración aplicada a mano en producción el 25 jul 2026 (traída al repo el
-- 7 sep 2026 para que el historial local y el remoto coincidan).
revoke execute on function public.create_seats_for_assigned_chiva() from public;
revoke execute on function public.handle_new_user() from public;

alter function public.create_seats_for_assigned_chiva() set search_path = public;
alter function public.handle_new_user() set search_path = public;
