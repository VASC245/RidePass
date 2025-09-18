// src/lib/email.js
export async function sendTicketByEmail({ to, name, qr, tour, departure, seats }) {
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
      Authorization: "Bearer TU_API_KEY_RESEND_AQUÍ",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "ChivaPass <noreply@chivapass.com>",
      to,
      subject: `🎫 Tu Ticket - ${tour}`,
      html,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(data.message || "Error al enviar el correo");
  }

  return data;
}
