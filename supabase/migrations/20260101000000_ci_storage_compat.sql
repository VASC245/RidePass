-- Compatibilidad para el Postgres local del CI, que arranca sin el servicio
-- storage-api y por eso trae el esquema `storage` sin las columnas que ese
-- servicio agrega. En producción todo esto ya existe y no hace nada
-- (la versión está marcada como aplicada en el historial remoto).
DO $$
BEGIN
  IF to_regclass('storage.buckets') IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='storage' AND table_name='buckets' AND column_name='public') THEN
      ALTER TABLE storage.buckets ADD COLUMN public boolean NOT NULL DEFAULT false;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='storage' AND table_name='buckets' AND column_name='file_size_limit') THEN
      ALTER TABLE storage.buckets ADD COLUMN file_size_limit bigint;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='storage' AND table_name='buckets' AND column_name='allowed_mime_types') THEN
      ALTER TABLE storage.buckets ADD COLUMN allowed_mime_types text[];
    END IF;
  END IF;

  IF to_regprocedure('storage.foldername(text)') IS NULL THEN
    CREATE FUNCTION storage.foldername(name text)
    RETURNS text[] LANGUAGE plpgsql AS $f$
    DECLARE parts text[];
    BEGIN
      SELECT string_to_array(name, '/') INTO parts;
      RETURN parts[1:array_length(parts, 1) - 1];
    END;
    $f$;
  END IF;
END;
$$;
