// Contenido de los pases de Apple Wallet y Google Wallet a partir del ticket
// público (get_public_ticket). Funciones puras: sin red ni secretos, para
// poder probarlas. La firma y el envío viven en pkpass.ts y google_wallet.ts.
//
// El QR del pase lleva exactamente el mismo texto que el QR de la página del
// ticket (qr_payload), así que los escáneres de embarque y de entrada lo
// leen igual.

export interface PublicTicket {
  kind: "tour" | "business"
  id: string
  customer_name: string | null
  quantity: number | null
  seats?: unknown
  subtotal: number | string | null
  fee: number | string | null
  total: number | string | null
  qr_payload: string | null
  used: boolean | null
  title: string | null
  date: string | null
  place: string | null
}

// Colores del ticket web (cabecera bg-gray-900, acento naranja de marca).
export const COLORS = {
  background: "rgb(17,24,39)",
  foreground: "rgb(255,255,255)",
  label: "rgb(247,127,0)",
  hexBackground: "#111827",
}

// Ecuador continental: UTC-5 todo el año, sin horario de verano.
const EC_OFFSET_MIN = -5 * 60

// "2026-09-13T14:00:00+00:00" → "2026-09-13T09:00:00-05:00"
export function toEcuadorIso(value: string | null): string | null {
  if (!value) return null
  const t = Date.parse(value)
  if (Number.isNaN(t)) return null
  const local = new Date(t + EC_OFFSET_MIN * 60_000)
  return local.toISOString().slice(0, 19) + "-05:00"
}

// Texto legible en español con la hora de Ecuador: "sábado, 13 de septiembre, 09:00"
export function ecuadorLabel(value: string | null): string {
  if (!value) return "–"
  const t = Date.parse(value)
  if (Number.isNaN(t)) return "–"
  return new Intl.DateTimeFormat("es-EC", {
    weekday: "long", day: "numeric", month: "long", hour: "2-digit", minute: "2-digit",
    hour12: false, timeZone: "America/Guayaquil",
  }).format(new Date(t))
}

export function seatList(seats: unknown): string {
  let s = seats
  if (typeof s === "string") { try { s = JSON.parse(s) } catch { s = [] } }
  return Array.isArray(s) && s.length ? s.join(", ") : "–"
}

const money = (v: unknown) => `$${Number(v ?? 0).toFixed(2)}`
export const shortId = (id: string) => id.slice(0, 8).toUpperCase()

// Un ticket solo se puede llevar al wallet si está pagado (get_public_ticket
// ya filtra eso) y tiene QR.
export function walletReady(t: PublicTicket | null): t is PublicTicket {
  return Boolean(t && t.id && t.qr_payload)
}

interface Labels {
  what: string; when: string; where: string; count: string; countValue: string; help: string
}

function seatCount(seats: unknown): number {
  let s = seats
  if (typeof s === "string") { try { s = JSON.parse(s) } catch { s = [] } }
  return Array.isArray(s) ? s.length : 0
}

function labelsFor(t: PublicTicket): Labels {
  const tour = t.kind === "tour"
  const one = tour ? seatCount(t.seats) === 1 : Number(t.quantity) === 1
  return {
    what: tour ? "Tour" : "Evento",
    when: tour ? "Salida" : "Fecha",
    where: tour ? "Chiva" : "Lugar",
    count: tour ? (one ? "Asiento" : "Asientos") : (one ? "Entrada" : "Entradas"),
    countValue: tour ? seatList(t.seats) : String(t.quantity ?? "–"),
    help: tour ? "Muestra el código al conductor al abordar." : "Muestra el código al ingresar.",
  }
}

// ---------------------------------------------------------------- Apple

export interface AppleIds { passTypeIdentifier: string; teamIdentifier: string }

// pass.json de un pase tipo eventTicket.
// https://developer.apple.com/documentation/walletpasses/pass
export function applePassJson(t: PublicTicket, ids: AppleIds, ticketUrl: string): Record<string, unknown> {
  const l = labelsFor(t)
  const when = toEcuadorIso(t.date)
  const pass: Record<string, unknown> = {
    formatVersion: 1,
    passTypeIdentifier: ids.passTypeIdentifier,
    teamIdentifier: ids.teamIdentifier,
    serialNumber: t.id,
    organizationName: "chivaspass",
    description: `${l.what}: ${t.title ?? "chivaspass"}`,
    foregroundColor: COLORS.foreground,
    backgroundColor: COLORS.background,
    labelColor: COLORS.label,
    sharingProhibited: true,
    barcodes: [{
      format: "PKBarcodeFormatQR",
      message: t.qr_payload,
      messageEncoding: "iso-8859-1",
      altText: shortId(t.id),
    }],
    eventTicket: {
      headerFields: [
        { key: "count", label: l.count.toUpperCase(), value: l.countValue },
      ],
      primaryFields: [
        { key: "title", label: l.what.toUpperCase(), value: t.title ?? "–" },
      ],
      secondaryFields: [
        when
          ? {
            key: "date", label: l.when.toUpperCase(), value: when,
            dateStyle: "PKDateStyleMedium", timeStyle: "PKDateStyleShort", ignoresTimeZone: true,
          }
          : { key: "date", label: l.when.toUpperCase(), value: "–" },
        { key: "place", label: l.where.toUpperCase(), value: t.place ?? "–", textAlignment: "PKTextAlignmentRight" },
      ],
      auxiliaryFields: [
        { key: "holder", label: "TITULAR", value: t.customer_name ?? "–" },
        { key: "total", label: "TOTAL PAGADO", value: money(t.total), textAlignment: "PKTextAlignmentRight" },
      ],
      backFields: [
        { key: "help", label: "Cómo usarlo", value: `${l.help} Baños de Agua Santa, Ecuador.` },
        { key: "when-text", label: l.when, value: ecuadorLabel(t.date) + " (hora de Ecuador)" },
        ...(Number(t.fee) > 0
          ? [
            { key: "subtotal", label: l.count, value: money(t.subtotal) },
            { key: "fee", label: "Cargo por servicio", value: money(t.fee) },
          ]
          : []),
        { key: "id", label: "ID del ticket", value: shortId(t.id) },
        ...(ticketUrl ? [{ key: "link", label: "Ver ticket en línea", value: ticketUrl }] : []),
      ],
    },
  }
  if (when) {
    pass.relevantDate = when
    // El pase se marca como vencido un día después de la salida o del evento.
    pass.expirationDate = toEcuadorIso(new Date(Date.parse(t.date!) + 24 * 3600_000).toISOString())
  }
  if (t.used) pass.voided = true
  return pass
}

// ---------------------------------------------------------------- Google

const loc = (value: string) => ({ defaultValue: { language: "es", value } })

export const GOOGLE_CLASS_SUFFIX = "chivaspass_ticket"

// Clase genérica compartida por todos los tickets.
// https://developers.google.com/wallet/generic/rest/v1/genericclass
export function googleClass(issuerId: string): Record<string, unknown> {
  return {
    id: `${issuerId}.${GOOGLE_CLASS_SUFFIX}`,
    // Diseño de la tarjeta: fila con fecha y lugar, fila con asientos y titular.
    classTemplateInfo: {
      cardTemplateOverride: {
        cardRowTemplateInfos: [
          {
            twoItems: {
              startItem: { firstValue: { fields: [{ fieldPath: "object.textModulesData['when']" }] } },
              endItem: { firstValue: { fields: [{ fieldPath: "object.textModulesData['where']" }] } },
            },
          },
          {
            twoItems: {
              startItem: { firstValue: { fields: [{ fieldPath: "object.textModulesData['count']" }] } },
              endItem: { firstValue: { fields: [{ fieldPath: "object.textModulesData['holder']" }] } },
            },
          },
        ],
      },
    },
  }
}

// Objeto genérico de un ticket.
// https://developers.google.com/wallet/generic/rest/v1/genericobject
export function googleObject(
  t: PublicTicket, issuerId: string, opts: { logoUrl: string; ticketUrl: string },
): Record<string, unknown> {
  const l = labelsFor(t)
  const obj: Record<string, unknown> = {
    id: `${issuerId}.${t.id}`,
    classId: `${issuerId}.${GOOGLE_CLASS_SUFFIX}`,
    state: t.used ? "COMPLETED" : "ACTIVE",
    hexBackgroundColor: COLORS.hexBackground,
    logo: {
      sourceUri: { uri: opts.logoUrl },
      contentDescription: loc("chivaspass"),
    },
    cardTitle: loc("chivaspass"),
    subheader: loc(l.what),
    header: loc(t.title ?? "Ticket"),
    barcode: { type: "QR_CODE", value: t.qr_payload, alternateText: shortId(t.id) },
    textModulesData: [
      { id: "when", header: l.when, body: ecuadorLabel(t.date) },
      { id: "where", header: l.where, body: t.place ?? "–" },
      { id: "count", header: l.count, body: l.countValue },
      { id: "holder", header: "Titular", body: t.customer_name ?? "–" },
      { id: "total", header: "Total pagado", body: money(t.total) },
      { id: "help", header: "Cómo usarlo", body: l.help },
    ],
  }
  if (opts.ticketUrl) {
    obj.linksModuleData = { uris: [{ uri: opts.ticketUrl, description: "Ver ticket en línea", id: "ticket" }] }
  }
  if (t.date && !Number.isNaN(Date.parse(t.date))) {
    obj.validTimeInterval = {
      end: { date: toEcuadorIso(new Date(Date.parse(t.date) + 24 * 3600_000).toISOString()) },
    }
  }
  return obj
}
