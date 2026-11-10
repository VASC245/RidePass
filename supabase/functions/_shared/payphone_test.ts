// Pruebas del cálculo del split y del cifrado de PayPhone.
//   deno test supabase/functions/_shared/payphone_test.ts
import { assertEquals, assertThrows, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { commissionCents, encryptTransferTo, planSplit, toCents, transferToJson } from "./payphone.ts"

const OWNER = { role: "owner" as const, identifier: "1790012345001", type: 3 }

Deno.test("toCents convierte sin errores de coma flotante", () => {
  assertEquals(toCents(11.1), 1110)
  assertEquals(toCents("0.85"), 85)
  assertEquals(toCents(1080.3), 108030)
  assertEquals(toCents(0.07), 7)
})

Deno.test("toCents rechaza más de dos decimales y negativos", () => {
  assertThrows(() => toCents(1.005))
  assertThrows(() => toCents(-1))
  assertThrows(() => toCents("abc"))
})

Deno.test("la comisión se redondea hacia arriba al centavo", () => {
  assertEquals(commissionCents(1110, 5.75), 64)    // 63,825
  assertEquals(commissionCents(85, 5.75), 5)       // 4,8875
  assertEquals(commissionCents(10000, 5.75), 575)  // exacto, sin redondeo
  assertEquals(commissionCents(1000, 5.75), 58)    // 57,5
  assertEquals(commissionCents(0, 5.75), 0)
  assertThrows(() => commissionCents(1000, 5.755))
  assertThrows(() => commissionCents(10.5, 5.75))
})

Deno.test("ticket de $10: el vendedor recibe $10 y ChivasPass $0,46", () => {
  const r = planSplit(11.1, 5.75, [{ ...OWNER, amount: 10 }])
  if (!r.ok) throw new Error(r.error)
  assertEquals(r.plan.total_cents, 1110)
  assertEquals(r.plan.payphone_cents, 64)
  assertEquals(r.plan.seller_cents, 1000)
  assertEquals(r.plan.net_fee_cents, 46)
  assertEquals(r.plan.total_cents, r.plan.payphone_cents + r.plan.seller_cents + r.plan.net_fee_cents)
})

Deno.test("el tope se respeta justo en el límite", () => {
  // $10,00: comisión 58 → quedan 942 para repartir
  const ok = planSplit(10, 5.75, [{ ...OWNER, amount: 9.42 }])
  assertEquals(ok.ok && ok.plan.net_fee_cents, 0)
  const over = planSplit(10, 5.75, [{ ...OWNER, amount: 9.43 }])
  assertEquals(!over.ok && over.error, "SPLIT_EXCEEDS_AVAILABLE")
})

Deno.test("una venta sin cargo por servicio (agencia) no se puede repartir", () => {
  const r = planSplit(10, 5.75, [{ ...OWNER, amount: 10 }])
  assertEquals(!r.ok && r.error, "SPLIT_EXCEEDS_AVAILABLE")
})

Deno.test("fase 1: más de un receptor está apagado", () => {
  const two = [{ ...OWNER, amount: 8 }, { role: "agency" as const, identifier: "+593991234567", type: 4, amount: 2 }]
  const off = planSplit(11.1, 5.75, two)
  assertEquals(!off.ok && off.error, "MULTI_RECIPIENT_DISABLED")
  const on = planSplit(11.1, 5.75, two, true)
  if (!on.ok) throw new Error(on.error)
  assertEquals(on.plan.seller_cents, 1000)
  assertEquals(on.plan.recipients.map((x) => x.amount_cents), [800, 200])
})

Deno.test("receptores inválidos se rechazan", () => {
  const bad = (identifier: string, type: number) =>
    planSplit(11.1, 5.75, [{ role: "owner", identifier, type, amount: 10 }])
  assertEquals(bad("0991234567", 4).ok, false)       // celular sin +593
  assertEquals(bad("12345", 3).ok, false)            // largo inválido
  assertEquals(bad("1790012345001", 5).ok, false)    // tipo desconocido
  assertEquals(bad("0912345678", 3).ok, true)        // cédula de 10 dígitos
  assertEquals(planSplit(11.1, 5.75, []).ok, false)
})

// Réplica de public.platform_fee (8 % + $0,30 redondeado a 5 centavos).
const platformFeeCents = (priceCents: number) =>
  Math.round((priceCents * 0.08 + 30) / 5) * 5

Deno.test("con la tarifa actual el tope se cumple para todo precio de $0,50 a $1.000", () => {
  for (let price = 50; price <= 100000; price += 5) {
    const fee = platformFeeCents(price)
    const r = planSplit((price + fee) / 100, 5.75, [{ ...OWNER, amount: price / 100 }])
    if (!r.ok) throw new Error(`falla con precio ${price / 100}: ${r.error}`)
  }
})

Deno.test("transferTo con Amount como texto (por defecto) o número", () => {
  const r = planSplit(11.1, 5.75, [{ ...OWNER, amount: 10 }])
  if (!r.ok) throw new Error(r.error)
  assertEquals(transferToJson(r.plan), '[{"Identifier":"1790012345001","Type":3,"Amount":"1000"}]')
  assertEquals(transferToJson(r.plan, "number"), '[{"Identifier":"1790012345001","Type":3,"Amount":1000}]')
})

Deno.test("el cifrado coincide con openssl (equivalente al ejemplo PHP oficial)", async () => {
  // printf '%s' "$JSON" | openssl enc -aes-256-cbc -K <hex de la clave> -iv 000…0 -base64 -A
  const out = await encryptTransferTo(
    '[{"Identifier":"1790012345001","Type":3,"Amount":"1000"}]',
    "chivaspass-test-key-0123456789ab",
  )
  assertEquals(out, "kPOqX6oHCLsHEQCfZNEESb4Trh3684lQcTkn9IHe6GS34cuJdf/YFx2k3f5TVBLJ0NL1Y+ROcHZUlYR6vU50xw==")
})

Deno.test("una clave que no mide 32 bytes se rechaza", async () => {
  await assertRejects(() => encryptTransferTo("[]", "corta"), Error, "32 bytes")
})
