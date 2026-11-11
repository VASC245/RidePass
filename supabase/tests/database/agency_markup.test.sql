-- Pruebas pgTAP del sobreprecio de agencias (migración 20261111000001).
BEGIN;
SELECT plan(12);

-- ───────────── Datos de prueba ─────────────
INSERT INTO public.owner_invite_codes (code, role) VALUES ('SP-DUENO', 'dueño'), ('SP-AG', 'agencia');
INSERT INTO auth.users (id, email, raw_user_meta_data, instance_id, aud, role, encrypted_password, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-0000000005a1', 'sp-dueno@test.local',   '{"full_name":"Dueño SP","role":"dueño","owner_code":"SP-DUENO"}',      '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now()),
  ('00000000-0000-0000-0000-0000000005a2', 'sp-agencia@test.local', '{"full_name":"Agencia SP","role":"agencia","invite_code":"SP-AG"}',    '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now());

INSERT INTO public.chivas (id, name, plate, code, capacity, user_id)
VALUES ('00000000-0000-0000-0000-0000000005c1', 'Chiva SP', 'SPP-001', 'SP1', 8, '00000000-0000-0000-0000-0000000005a1');
INSERT INTO public.tours (id, title, base_price, duration, user_id, active, allow_agency_sales)
VALUES ('00000000-0000-0000-0000-0000000005d1', 'Tour SP', 10, 60, '00000000-0000-0000-0000-0000000005a1', true, true);
INSERT INTO public.assigned_chivas (id, tour_id, chiva_id, departure_at, owner_id)
VALUES ('00000000-0000-0000-0000-0000000005e1', '00000000-0000-0000-0000-0000000005d1', '00000000-0000-0000-0000-0000000005c1',
        now() + interval '2 days', '00000000-0000-0000-0000-0000000005a1');

SELECT is((SELECT count(*) FROM pg_proc WHERE proname = 'reserve_tour_seats'), 1::bigint,
  'Queda una sola firma de reserve_tour_seats (PostgREST no se confunde)');

-- ───────────── Venta con sobreprecio ─────────────
SELECT set_config('test.sp', public.reserve_tour_seats('00000000-0000-0000-0000-0000000005e1', ARRAY[1,2],
  '{"name":"Ana","email":"ana-sp@test.local"}'::jsonb, '00000000-0000-0000-0000-0000000005a2',
  'pendiente', 'transferencia', 'TRX-SP-1', 12)::text, true);

SELECT is((SELECT sale_price || '|' || total_sale || '|' || owner_gain || '|' || agency_gain || '|' || platform_fee || '|' || total_charged
             FROM public.sales_simple WHERE customer_email = 'ana-sp@test.local'),
  '12|24|20|4|0|24',
  'La agencia cobra $12 por asiento: el turista paga $24, el dueño recibe $20 y la agencia gana $4, sin cargo por servicio');
SELECT is((current_setting('test.sp')::jsonb->>'owner_amount') || '|' || (current_setting('test.sp')::jsonb->>'agency_amount'),
  '20|4', 'La función devuelve cuánto va al dueño y cuánto a la agencia');

SELECT lives_ok(
  $$ SELECT public.confirm_sale((current_setting('test.sp')::jsonb->>'sale_id')::uuid, 'TRX-SP-1') $$,
  'El dueño confirma la venta de la agencia');
SELECT is((SELECT monto_total FROM public.owner_balance WHERE sale_id = (current_setting('test.sp')::jsonb->>'sale_id')::uuid),
  20::numeric, 'Al saldo del dueño entra solo su precio');
SELECT is((SELECT monto_total FROM public.agency_balance WHERE sale_id = (current_setting('test.sp')::jsonb->>'sale_id')::uuid),
  4::numeric, 'Al saldo de la agencia entra su ganancia');

-- ───────────── Precios no válidos ─────────────
SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-0000000005e1', ARRAY[3],
       '{"name":"Beto","email":"beto-sp@test.local"}'::jsonb, '00000000-0000-0000-0000-0000000005a2',
       'pendiente', 'transferencia', 'TRX-SP-2', 9.99) $$,
  '%AGENCY_PRICE_INVALID%', 'La agencia no puede vender por debajo del precio del dueño');
SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-0000000005e1', ARRAY[3],
       '{"name":"Beto","email":"beto-sp@test.local"}'::jsonb, '00000000-0000-0000-0000-0000000005a2',
       'pendiente', 'transferencia', 'TRX-SP-2', 30.01) $$,
  '%AGENCY_PRICE_INVALID%', 'Ni por encima del triple');
SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-0000000005e1', ARRAY[3],
       '{"name":"Beto","email":"beto-sp@test.local"}'::jsonb, '00000000-0000-0000-0000-0000000005a2',
       'pendiente', 'transferencia', 'TRX-SP-2', 12.345) $$,
  '%AGENCY_PRICE_INVALID%', 'Ni con más de dos decimales');
SELECT throws_like(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-0000000005e1', ARRAY[3],
       '{"name":"Beto","email":"beto-sp@test.local"}'::jsonb, NULL,
       'pendiente', 'transferencia', 'TRX-SP-2', 12) $$,
  '%AGENCY_PRICE_NOT_AGENCY%', 'Solo una agencia puede poner su propio precio');

-- ───────────── Sin sobreprecio ─────────────
SELECT lives_ok(
  $$ SELECT public.reserve_tour_seats('00000000-0000-0000-0000-0000000005e1', ARRAY[3],
       '{"name":"Caro","email":"caro-sp@test.local"}'::jsonb, '00000000-0000-0000-0000-0000000005a2',
       'pendiente', 'transferencia', 'TRX-SP-3') $$,
  'La agencia puede vender al precio del dueño sin indicar precio');
SELECT is((SELECT total_sale || '|' || owner_gain || '|' || agency_gain FROM public.sales_simple WHERE customer_email = 'caro-sp@test.local'),
  '10|10|0', 'Sin sobreprecio todo es para el dueño');

SELECT * FROM finish();
ROLLBACK;
