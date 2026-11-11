// Pruebas del aviso por SMS al vendedor.
//   deno test supabase/functions/_shared/messages_test.ts
import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { sellerSms, type TicketInfo } from "./messages.ts"

const base: TicketInfo = {
  kind: "tour", status: "pendiente",
  customer: { name: "Ana", email: "ana@test.local" },
  title: "Ruta de las Cascadas", place: "La Bañeña", date: "2026-11-20T15:00:00Z",
  seats: [1, 2], quantity: 2, amount: 24, subtotal: 24, fee: 0,
  paymentLabel: "Transferencia · TRX-1", ticketUrl: "",
}

Deno.test("El SMS al dueño muestra lo que recibe él, no el precio de la agencia", () => {
  const sms = sellerSms({ ...base, sellerAmount: 20 })
  assertStringIncludes(sms, "$20.00")
  assertEquals(sms.includes("$24.00"), false)
})

Deno.test("Sin sobreprecio el SMS muestra el total", () => {
  assertStringIncludes(sellerSms(base), "$24.00")
})
