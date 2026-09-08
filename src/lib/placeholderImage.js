// Foto local de respaldo para tours/atracciones sin imagen propia.
// Determinística por id para que cada tarjeta conserve siempre la misma foto.
const TOTAL = 6

export function placeholderFor(id) {
  const s = String(id ?? '')
  let hash = 0
  for (let i = 0; i < s.length; i++) hash = (hash * 31 + s.charCodeAt(i)) >>> 0
  return `/img/placeholders/fallback-${(hash % TOTAL) + 1}.jpg`
}
