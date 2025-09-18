// supabase/functions/tourManager/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")! // 👈 service role key
);

serve(async (req: Request) => {
  try {
    // 1. Actualizar estado de los tours
    const now = new Date().toISOString();

    // 🔹 Marcar como "en_curso"
    await supabase
      .from("assigned_chivas")
      .update({ status: "en_curso" })
      .lte("departure_at", now)
      .gte(
        "departure_at",
        new Date(Date.now() - 1000 * 60 * 60).toISOString() // tours que arrancaron hace < duración
      )
      .neq("status", "en_curso");

    // 🔹 Marcar como "finalizado"
    await supabase
      .from("assigned_chivas")
      .update({ status: "finalizado" })
      .lt("departure_at", new Date(Date.now() - 1000 * 60 * 60).toISOString()) // > duración
      .neq("status", "finalizado");

    // 2. Revisar si hay nuevos boletos vendidos (seats con status "pagado")
    const { data: soldSeats } = await supabase
      .from("seats")
      .select("id, seat_number, assigned_chiva_id")
      .eq("status", "pagado")
      .is("notified", null); // 👈 para no enviar duplicados (añade campo `notified` en seats)

    if (soldSeats && soldSeats.length > 0) {
      for (const seat of soldSeats) {
        // obtener info del tour y dueño
        const { data: tourData } = await supabase
          .from("assigned_chivas")
          .select("tours(title), chivas(name, user_id), departure_at")
          .eq("id", seat.assigned_chiva_id)
          .single();

        if (!tourData) continue;

        // obtener correo del dueño
        const { data: owner } = await supabase
          .from("profiles")
          .select("email, full_name")
          .eq("id", tourData.chivas.user_id)
          .single();

        if (!owner) continue;

        // 🔹 Enviar correo con EmailJS API
        await fetch("https://api.emailjs.com/api/v1.0/email/send", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            service_id: Deno.env.get("EMAILJS_SERVICE_ID"),
            template_id: Deno.env.get("EMAILJS_TEMPLATE_ID"),
            user_id: Deno.env.get("EMAILJS_USER_ID"),
            template_params: {
              to_name: owner.full_name,
              to_email: owner.email,
              tour_title: tourData.tours.title,
              chiva_name: tourData.chivas.name,
              departure_time: new Date(tourData.departure_at).toLocaleString(),
              seat_number: seat.seat_number,
            },
          }),
        });

        // marcar el asiento como notificado
        await supabase.from("seats").update({ notified: true }).eq("id", seat.id);
      }
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
