-- Pruebas pgTAP del cobro con PayPhone (migración 20261110000001).
BEGIN;
SELECT plan(17);

-- ───────────── Datos de prueba ─────────────
INSERT INTO public.owner_invite_codes (code) VALUES ('PP-DUENO'), ('PP-DUENO2');
INSERT INTO auth.users (id, email, raw_user_meta_data, instance_id, aud, role, encrypted_password, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-0000000000b1', 'pp-dueno@test.local',  '{"full_name":"Dueño PP","role":"dueño","owner_code":"PP-DUENO"}',   '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now()),
  ('00000000-0000-0000-0000-0000000000b2', 'pp-dueno2@test.local', '{"full_name":"Dueño Sin PP","role":"dueño","owner_code":"PP-DUENO2"}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now());

INSERT INTO public.chivas (id, name, plate, code, capacity, user_id) VALUES
  ('00000000-0000-0000-0000-0000000000c1', 'Chiva PP', 'PPP-001', 'PP1', 6, '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000c2', 'Chiva Sin PP', 'PPP-002', 'PP2', 6, '00000000-0000-0000-0000-0000000000b2');
INSERT INTO public.tours (id, title, base_price, duration, user_id) VALUES
  ('00000000-0000-0000-0000-0000000000d1', 'Tour PP', 10, 60, '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000d2', 'Tour Sin PP', 10, 60, '00000000-0000-0000-0000-0000000000b2');
INSERT INTO public.assigned_chivas (id, tour_id, chiva_id, departure_at, owner_id) VALUES
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000c1', now() + interval '2 days', '00000000-0000-0000-0000-0000000000b1'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000c2', now() + interval '2 days', '00000000-0000-0000-0000-0000000000b2');

-- ───────────── Cuenta PayPhone del vendedor ───────────────
SELECT throws_ok(
  $$ INSERT INTO public.panel_settings (user_id, payphone_identifier, payphone_id_type)
     VALUES ('00000000-0000-0000-0000-0000000000b1', '12345', 3) $$,
  '23514', NULL, 'Un RUC o cédula con largo inválido se rechaza');
SELECT throws_ok(
  $$ INSERT INTO public.panel_settings (user_id, payphone_identifier, payphone_id_type)
     VALUES ('00000000-0000-0000-0000-0000000000b1', '1790012345001', NULL) $$,
  '23514', NULL, 'El identificador sin tipo se rechaza');

INSERT INTO public.panel_settings (user_id, payphone_identifier, payphone_id_type)
VALUES ('00000000-0000-0000-0000-0000000000b1', '099 123-4567', 4);
SELECT is((SELECT payphone_identifier FROM public.panel_settings WHERE user_id = '00000000-0000-0000-0000-0000000000b1'),
  '+593991234567', 'El celular local se guarda como +593 sin espacios ni guiones');

UPDATE public.panel_settings SET payphone_identifier = '', payphone_id_type = 4
 WHERE user_id = '00000000-0000-0000-0000-0000000000b1';
SELECT is((SELECT coalesce(payphone_identifier, 'null') || '|' || coalesce(payphone_id_type::text, 'null')
             FROM public.panel_settings WHERE user_id = '00000000-0000-0000-0000-0000000000b1'),
  'null|null', 'Borrar el identificador también borra el tipo');

UPDATE public.panel_settings SET payphone_identifier = '1790012345001', payphone_id_type = 3
 WHERE user_id = '00000000-0000-0000-0000-0000000000b1';
INSERT INTO public.panel_settings (user_id) VALUES ('00000000-0000-0000-0000-0000000000b2');

SELECT is((public.seller_controls('00000000-0000-0000-0000-0000000000b1')->>'accept_payphone')::boolean, true,
  'Con cuenta PayPhone y tarjetas activas, el checkout ofrece PayPhone');
SELECT is((public.seller_controls('00000000-0000-0000-0000-0000000000b2')->>'accept_payphone')::boolean, false,
  'Sin cuenta PayPhone no se ofrece');
SELECT ok(NOT (public.get_seller_payment_info('00000000-0000-0000-0000-0000000000b1') ? 'payphone_identifier'),
  'La función pública no expone el identificador del vendedor');

SELECT is(public.setting_numeric('payphone_commission_pct', 0), 5.75::numeric, 'La comisión de PayPhone admite decimales');

-- ───────────── Receptores del split ───────────────
SELECT set_config('test.sale_pp', (public.reserve_tour_seats('00000000-0000-0000-0000-0000000000e1', ARRAY[1],
  '{"name":"Ana","email":"ana-pp@test.local"}'::jsonb, NULL, 'pendiente', 'tarjeta', NULL)->>'sale_id'), true);
SELECT set_config('test.sale_sin', (public.reserve_tour_seats('00000000-0000-0000-0000-0000000000e2', ARRAY[1],
  '{"name":"Beto","email":"beto-pp@test.local"}'::jsonb, NULL, 'pendiente', 'tarjeta', NULL)->>'sale_id'), true);

SELECT is(public.payphone_split_recipients('tour', current_setting('test.sale_pp')::uuid)->'recipients'->0->>'amount',
  '10', 'El receptor es el dueño con su precio íntegro');
SELECT throws_like(
  $$ SELECT public.payphone_split_recipients('tour', current_setting('test.sale_sin')::uuid) $$,
  '%METHOD_DISABLED%', 'Sin cuenta PayPhone el split responde METHOD_DISABLED');

-- ───────────── Reclamo atómico de la sesión ───────────────
INSERT INTO public.payment_sessions (ticket_type, ticket_id, amount, provider, provider_token, status, metadata)
VALUES ('tour', current_setting('test.sale_pp')::uuid, 11.10, 'payphone', 'TX-PP-1', 'pending', '{}');

SELECT is(public.payphone_claim_session('TX-PP-1')->>'state', 'claimed', 'La primera llamada reclama la sesión');
SELECT is(public.payphone_claim_session('TX-PP-1')->>'state', 'busy', 'Una segunda llamada inmediata queda en espera');
SELECT is(public.payphone_claim_session('NO-EXISTE')->>'state', 'not_found', 'Una sesión desconocida no existe');

-- ───────────── Cron con margen para tarjeta ───────────────
-- 16 minutos: una transferencia sin comprobante ya se liberaría; la tarjeta no.
UPDATE public.sales_simple SET created_at = now() - interval '16 minutes'
 WHERE id IN (current_setting('test.sale_pp')::uuid, current_setting('test.sale_sin')::uuid);
SELECT public.expire_pending_reservations();
SELECT is((SELECT status FROM public.sales_simple WHERE id = current_setting('test.sale_sin')::uuid), 'pendiente',
  'A los 16 minutos la reserva con tarjeta sigue esperando el pago');

-- 25 minutos: la que tiene confirmación en curso se respeta; la otra se libera.
UPDATE public.sales_simple SET created_at = now() - interval '25 minutes'
 WHERE id IN (current_setting('test.sale_pp')::uuid, current_setting('test.sale_sin')::uuid);
SELECT public.expire_pending_reservations();
SELECT is((SELECT status FROM public.sales_simple WHERE id = current_setting('test.sale_pp')::uuid), 'pendiente',
  'No se libera una venta con la confirmación de PayPhone en curso');
SELECT is((SELECT status FROM public.sales_simple WHERE id = current_setting('test.sale_sin')::uuid), 'cancelado',
  'A los 25 minutos sin pago la reserva con tarjeta se libera');

-- ───────────── Permisos ───────────────
SET LOCAL ROLE anon;
SELECT throws_ok(
  $$ SELECT public.payphone_split_recipients('tour', current_setting('test.sale_pp')::uuid) $$,
  '42501', NULL, 'Un visitante anónimo no puede leer los receptores del split');
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
