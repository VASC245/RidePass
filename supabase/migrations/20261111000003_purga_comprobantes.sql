-- ================================================================
-- Borrado de comprobantes a los 90 días (11 nov 2026)
--
-- La política de privacidad promete: "Comprobantes de pago: 90 días después
-- de la fecha de la salida o del evento. Luego se borran." Hasta hoy no se
-- borraba nada.
--
-- Storage no deja borrar archivos con DELETE sobre storage.objects (trigger
-- protect_objects_delete): hay que usar su API. Por eso:
--   1. proofs_to_purge() lista lo que toca borrar (solo service_role).
--   2. La edge function purge-proofs borra los archivos con la API de
--      Storage y llama a mark_proofs_purged() para dejar constancia.
--   3. pg_cron + pg_net llaman a la función una vez al día.
--
-- Qué se borra:
--   - tour:    comprobante de pending_payments cuya salida fue hace más de
--              proof_retention_days (90).
--   - negocio: comprobante de business_tickets cuyo evento fue hace más de
--              proof_retention_days.
--   - suelto:  archivo del bucket que ninguna reserva usa, subido hace más de
--              orphan_proof_grace_days (2): subidas de reservas que fallaron.
-- La venta, el número de comprobante y los montos se conservan: solo se
-- borra la imagen.
-- ================================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

ALTER TABLE public.pending_payments ADD COLUMN IF NOT EXISTS comprobante_purged_at timestamptz;
ALTER TABLE public.business_tickets ADD COLUMN IF NOT EXISTS payment_proof_purged_at timestamptz;

INSERT INTO public.app_settings (key, value, description) VALUES
  ('proof_retention_days', '90',
   'Días después de la salida o del evento en que se borra la imagen del comprobante (política de privacidad).'),
  ('orphan_proof_grace_days', '2',
   'Días tras los que se borra un comprobante subido que ninguna reserva usa.'),
  ('functions_base_url', 'https://cyyzudhjpifpbpeiebsn.supabase.co/functions/v1',
   'URL base de las edge functions; la usa la tarea diaria de borrado de comprobantes.')
ON CONFLICT (key) DO NOTHING;

-- Lista lo que toca borrar. La parte de archivos sueltos solo corre donde
-- existe storage.objects (no en el Postgres local del CI).
CREATE OR REPLACE FUNCTION public.proofs_to_purge(p_limit int DEFAULT 500)
RETURNS TABLE (path text, kind text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_keep  interval := make_interval(days => public.setting_int('proof_retention_days', 90));
  v_grace interval := make_interval(days => public.setting_int('orphan_proof_grace_days', 2));
  v_objects regclass := to_regclass('storage.objects');
BEGIN
  RETURN QUERY
  SELECT p.comprobante_path, 'tour'::text
    FROM public.pending_payments p
    JOIN public.assigned_chivas ac ON ac.id = p.assigned_chiva_id
   WHERE p.comprobante_purged_at IS NULL
     AND p.comprobante_path LIKE 'comprobantes/%'
     AND ac.departure_at < now() - v_keep
  UNION ALL
  SELECT t.payment_proof_path, 'negocio'::text
    FROM public.business_tickets t
    JOIN public.business_events e ON e.id = t.event_id
   WHERE t.payment_proof_purged_at IS NULL
     AND t.payment_proof_path LIKE 'comprobantes/%'
     AND e.event_date < now() - v_keep
  LIMIT p_limit;

  -- La tabla va en una variable: en el Postgres local del CI no existe y el
  -- linter fallaría al analizar la consulta.
  IF v_objects IS NOT NULL THEN
    RETURN QUERY EXECUTE format($q$
      SELECT o.name, 'suelto'::text
        FROM %s o
       WHERE o.bucket_id = 'comprobantes'
         AND o.created_at < now() - $1
         AND NOT EXISTS (SELECT 1 FROM public.pending_payments p WHERE p.comprobante_path = o.name)
         AND NOT EXISTS (SELECT 1 FROM public.business_tickets t WHERE t.payment_proof_path = o.name)
       LIMIT $2
    $q$, v_objects) USING v_grace, p_limit;
  END IF;
END;
$$;

-- Deja constancia en las reservas de que su comprobante ya no existe.
CREATE OR REPLACE FUNCTION public.mark_proofs_purged(p_paths text[])
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_pp int; v_bt int;
BEGIN
  UPDATE public.pending_payments SET comprobante_purged_at = now()
   WHERE comprobante_path = ANY(p_paths) AND comprobante_purged_at IS NULL;
  GET DIAGNOSTICS v_pp = ROW_COUNT;
  UPDATE public.business_tickets SET payment_proof_purged_at = now()
   WHERE payment_proof_path = ANY(p_paths) AND payment_proof_purged_at IS NULL;
  GET DIAGNOSTICS v_bt = ROW_COUNT;
  RETURN v_pp + v_bt;
END;
$$;

REVOKE ALL ON FUNCTION public.proofs_to_purge(int)      FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_proofs_purged(text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.proofs_to_purge(int)      TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_proofs_purged(text[]) TO service_role;

-- Tarea diaria a las 04:41 UTC (23:41 en Ecuador).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'chivapass_purge_proofs') THEN
    PERFORM cron.unschedule('chivapass_purge_proofs');
  END IF;
  PERFORM cron.schedule('chivapass_purge_proofs', '41 4 * * *', $job$
    SELECT net.http_post(
      url     := (SELECT value FROM public.app_settings WHERE key = 'functions_base_url') || '/purge-proofs',
      body    := '{}'::jsonb,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      timeout_milliseconds := 60000
    );
  $job$);
END $$;
