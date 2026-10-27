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

## 3. Secrets de las funciones (act. 26 oct 2026)

Se cargan en Supabase → Edge Functions → Secrets, o con la CLI:

| Secret | Para qué | Obligatorio |
| --- | --- | --- |
| `BREVO_API_KEY` | Correos de tickets, contacto y SMS al vendedor | Sí |
| `BREVO_SENDER_EMAIL` | Remitente verificado en Brevo | Sí |
| `BREVO_SENDER_NAME` | Nombre del remitente (por defecto `chivaspass`) | No |
| `BREVO_SMS_SENDER` | Remitente de SMS, máx. 11 caracteres | No |
| `CONTACT_EMAIL` | Buzón que recibe el formulario de contacto (por defecto el remitente) | No |
| `PUBLIC_APP_URL` | URL del sitio para los enlaces de los tickets | Sí |
| `ALLOWED_ORIGINS` | Orígenes del sitio separados por coma (CORS) | Sí |
| `TURNSTILE_SECRET_KEY` | Captcha de Cloudflare en reservas y contacto | Recomendado |
| `KUSHKI_PRIVATE_KEY`, `KUSHKI_ENV` | Pago con tarjeta (`uat` o `production`) | Para tarjeta |

Si falta `BREVO_*` las ventas funcionan pero no sale ningún correo. Sin
`PUBLIC_APP_URL` el enlace del ticket solo se arma si el origen de la
petición está en la lista permitida. Sin `TURNSTILE_SECRET_KEY` no se pide
captcha (el sitio tampoco lo muestra sin `VITE_TURNSTILE_SITE_KEY`).

`SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY` los inyecta
Supabase automáticamente.

Variables públicas del sitio (en `.env.production`, van dentro del bundle):
`VITE_TURNSTILE_SITE_KEY`, `VITE_PLANS_BANK_*`, `VITE_PLANS_WHATSAPP`,
`VITE_LEGAL_OWNER`, `VITE_LEGAL_RUC`, `VITE_LEGAL_EMAIL`, `VITE_KUSHKI_PUBLIC_KEY`.

### Captcha (Cloudflare Turnstile)

1. Cloudflare → Turnstile → Add widget. Hostnames: `chivaspass.valentinsil13.workers.dev`
   y `chivaspass.com`. Modo: Managed.
2. La *site key* va en `.env.production` como `VITE_TURNSTILE_SITE_KEY`.
3. La *secret key* va como secret `TURNSTILE_SECRET_KEY` en Supabase.
4. `npm run deploy`.

### Confirmación de correo en el registro

Authentication → Sign In / Providers → Email → **Confirm email** activado.
El servidor de correo por defecto de Supabase solo envía a miembros del
equipo, así que hay que configurar SMTP propio con Brevo en
Authentication → Emails → SMTP Settings (`smtp-relay.brevo.com`, puerto 587,
usuario y clave SMTP de Brevo).

## 4. Desplegar funciones

```sh
npx supabase functions deploy public-reserve --use-api
npx supabase functions deploy kushki-charge --use-api
npx supabase functions deploy contact --use-api
npx supabase functions delete send-ticket
npx supabase functions delete send-whatsapp
```

## 5. Códigos de invitación

Dueños, agencias y negocios se registran con un código de su rol (sin
código válido la cuenta queda como cliente). En el SQL Editor:

```sql
select public.create_invite_code('dueño');    -- DUENO-XXXXXXXXXX
select public.create_invite_code('agencia');  -- AGENCIA-XXXXXXXXXX
select public.create_invite_code('negocio');  -- NEGOCIO-XXXXXXXXXX
select code, role, used_by, used_at from public.owner_invite_codes order by used_at nulls first;
```

## 5b. Expiración de reservas (segunda migración)

`expire_pending_reservations()` corre cada 5 minutos con `pg_cron` y libera:

| Caso | Plazo por defecto | Clave en `app_settings` |
| --- | --- | --- |
| Reserva sin comprobante (tarjeta interrumpida) | 15 minutos | `reservation_no_proof_minutes` |
| Reserva con comprobante que nadie verificó | 24 horas | `reservation_unverified_hours` |
| Comprobante sin verificar y la salida está cerca | 60 minutos antes | `reservation_release_before_departure_minutes` |

Con ese mismo margen se dejan de aceptar transferencias nuevas (error
`TRANSFER_CLOSED`); el efectivo del dueño se sigue vendiendo hasta la salida.

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
| EmailJS desde el navegador | correo Brevo desde el servidor tras registrar la venta |
| `panel_settings` legible por anónimos | RPC `get_seller_payment_info(owner)` |
| `business_tickets` verificados listables por anónimos | RPC `get_public_ticket(id)` sin cédula ni teléfono |
| Bucket `comprobantes` público | privado; el vendedor lo abre con URL firmada |
| Subida directa al bucket | URL firmada de `public-reserve` (`type: 'upload-url'`, con captcha para el público) |
