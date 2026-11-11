-- Las políticas RLS deben llamar auth.uid() / my_role() dentro de un
-- (select ...) para que Postgres los evalúe una vez por consulta y no por
-- fila (aviso auth_rls_initplan del linter de Supabase).
BEGIN;
SELECT plan(2);

SELECT is(
  (SELECT count(*) FROM pg_policies
    WHERE schemaname = 'public'
      AND (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ '(?<!SELECT )auth\.(uid|email|jwt|role)\(\)'),
  0::bigint,
  'Ninguna política llama auth.uid() fila por fila');

SELECT is(
  (SELECT count(*) FROM pg_policies
    WHERE schemaname = 'public'
      AND (coalesce(qual, '') || ' ' || coalesce(with_check, '')) ~ '(?<!SELECT )my_role\(\)'),
  0::bigint,
  'Ninguna política llama my_role() fila por fila');

SELECT * FROM finish();
ROLLBACK;
