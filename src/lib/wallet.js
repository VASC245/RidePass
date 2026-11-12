// Botones "Agregar a Apple Wallet" y "Agregar a la Billetera de Google" del
// ticket. El pase lo arma la edge function wallet-pass con el mismo QR.

const BASE = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/wallet-pass`

const enabled = {
  apple: import.meta.env.VITE_WALLET_APPLE === "true",
  google: import.meta.env.VITE_WALLET_GOOGLE === "true",
}

// Insignias oficiales, sin modificar (las guías de Apple y Google no
// permiten botones propios ni cambiar texto, color o forma).
//   Google: add-to-wallet-svg.zip de developers.google.com/wallet, versión
//           es419 (español de Latinoamérica), variante "add-wallet-badge".
//   Apple:  "Download badge files" en developer.apple.com/wallet/
//           add-to-apple-wallet-guidelines (pide aceptar la licencia de
//           Apple con la cuenta de desarrollador), versión en español,
//           guardarla como public/img/wallet/apple-wallet-es.svg ANTES de
//           encender VITE_WALLET_APPLE.
export const WALLET_BADGES = {
  apple: { badge: "/img/wallet/apple-wallet-es.svg", label: "Agregar a Apple Wallet" },
  google: { badge: "/img/wallet/google-wallet-es419.svg", label: "Agregar a la Billetera de Google" },
}

export const walletUrl = (ticketId, platform) =>
  `${BASE}?id=${encodeURIComponent(ticketId)}&p=${platform}`

export function isIos(ua = navigator.userAgent, touch = navigator.maxTouchPoints ?? 0) {
  return /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && touch > 1)
}

// iPhone/iPad → solo Apple; Android → solo Google; computadora → ambos
// (desde la Mac, Safari lo guarda en la Wallet del iPhone; Google lo guarda
// en la cuenta y aparece en el teléfono).
export function walletPlatforms(ua = navigator.userAgent, touch = navigator.maxTouchPoints ?? 0) {
  const android = /Android/.test(ua)
  const list = isIos(ua, touch) ? ["apple"] : android ? ["google"] : ["apple", "google"]
  return list.filter((p) => enabled[p])
}
