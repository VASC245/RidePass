-- Pruebas pgTAP del borrado de comprobantes (migración 20261111000003).
BEGIN;
SELECT plan(9);

INSERT INTO public.owner_invite_codes (code, role) VALUES ('PG-DUENO', 'dueño'), ('PG-NEG', 'negocio');
INSERT INTO auth.users (id, email, raw_user_meta_data, instance_id, aud, role, encrypted_password, created_at, updated_at)
VALUES
  ('00000000-0000-0000-0000-0000000006a1', 'pg-dueno@test.local', '{"full_name":"Dueño PG","role":"dueño","owner_code":"PG-DUENO"}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now()),
  ('00000000-0000-0000-0000-0000000006a2', 'pg-neg@test.local',   '{"full_name":"Negocio PG","role":"negocio","invite_code":"PG-NEG"}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'x', now(), now());

INSERT INTO public.chivas (id, name, plate, code, capacity, user_id)
VALUES ('00000000-0000-0000-0000-0000000006c1', 'Chiva PG', 'PGG-001', 'PG1', 4, '00000000-0000-0000-0000-0000000006a1');
INSERT INTO public.tours (id, title, base_price, duration, user_id)
VALUES ('00000000-0000-0000-0000-0000000006d1', 'Tour PG', 10, 60, '00000000-0000-0000-0000-0000000006a1');

-- Salidas de hace 100 días (vencida), 30 días (no) y futura (no). Los
-- triggers de fechas se saltan con session_replication_role.
SET LOCAL session_replication_role = replica;
INSERT INTO public.assigned_chivas (id, tour_id, chiva_id, departure_at, owner_id) VALUES
  ('00000000-0000-0000-0000-0000000006e1', '00000000-0000-0000-0000-0000000006d1', '00000000-0000-0000-0000-0000000006c1', now() - interval '100 days', '00000000-0000-0000-0000-0000000006a1'),
  ('00000000-0000-0000-0000-0000000006e2', '00000000-0000-0000-0000-0000000006d1', '00000000-0000-0000-0000-0000000006c1', now() - interval '30 days',  '00000000-0000-0000-0000-0000000006a1'),
  ('00000000-0000-0000-0000-0000000006e3', '00000000-0000-0000-0000-0000000006d1', '00000000-0000-0000-0000-0000000006c1', now() + interval '5 days',   '00000000-0000-0000-0000-0000000006a1');
INSERT INTO public.pending_payments (id, assigned_chiva_id, owner_id, numero_comprobante, comprobante_path, comprobante_url, estado, agency_name, boletos_vendidos, monto_owner, monto_agencia) VALUES
  ('00000000-0000-0000-0000-0000000006f1', '00000000-0000-0000-0000-0000000006e1', '00000000-0000-0000-0000-0000000006a1', 'TRX-V', 'comprobantes/pg-vieja.png',  'comprobantes/pg-vieja.png',  'verificado', 'x', 1, 10, 0),
  ('00000000-0000-0000-0000-0000000006f2', '00000000-0000-0000-0000-0000000006e2', '00000000-0000-0000-0000-0000000006a1', 'TRX-R', 'comprobantes/pg-reciente.png', 'comprobantes/pg-reciente.png', 'verificado', 'x', 1, 10, 0),
  ('00000000-0000-0000-0000-0000000006f3', '00000000-0000-0000-0000-0000000006e3', '00000000-0000-0000-0000-0000000006a1', 'TRX-F', 'comprobantes/pg-futura.png', 'comprobantes/pg-futura.png', 'pendiente', 'x', 1, 10, 0);

INSERT INTO public.businesses (id, owner_id, name, category)
VALUES ('00000000-0000-0000-0000-0000000006b1', '00000000-0000-0000-0000-0000000006a2', 'Negocio PG', 'otro');
INSERT INTO public.business_events (id, business_id, owner_id, title, event_date, price, capacity) VALUES
  ('00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-0000000006b1', '00000000-0000-0000-0000-0000000006a2', 'Evento viejo', now() - interval '95 days', 5, 10);
INSERT INTO public.business_tickets (id, event_id, business_id, owner_id, customer_name, customer_email, customer_cedula, customer_phone, quantity, unit_price, total_price, payment_status, payment_number, payment_proof_path, qr_payload)
VALUES ('00000000-0000-0000-0000-000000000611', '00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-0000000006b1', '00000000-0000-0000-0000-0000000006a2',
        'Ana', 'ana-pg@test.local', '1', '0999', 1, 5, 5, 'verificado', 'TRX-N', 'comprobantes/pg-negocio.png', 'qr-pg-1');
SET LOCAL session_replication_role = origin;

SELECT is((SELECT count(*) FROM public.proofs_to_purge() WHERE path LIKE 'comprobantes/pg-%'), 2::bigint,
  'Solo entran los comprobantes con más de 90 días desde la salida o el evento');
SELECT ok(EXISTS (SELECT 1 FROM public.proofs_to_purge() WHERE path = 'comprobantes/pg-vieja.png' AND kind = 'tour'),
  'El de la salida de hace 100 días se borra');
SELECT ok(EXISTS (SELECT 1 FROM public.proofs_to_purge() WHERE path = 'comprobantes/pg-negocio.png' AND kind = 'negocio'),
  'El del evento de hace 95 días se borra');
SELECT ok(NOT EXISTS (SELECT 1 FROM public.proofs_to_purge() WHERE path IN ('comprobantes/pg-reciente.png', 'comprobantes/pg-futura.png')),
  'Los de salidas recientes o futuras se conservan');

UPDATE public.app_settings SET value = '20' WHERE key = 'proof_retention_days';
SELECT ok(EXISTS (SELECT 1 FROM public.proofs_to_purge() WHERE path = 'comprobantes/pg-reciente.png'),
  'El plazo sale de app_settings');
UPDATE public.app_settings SET value = '90' WHERE key = 'proof_retention_days';

SELECT is(public.mark_proofs_purged(ARRAY['comprobantes/pg-vieja.png', 'comprobantes/pg-negocio.png']), 2,
  'mark_proofs_purged marca la reserva y la entrada');
SELECT is((SELECT count(*) FROM public.proofs_to_purge() WHERE path LIKE 'comprobantes/pg-%'), 0::bigint,
  'Lo ya borrado no vuelve a aparecer');

SELECT ok(NOT has_function_privilege('anon', 'public.proofs_to_purge(int)', 'execute')
      AND NOT has_function_privilege('authenticated', 'public.mark_proofs_purged(text[])', 'execute'),
  'Solo el servidor puede listar y marcar comprobantes');
SELECT is((SELECT count(*) FROM cron.job WHERE jobname = 'chivapass_purge_proofs'), 1::bigint,
  'La tarea diaria queda programada');

SELECT * FROM finish();
ROLLBACK;
