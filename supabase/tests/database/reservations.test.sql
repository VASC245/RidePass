-- Pruebas pgTAP de la lógica crítica de ventas.
-- Se ejecutan con `supabase test db` (local o CI) sobre las migraciones.
BEGIN;
SELECT plan(19);

-- ───────────── Datos de prueba ─────────────
-- Usuarios en auth.users: el trigger handle_new_user crea public.users.
INSERT INTO auth.users (id, email, raw_user_meta_data, instance_id, aud, role, encrypted_password, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-00000000aa01', 'dueno@test.local',   '{"full_name":"Dueño Test","role":"dueño","owner_code":"TEST-CODE"}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now()),
  ('00000000-0000-0000-0000-00000000aa02', 'agencia@test.local', '{"full_name":"Agencia Test","role":"agencia"}',                          '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now()),
  ('00000000-0000-0000-0000-00000000aa03', 'pirata@test.local',  '{"full_name":"Pirata","role":"dueño"}',                                 '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now()),
  ('00000000-0000-0000-0000-00000000aa04', 'negocio@test.local', '{"full_name":"Negocio Test","role":"negocio"}',                          '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now());

-- El primero no tenía código válido en la tabla todavía → cae a agencia. Lo
-- corregimos insertando el código y volviendo a evaluar con un usuario nuevo.
INSERT INTO public.owner_invite_codes (code) VALUES ('TEST-CODE');
INSERT INTO auth.users (id, email, raw_user_meta_data, instance_id, aud, role, encrypted_password, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-00000000aa05', 'dueno2@test.local', '{"full_name":"Dueño Real","role":"dueño","owner_code":"TEST-CODE"}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now());

SELECT is((SELECT role FROM public.users WHERE id = '00000000-0000-0000-0000-00000000aa03'), 'agencia',
  'Registrarse como dueño sin código válido cae a agencia');
SELECT is((SELECT role FROM public.users WHERE id = '00000000-0000-0000-0000-00000000aa05'), 'dueño',
  'Registrarse como dueño con código válido funciona');
SELECT is((SELECT used_by FROM public.owner_invite_codes WHERE code = 'TEST-CODE'), '00000000-0000-0000-0000-00000000aa05'::uuid,
  'El código de invitación queda consumido');

-- Dueño real: chiva, tour y salida
INSERT INTO public.chivas (id, name, plate, code, capacity, user_id)
VALUES ('00000000-0000-0000-0000-00000000cc01', 'Chiva Test', 'ABC-123', 'CH1', 4, '00000000-0000-0000-0000-00000000aa05');
INSERT INTO public.tours (id, title, base_price, duration, user_id)
VALUES ('00000000-0000-0000-0000-00000000dd01', 'Tour Test', 5, 60, '00000000-0000-0000-0000-00000000aa05');
INSERT INTO public.assigned_chivas (id, tour_id, chiva_id, departure_at, owner_id)
VALUES ('00000000-0000-0000-0000-00000000ee01', '00000000-0000-0000-0000-00000000dd01', '00000000-0000-0000-0000-00000000cc01', now() + interval '2 days', '00000000-0000-0000-0000-00000000aa05');

SELECT is((SELECT count(*) FROM public.seats WHERE assigned_chiva_id = '00000000-0000-0000-0000-00000000ee01'), 4::bigint,
  'El trigger genera un asiento por cada plaza de la chiva');

-- ───────────── Reserva de asientos ─────────────
SELECT lives_ok(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-00000000ee01', ARRAY[1,2],
       '{"name":"Ana","email":"ana@test.local","phone":"0999","cedula":"1"}'::jsonb, NULL, 'pendiente', 'transferencia', 'TRX-1') $$,
  'Reserva de dos asientos libres');

SELECT is((SELECT count(*) FROM public.seats WHERE assigned_chiva_id = '00000000-0000-0000-0000-00000000ee01' AND status = 'reservado'), 2::bigint,
  'Los asientos reservados quedan en estado reservado');

SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-00000000ee01', ARRAY[2,3],
       '{"name":"Beto","email":"beto@test.local"}'::jsonb, NULL, 'pendiente', 'transferencia', 'TRX-2') $$,
  '%SEATS_UNAVAILABLE%',
  'No se puede vender un asiento ya reservado');

SELECT is((SELECT count(*) FROM public.sales_simple WHERE assigned_chiva_id = '00000000-0000-0000-0000-00000000ee01'), 1::bigint,
  'La reserva fallida no deja venta huérfana');

-- Confirmar y cancelar
SELECT lives_ok(
  $$ SELECT public.confirm_sale((SELECT id FROM public.sales_simple LIMIT 1), 'TRX-1') $$,
  'Confirmar la venta');
SELECT is((SELECT count(*) FROM public.seats WHERE assigned_chiva_id = '00000000-0000-0000-0000-00000000ee01' AND status = 'pagado'), 2::bigint,
  'Al confirmar, los asientos pasan a pagado');

SELECT lives_ok(
  $$ SELECT public.cancel_sale((SELECT id FROM public.sales_simple LIMIT 1)) $$,
  'Cancelar la venta');
SELECT is((SELECT count(*) FROM public.seats WHERE assigned_chiva_id = '00000000-0000-0000-0000-00000000ee01' AND status = 'disponible'), 4::bigint,
  'Al cancelar, los asientos vuelven a disponible');

-- ───────────── Cupo de eventos ─────────────
INSERT INTO public.businesses (id, owner_id, name, category)
VALUES ('00000000-0000-0000-0000-00000000bb01', '00000000-0000-0000-0000-00000000aa04', 'Cascada Test', 'cascada');
INSERT INTO public.business_events (id, business_id, owner_id, title, price, capacity, event_date)
VALUES ('00000000-0000-0000-0000-00000000ef01', '00000000-0000-0000-0000-00000000bb01', '00000000-0000-0000-0000-00000000aa04', 'Evento Test', 10, 3, now() + interval '1 day');

SELECT lives_ok(
  $$ SELECT public.create_business_ticket('00000000-0000-0000-0000-00000000ef01', 2,
       '{"name":"Ana","email":"ana@test.local","phone":"0999","cedula":"1"}'::jsonb, 'pendiente', 'TRX-9', 'comprobantes/x.jpg') $$,
  'Ticket dentro del cupo');

SELECT throws_like(
  $$ SELECT public.create_business_ticket('00000000-0000-0000-0000-00000000ef01', 2,
       '{"name":"Beto","email":"beto@test.local","phone":"0999","cedula":"2"}'::jsonb, 'pendiente', 'TRX-10', 'comprobantes/y.jpg') $$,
  '%CAPACITY_EXCEEDED%',
  'No se puede sobrevender un evento');

-- ───────────── Controles del dueño ─────────────
UPDATE public.assigned_chivas SET sales_open = false WHERE id = '00000000-0000-0000-0000-00000000ee01';
SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-00000000ee01', ARRAY[1],
       '{"name":"Eva","email":"eva@test.local"}'::jsonb, NULL, 'pendiente', 'transferencia', 'TRX-3') $$,
  '%SALES_CLOSED%',
  'Con ventas cerradas nadie compra');
SELECT lives_ok(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-00000000ee01', ARRAY[1],
       '{"name":"Eva","email":"eva@test.local"}'::jsonb, NULL, 'pagado', 'efectivo', NULL) $$,
  'El dueño sí vende en efectivo aunque las ventas públicas estén cerradas');
UPDATE public.assigned_chivas SET sales_open = true WHERE id = '00000000-0000-0000-0000-00000000ee01';

INSERT INTO public.panel_settings (user_id, accept_transfers) VALUES ('00000000-0000-0000-0000-00000000aa05', false);
SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-00000000ee01', ARRAY[2],
       '{"name":"Fer","email":"fer@test.local"}'::jsonb, NULL, 'pendiente', 'transferencia', 'TRX-4') $$,
  '%METHOD_DISABLED%',
  'Con transferencias desactivadas se rechaza ese método');

UPDATE public.tours SET allow_agency_sales = false WHERE id = '00000000-0000-0000-0000-00000000dd01';
SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-00000000ee01', ARRAY[2],
       '{"name":"Gus","email":"gus@test.local"}'::jsonb, '00000000-0000-0000-0000-00000000aa02', 'pendiente', 'tarjeta', NULL) $$,
  '%AGENCY_DISABLED%',
  'Tour sin venta por agencias rechaza a la agencia');

UPDATE public.tours SET active = false WHERE id = '00000000-0000-0000-0000-00000000dd01';
SELECT is(
  (SELECT count(*) FROM public.tours WHERE id = '00000000-0000-0000-0000-00000000dd01' AND public.seller_is_public(user_id) AND active), 0::bigint,
  'Un tour inactivo no cumple la condición de lectura pública');

SELECT * FROM finish();
ROLLBACK;
