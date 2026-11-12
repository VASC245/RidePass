// Botones "Agregar a Apple Wallet" y "Guardar en Google Wallet" del ticket.
// El pase lo arma la edge function wallet-pass con el mismo QR del ticket.

const BASE = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/wallet-pass`

const enabled = {
  apple: import.meta.env.VITE_WALLET_APPLE === "true",
  google: import.meta.env.VITE_WALLET_GOOGLE === "true",
}

export const walletUrl = (ticketId, platform) =>
  `${BASE}?id=${encodeURIComponent(ticketId)}&p=${platform}`

// iPhone/iPad → solo Apple; Android → solo Google; computadora → ambos
// (desde la Mac, Safari lo guarda en la Wallet del iPhone; Google lo guarda
// en la cuenta y aparece en el teléfono).
export function walletPlatforms(ua = navigator.userAgent, touch = navigator.maxTouchPoints ?? 0) {
  const ios = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && touch > 1)
  const android = /Android/.test(ua)
  const list = ios ? ["apple"] : android ? ["google"] : ["apple", "google"]
  return list.filter((p) => enabled[p])
}
