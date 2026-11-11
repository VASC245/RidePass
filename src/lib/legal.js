// Datos del responsable que aparecen en Términos, Privacidad y Créditos.
// Se configuran con variables de entorno en el build (.env.production):
//   VITE_LEGAL_OWNER  nombre o razón social del titular de chivaspass
//   VITE_LEGAL_RUC    RUC del titular (si queda vacío, las páginas omiten la línea)
//   VITE_LEGAL_EMAIL  correo para reclamos y derechos sobre datos personales
// Si cambia el texto legal, actualiza también `updated`.
const env = import.meta.env

export const LEGAL = {
  owner: env.VITE_LEGAL_OWNER || 'chivaspass',
  ruc: env.VITE_LEGAL_RUC || '',
  email: env.VITE_LEGAL_EMAIL || 'chivaspass@gmail.com',
  city: 'Baños de Agua Santa, Tungurahua, Ecuador',
  updated: '26 de octubre de 2026',
}
