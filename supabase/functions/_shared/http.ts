// Utilidades HTTP compartidas por las edge functions.

// Orígenes por defecto si el secret ALLOWED_ORIGINS no está configurado:
// producción, previews de Netlify y el dev server local. Nunca se refleja
// un origen arbitrario.
//   supabase secrets set ALLOWED_ORIGINS=https://tudominio.com,http://localhost:5173
const DEFAULT_ORIGINS = ["https://chivaspass.netlify.app", "http://localhost:5173"]
const PREVIEW_RE = /^https:\/\/[a-z0-9-]+--chivaspass\.netlify\.app$/

const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean)
const ORIGINS = ALLOWED_ORIGINS.length ? ALLOWED_ORIGINS : DEFAULT_ORIGINS

export function originAllowed(origin: string): boolean {
  return ORIGINS.includes(origin) || PREVIEW_RE.test(origin)
}

// Devuelve las cabeceras CORS para la petición.
export function corsFor(req: Request): Record<string, string> {
  const origin = req.headers.get("origin") ?? ""
  const allowed = originAllowed(origin)
  return {
    "Access-Control-Allow-Origin": allowed ? origin : ORIGINS[0],
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
    "Content-Type": "application/json",
  }
}

export const jsonResponse = (cors: Record<string, string>) =>
  (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: cors })

// URL pública de la app para armar links de tickets. Prioridad:
// PUBLIC_APP_URL (secret) → cabecera Origin de la petición.
export function appUrl(req: Request): string {
  const env = Deno.env.get("PUBLIC_APP_URL")
  if (env) return env.replace(/\/$/, "")
  const origin = req.headers.get("origin")
  return origin ? origin.replace(/\/$/, "") : ""
}

// Traduce los códigos que lanzan las funciones SQL a mensajes para el usuario.
export function mapDbError(message: string): { status: number; message: string } {
  const m = message ?? ""
  if (m.includes("SEATS_UNAVAILABLE"))  return { status: 409, message: "Alguno de los asientos ya no está disponible. Elige de nuevo." }
  if (m.includes("CAPACITY_EXCEEDED"))  return { status: 409, message: "No quedan cupos suficientes para este evento." }
  if (m.includes("TOUR_NOT_FOUND"))     return { status: 404, message: "Tour no encontrado." }
  if (m.includes("EVENT_NOT_FOUND"))    return { status: 404, message: "Evento no encontrado." }
  if (m.includes("TOUR_UNAVAILABLE"))   return { status: 400, message: "Este tour ya no está disponible." }
  if (m.includes("TOUR_WITHOUT_PRICE")) return { status: 400, message: "El tour no tiene precio configurado." }
  if (m.includes("EVENT_INACTIVE"))     return { status: 400, message: "Este evento ya no está activo." }
  if (m.includes("EVENT_PAST"))         return { status: 400, message: "Este evento ya pasó." }
  if (m.includes("SALES_CLOSED"))       return { status: 409, message: "Las ventas para esta salida están cerradas por el momento." }
  if (m.includes("OUTSIDE_HOURS"))      return { status: 409, message: "El vendedor no recibe reservas a esta hora. Revisa su horario de atención." }
  if (m.includes("AGENCY_DISABLED"))    return { status: 403, message: "Este tour no admite ventas por agencias." }
  if (m.includes("METHOD_DISABLED"))    return { status: 409, message: "El vendedor no acepta este método de pago." }
  if (m.includes("SEATS_REQUIRED"))     return { status: 400, message: "Selecciona al menos un asiento." }
  if (m.includes("QUANTITY_REQUIRED"))  return { status: 400, message: "Indica cuántas entradas quieres." }
  return { status: 500, message: "No se pudo registrar la reserva." }
}

// IP del cliente detrás del proxy de Supabase.
export function clientIp(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for") ?? ""
  return fwd.split(",")[0].trim() || req.headers.get("cf-connecting-ip") || "unknown"
}

// Límite de peticiones por IP y endpoint usando la función SQL
// check_rate_limit (ventana fija). Si la base de datos falla, no bloquea:
// preferimos degradar el límite antes que tumbar las ventas.
// deno-lint-ignore no-explicit-any
export async function rateLimited(supabase: any, req: Request, bucket: string, limit: number, windowSeconds = 60): Promise<boolean> {
  try {
    const { data, error } = await supabase.rpc("check_rate_limit", {
      p_key: `${bucket}:${clientIp(req)}`,
      p_limit: limit,
      p_window_seconds: windowSeconds,
    })
    if (error) { console.warn("[rate-limit] rpc error:", error.message); return false }
    return data === false
  } catch (e) {
    console.warn("[rate-limit] failed:", (e as Error).message)
    return false
  }
}

export interface Customer {
  name: string
  email: string
  phone?: string
  cedula?: string
  address?: string
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

// Normaliza y valida los datos del comprador. Devuelve null si algo falta.
export function parseCustomer(raw: unknown, requireAddress = false): Customer | null {
  if (!raw || typeof raw !== "object") return null
  const c = raw as Record<string, unknown>
  const str = (v: unknown, max = 120) => String(v ?? "").trim().slice(0, max)
  const customer: Customer = {
    name:    str(c.name),
    email:   str(c.email).toLowerCase(),
    phone:   str(c.phone, 30),
    cedula:  str(c.cedula, 30),
    address: str(c.address, 200),
  }
  if (!customer.name || !EMAIL_RE.test(customer.email)) return null
  if (requireAddress && !customer.address) return null
  return customer
}

export function parseSeats(raw: unknown): number[] | null {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 60) return null
  const seats = raw.map(Number)
  if (seats.some((n) => !Number.isInteger(n) || n < 1 || n > 200)) return null
  return [...new Set(seats)]
}
