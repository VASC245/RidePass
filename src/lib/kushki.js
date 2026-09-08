// Tokenización de tarjetas con Kushki (la tarjeta viaja directo a Kushki,
// nunca a nuestro servidor). El cobro real lo hace la edge function
// `kushki-charge` con la llave privada y el monto calculado en el servidor.
//
// Config (.env.local):
//   VITE_KUSHKI_PUBLIC_KEY = llave pública del comercio (sandbox o producción)
//   VITE_KUSHKI_ENV        = 'uat' (sandbox, por defecto) | 'production'

const PUBLIC_KEY = import.meta.env.VITE_KUSHKI_PUBLIC_KEY
const ENV        = import.meta.env.VITE_KUSHKI_ENV || 'uat'

const BASE = ENV === 'production'
  ? 'https://api.kushkipagos.com'
  : 'https://api-uat.kushkipagos.com'

// Ignora el placeholder del .env de ejemplo
const isPlaceholder = !PUBLIC_KEY || /aqui|xxxx|ejemplo/i.test(PUBLIC_KEY)

export const kushkiEnabled = !isPlaceholder

export async function tokenizeCard({ name, number, expiry, cvv, amount }) {
  if (!PUBLIC_KEY) throw new Error('Pago con tarjeta no configurado todavía.')

  const [expiryMonth, expiryYear] = String(expiry).split('/').map(s => s.trim())
  if (!expiryMonth || !expiryYear) throw new Error('Fecha de vencimiento inválida (usa MM/AA).')

  const res = await fetch(`${BASE}/card/v1/tokens`, {
    method: 'POST',
    headers: {
      'Public-Merchant-Id': PUBLIC_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      card: {
        name,
        number: String(number).replace(/\s+/g, ''),
        expiryMonth,
        expiryYear,
        cvv,
      },
      totalAmount: Number(amount),
      currency: 'USD',
    }),
  })

  const data = await res.json().catch(() => ({}))
  if (!res.ok || !data.token) {
    throw new Error(data.message || 'No se pudo validar la tarjeta. Revisa los datos.')
  }
  return data.token
}
