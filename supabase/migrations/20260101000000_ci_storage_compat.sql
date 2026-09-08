-- Sin efecto. Se conserva porque la versión ya figura en el historial remoto.
-- Las sentencias de storage de las demás migraciones están protegidas con un
-- DO que comprueba que el esquema storage tenga las columnas de storage-api;
-- en el Postgres local del CI (sin storage-api) simplemente se omiten.
SELECT 1;
