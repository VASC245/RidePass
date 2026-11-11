// Borra las imágenes de comprobantes que ya cumplieron su plazo (política de
// privacidad: 90 días después de la salida o del evento) y los archivos
// subidos que ninguna reserva usa. La llama pg_cron una vez al día.
//
// No exige JWT (la llama pg_cron sin credenciales): solo puede borrar lo que
// la base de datos ya marcó como vencido en proofs_to_purge(), así que
// llamarla de más no borra nada que no tocara borrar. Además tiene un
// límite global de 3 ejecuciones por hora.
//
// Entrada opcional: { dryRun: true } → solo cuenta, no borra.
// Respuesta: { success, dryRun, found: { tour, negocio, suelto }, removed, marked }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const BUCKET = "comprobantes"
const BATCH = 100

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })

serve(async (req) => {
  if (req.method !== "POST") return json({ success: false, message: "Método no permitido." }, 405)

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  try {
    const body = await req.json().catch(() => ({}))
    const dryRun = body?.dryRun === true

    const { data: allowed } = await supabase.rpc("check_rate_limit", {
      p_key: "purge-proofs:global", p_limit: 3, p_window_seconds: 3600,
    })
    if (allowed === false) return json({ success: false, message: "Ya se ejecutó hace poco." }, 429)

    const { data: rows, error } = await supabase.rpc("proofs_to_purge", { p_limit: 500 })
    if (error) {
      console.error("[purge-proofs] proofs_to_purge:", error.message)
      return json({ success: false, message: "No se pudo obtener la lista." }, 500)
    }

    const list = (rows ?? []) as { path: string; kind: string }[]
    const found = { tour: 0, negocio: 0, suelto: 0 } as Record<string, number>
    for (const r of list) found[r.kind] = (found[r.kind] ?? 0) + 1
    if (dryRun || list.length === 0) {
      return json({ success: true, dryRun, found, removed: 0, marked: 0 })
    }

    // Los nombres en el bucket incluyen la carpeta "comprobantes/", igual que
    // la ruta guardada en la reserva.
    const paths = [...new Set(list.map((r) => r.path))]
    let removed = 0
    const done: string[] = []
    for (let i = 0; i < paths.length; i += BATCH) {
      const chunk = paths.slice(i, i + BATCH)
      const { data, error: rmErr } = await supabase.storage.from(BUCKET).remove(chunk)
      if (rmErr) {
        console.error("[purge-proofs] remove:", rmErr.message)
        continue // este lote se reintenta mañana
      }
      removed += data?.length ?? 0
      // Un archivo que ya no existía también cuenta como borrado.
      done.push(...chunk)
    }

    const { data: marked, error: mkErr } = await supabase.rpc("mark_proofs_purged", { p_paths: done })
    if (mkErr) console.error("[purge-proofs] mark_proofs_purged:", mkErr.message)

    console.log(`[purge-proofs] encontrados ${JSON.stringify(found)}, borrados ${removed}, marcados ${marked ?? 0}`)
    return json({ success: true, dryRun: false, found, removed, marked: marked ?? 0 })
  } catch (err) {
    console.error("[purge-proofs]", (err as Error).message)
    return json({ success: false, message: "Error interno." }, 500)
  }
})
