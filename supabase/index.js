import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { qrcode } from "qrcode";
import Resend from "resend";

type Payload = {
  ticket_id: string;
  to_email: string;
  to_name?: string;
  app_name?: string;
  qr_value: string;
};

const resend = new Resend.Deno({
  apiKey: Deno.env.get("RESEND_API_KEY")!,
});

const FROM = Deno.env.get("FROM_EMAIL") || "tickets@example.com";
const APP_URL = Deno.env.get("APP_PUBLIC_URL") || "https://example.com";

serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  try {
    const body: Payload = await req.json();
    const pngDataUrl = await qrcode(body.qr_value, { size: 300 });

    const html = `
      <div style="font-family: sans-serif;">
        <h2>${body.app_name || 'ChivaPass'} - Tu Boleto</h2>
        <p>Hola ${body.to_name || 'pasajero'},</p>
        <p>Gracias por tu compra. Escanea este código QR al abordar:</p>
        <img src="${pngDataUrl}" alt="QR Ticket" style="width:200px; height:200px;" />
        <p>Si no puedes ver el QR, accede a <a href="${APP_URL}">${APP_URL}</a></p>
        <p style="font-size:12px; color:#666;">Ticket ID: ${body.ticket_id}</p>
      </div>
    `;

    const { data, error } = await resend.emails.send({
      from: `ChivaPass <${FROM}>`,
      to: [body.to_email],
      subject: "Tu boleto con QR",
      html
    });

    if (error) return new Response(JSON.stringify({ ok: false, error }), { status: 500 });
    return new Response(JSON.stringify({ ok: true, data }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: e?.message }), { status: 400 });
  }
});
