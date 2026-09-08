// DESACTIVADA. Esta función era un relay abierto de correo (cualquiera podía
// invocarla) y tenía la clave de Resend escrita en el código.
// El envío de tickets ahora lo hacen public-reserve y kushki-charge
// internamente (ver _shared/notify.ts).
//
// Desplegar esta versión deja el endpoint respondiendo 410 hasta que se
// elimine del proyecto con:  npx supabase functions delete send-ticket
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

serve(() =>
  new Response(JSON.stringify({ error: "Endpoint retirado." }), {
    status: 410,
    headers: { "Content-Type": "application/json" },
  }))
