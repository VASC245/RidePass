# Despliegue del endurecimiento de seguridad (sep 2026)

El frontend actual depende de las migraciones `20260907000000_security_hardening.sql`
y `20260907000001_expiry_and_scale.sql`, y de las edge functions reescritas.
Hasta que se apliquen, las ventas fallan porque el navegador llama a RPCs que
todavía no existen en la base de datos.

**Estado (7 sep 2026): las cuatro migraciones YA ESTÁN APLICADAS en producción**
(proyecto `cyyzudhjpifpbpeiebsn`) y registradas en el historial con las
versiones `20260907000000` a `20260907000003`. Se corrieron dos checklists
completos contra producción dentro de transacciones con ROLLBACK: 37
comprobaciones de seguridad y aislamiento entre dueños, y 16 de controles
del dueño; todas pasaron. Falta desplegar las edge functions (paso 4) y
configurar los secrets (paso 3).

**Controles del dueño (migración `20260907000003`):** en la base de datos,
así que ningún cliente los evita.

| Dónde | Control | Efecto |
| --- | --- | --- |
| Mis tours | Tour activo | Inactivo: desaparece del sitio y nadie lo vende, ni el dueño |
| Mis tours | Venta por agencias | Apagado: las agencias no lo ven ni lo venden |
| Salidas | Ventas abiertas/cerradas | Cerrada: invisible al público; el dueño aún vende en efectivo |
| Configuración | Aparecer en la página pública | Apagado: todo el vendedor desaparece del sitio |
| Configuración | Transferencia / Tarjeta / Efectivo | Cada método se puede apagar por separado |
| Configuración | Horario de atención | Con "solo en horario", fuera de hora no se reserva |
| Configuración | Cerrar ventas N minutos antes | Deja de vender cerca de la salida |

Historial de migraciones: el proyecto remoto tiene dos migraciones de julio
(`20260725025438_endurecer_rls_y_bucket_comprobantes`,
`20260725030833_revocar_execute_public_funciones_definer`) que no están en el
repo, y las ocho migraciones iniciales del repo no están marcadas en el
remoto. Antes del primer `supabase db push` hay que reconciliar:

```sh
npx supabase link --project-ref cyyzudhjpifpbpeiebsn
# marcar las 8 iniciales como aplicadas (ya lo están de hecho)
npx supabase migration repair --status applied 20260522000000 20260522000001 20260522000002 20260522000003 20260522000004 20260523000001 20260523000002 20260523000003
# traer las dos de julio al repo
npx supabase migration fetch
npx supabase migration list   # local y remoto deben coincidir
```

## 1. Antes de aplicar

Comprobar que el esquema real coincide con las migraciones del repo. En el
SQL Editor de Supabase:

```sql
select column_name from information_schema.columns
 where table_name = 'drivers' order by 1;
select column_name from information_schema.columns
 where table_name = 'assigned_chivas' order by 1;
select policyname from pg_policies where tablename in ('seats','sales_simple','pending_payments','business_tickets');
```

La migración usa `ADD COLUMN IF NOT EXISTS` y `DROP POLICY IF EXISTS`, así
que es segura de repetir, pero conviene mirar el resultado.

## 2. Aplicar la migración

```sh
npx supabase link --project-ref cyyzudhjpifpbpeiebsn
npx supabase db push
```

O pegar el contenido del archivo en el SQL Editor.

## 3. Secrets de las funciones

```sh
npx supabase secrets set \
  RESEND_API_KEY=re_...            # clave NUEVA (la anterior quedó en el historial de git)
  RESEND_FROM="ChivaPass <noreply@smartchiva.com>" \
  ALLOWED_ORIGINS=https://TU-DOMINIO,http://localhost:5173 \
  PUBLIC_APP_URL=https://TU-DOMINIO \
  KUSHKI_PRIVATE_KEY=... KUSHKI_ENV=uat \
  TWILIO_SID=... TWILIO_TOKEN=... TWILIO_WHATSAPP_FROM=whatsapp:+1...
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta
Supabase automáticamente.

## 4. Desplegar funciones

```sh
npx supabase functions deploy public-reserve
npx supabase functions deploy kushki-charge
npx supabase functions deploy send-ticket      # versión que responde 410
npx supabase functions delete send-ticket      # y luego eliminarla
npx supabase functions delete send-whatsapp
```

## 5. Código de invitación para dueños

Las cuentas de dueño ya no se crean libremente. Insertar un código y
entregarlo al dueño:

```sql
insert into public.owner_invite_codes (code) values ('CODIGO-UNICO-AQUI');
```

## 5b. Expiración de reservas (segunda migración)

`expire_pending_reservations()` corre cada 5 minutos con `pg_cron` y libera:

| Caso | Plazo por defecto | Clave en `app_settings` |
| --- | --- | --- |
| Reserva sin comprobante (tarjeta interrumpida) | 15 minutos | `reservation_no_proof_minutes` |
| Reserva con comprobante que nadie verificó | 24 horas | `reservation_unverified_hours` |
| Comprobante sin verificar y la salida está cerca | 60 minutos antes | `reservation_release_before_departure_minutes` |

Cambiar un plazo sin redeploy:

```sql
update public.app_settings set value = '30' where key = 'reservation_no_proof_minutes';
```

Ver las últimas ejecuciones: `select * from cron.job_run_details order by start_time desc limit 20;`

## 6. Probar

1. Reserva pública de tour con transferencia: debe crear `sales_simple`
   en `pendiente`, `pending_payments` con `sale_id`, asientos `reservado`.
2. Verificar el comprobante desde el panel del dueño: la venta pasa a
   `pagado` y los asientos a `pagado`. Rechazar: `cancelado` y `disponible`.
3. Escanear el QR con el dueño: asientos `abordado`; segundo escaneo avisa
   "ya fue usado".
4. Venta de agencia: comprobante → venta `pendiente` con `agency_id`.
5. Venta del dueño en efectivo: venta `pagado` directa.
6. Evento: la capacidad descuenta los tickets no rechazados; al llenarse el
   evento pasa a `agotado`.
7. Con la anon key, intentar `update seats` o `insert sales_simple` desde
   la consola del navegador: debe devolver error de RLS.

## Qué cambió para el frontend

| Antes | Ahora |
| --- | --- |
| `insert` directo en `sales_simple`, `pending_payments`, `business_tickets` | edge function `public-reserve` |
| `update seats` desde el navegador | RPC `board_sale` (embarque) y `verify_pending_payment` (comprobantes) |
| Escáner confiaba en el JSON del QR | QR solo lleva `sale_id` / `ticket_id`; el servidor valida |
| EmailJS desde el navegador | correo Resend desde el servidor tras registrar la venta |
| `panel_settings` legible por anónimos | RPC `get_seller_payment_info(owner)` |
| `business_tickets` verificados listables por anónimos | RPC `get_public_ticket(id)` sin cédula ni teléfono |
| Bucket `comprobantes` público | privado; el vendedor lo abre con URL firmada |
