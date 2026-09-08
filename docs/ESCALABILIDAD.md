# ChivaPass a 100.000 clientes

Qué hace falta para atender 100.000 clientes sin rehacer la arquitectura.
Supuestos: 100.000 compradores registrados al año, unas 300 compras diarias
en promedio, picos de feriado de 3.000 compras al día y 300 personas
comprando a la vez. Si el objetivo fuera 100.000 usuarios *simultáneos*, el
plan cambia y hay que hablarlo aparte.

## Dónde estamos

| Componente | Hoy | Límite práctico |
| --- | --- | --- |
| Base de datos | Supabase plan Free, hiberna tras una semana sin uso | 500 MB, 60 conexiones, se apaga solo |
| Edge functions | 2 funciones, cold start ~300 ms | 500.000 invocaciones/mes en Free |
| Frontend | Netlify, chunks por ruta, assets con caché de un año | CDN global, sin límite práctico |
| Correo | Resend | 3.000/mes en Free |
| WhatsApp | Twilio | por mensaje |
| Pagos | Kushki | por transacción |

La base de datos tiene hoy menos de diez filas de negocio. Con 100.000
clientes y una compra por persona al año, `sales_simple` y
`business_tickets` suman unas 100.000 filas por año y `seats` unas 4
millones (40 asientos por salida). Todo eso cabe en menos de 2 GB y
Postgres lo consulta en milisegundos si los índices están bien.

## Lo que ya quedó hecho en el código

- **Reservas atómicas en SQL.** `reserve_tour_seats` bloquea la fila de la
  salida con `FOR UPDATE`, así que dos compradores del mismo asiento se
  serializan en la base de datos y nunca hay doble venta. El bloqueo dura
  milisegundos y es por salida, no global: mil salidas distintas se
  reservan en paralelo.
- **Expiración automática.** `expire_pending_reservations` corre cada
  cinco minutos y libera asientos de reservas abandonadas. Sin esto el
  inventario se agota con reservas fantasma en cuanto hay tráfico.
- **Índices compuestos** para las consultas de listado, disponibilidad y
  paneles (`20260907000001_expiry_and_scale.sql`).
- **Rate limiting por IP** en las funciones de reserva y cobro. Frena bots
  y pruebas de tarjetas robadas sin afectar a usuarios normales.
- **Idempotencia de cobros** por token de Kushki.
- **Listado público acotado**: solo próximas salidas activas, máximo 200,
  con caché de 60 segundos en el navegador.
- **Caché de assets** un año en CDN; el HTML nunca se cachea.

## Lo que hay que contratar o configurar

1. **Supabase Pro** (25 USD/mes). Quita la hibernación, sube a 8 GB de
   base de datos, 100 GB de storage, backups diarios de 7 días y soporte.
   Es la única compra imprescindible: en Free el proyecto se apaga solo y
   los primeros compradores del día verían errores.
2. **Compute add-on Small** (unos 15 USD/mes) cuando pasen de 50 compras
   por hora sostenidas. El Micro que trae Pro aguanta el arranque.
3. **Resend Pro** (20 USD/mes, 50.000 correos) al superar 3.000 tickets
   mensuales. Verificar el dominio `smartchiva.com` con SPF, DKIM y DMARC
   para que los tickets no caigan en spam.
4. **Kushki**: negociar tarifa por volumen y activar el webhook de
   confirmación (pendiente de implementar del lado nuestro).
5. **Netlify**: el plan Free basta. Si el tráfico supera 100 GB al mes,
   pasar a Pro (19 USD).
6. **Dominio y correo transaccional** separados del correo personal.

Costo mensual estimado en régimen: entre 60 y 100 USD, sin contar
comisiones de Kushki y Twilio.

## Lo que falta construir, en orden

1. **Webhook de Kushki** para conciliar cobros aprobados que quedaron en
   `needs_review`. A escala, un 0,1 % de fallos de red son varios clientes
   por semana esperando su ticket.
2. **Cola de notificaciones.** Hoy el correo y el WhatsApp se envían dentro
   de la petición de reserva. Si Resend tarda tres segundos, el comprador
   espera tres segundos. Mover los envíos a `pgmq` (extensión ya
   disponible) con un worker cada minuto quita esa latencia y permite
   reintentos.
3. **Un QR por asiento** o abordaje parcial, para grupos que llegan por
   separado.
4. **Vista de disponibilidad** precalculada por salida (`asientos libres`)
   para que las tarjetas de la landing no consulten `seats`. Basta un
   trigger que mantenga un contador en `assigned_chivas`.
5. **Particionar `seats` y `sales_simple` por año** con `pg_partman`
   cuando pasen de 10 millones de filas. No antes.
6. **Observabilidad**: activar `pg_stat_statements` en el dashboard (ya
   instalado), alertas de Supabase por CPU y conexiones, y un panel de
   Netlify Analytics. Revisar el reporte de advisors de Supabase cada
   mes.
7. **Backups probados**: una vez al trimestre restaurar un backup en una
   rama y correr las pruebas pgTAP contra él.

## Qué NO hace falta

- Microservicios, Kubernetes ni otra base de datos. Un Postgres bien
  indexado atiende este volumen con un solo nodo.
- Redis para caché. La consulta pública ya es una lectura por índice y el
  navegador la cachea. Si algún día hace falta, PostgREST soporta
  `Cache-Control` por vista.
- Un servidor propio. Las edge functions escalan solas y el frontend es
  estático.

## Cómo saber que vamos bien

Revisar mensualmente en el dashboard de Supabase:

| Métrica | Sano | Actuar si |
| --- | --- | --- |
| CPU de la base de datos | menos de 40 % | más de 70 % sostenido |
| Conexiones activas | menos de 30 | más de 50 |
| Latencia p95 de `public-reserve` | menos de 800 ms | más de 2 s |
| Reservas expiradas por día | menos de 10 % de las creadas | más de 25 % (algo falla en el pago) |
| Sesiones `needs_review` | 0 | cualquiera: conciliar el mismo día |
