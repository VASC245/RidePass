// ✅ FILE: supabase/functions/send-ticket/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const RESEND_API_KEY = "re_G4Gfr1Kj_HqFJBTosKbtetbvorLYULgjZ"; // Usa tu clave

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    const { to, name, qr, tour, departure, seats } = await req.json();

    const html = `
      <div style="font-family: sans-serif;">
        <h2>🎫 Ticket de Tour - ${tour}</h2>
        <p>Hola <strong>${name}</strong>,</p>
        <p>Gracias por tu compra. Aquí está tu código QR para abordar:</p>
        <img src="${qr}" alt="QR" style="width:200px; margin: 20px 0;" />
        <p><strong>Asientos:</strong> ${seats.join(", ")}</p>
        <p><strong>Salida:</strong> ${new Date(departure).toLocaleString("es-EC")}</p>
        <hr />
        <p>ChivaPass · Baños de Agua Santa</p>
      </div>
    `;

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "ChivaPass <noreply@smartchiva.com>", // ✅ dominio verificado
        to,
        subject: `Tu Ticket - ${tour}`,
        html,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      return new Response(JSON.stringify({ error: data }), {
        status: 500,
        headers: { "Access-Control-Allow-Origin": "*" },
      });
    }

    return new Response(JSON.stringify({ message: "Correo enviado" }), {
      status: 200,
      headers: { "Access-Control-Allow-Origin": "*" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Access-Control-Allow-Origin": "*" },
    });
  }
});

