import { assert, assertEquals, assertMatch } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { forge, type ForgeObject } from "./forge.ts"
import { unzipSync } from "https://esm.sh/fflate@0.8.2"
import { applePassJson, ecuadorLabel, googleClass, googleObject, type PublicTicket, toEcuadorIso, walletReady } from "./wallet.ts"
import { type AppleSigner, appleSignerFromEnv, buildPkpass } from "./pkpass.ts"

const tour: PublicTicket = {
  kind: "tour",
  id: "3f2a9c1e-0000-4000-8000-000000000abc",
  customer_name: "Ana Pérez",
  quantity: 2,
  seats: [3, 4],
  subtotal: 20,
  fee: 1.9,
  total: 21.9,
  qr_payload: JSON.stringify({ type: "chiva_sale", sale_id: "3f2a9c1e-0000-4000-8000-000000000abc" }),
  used: false,
  title: "Ruta de las Cascadas",
  date: "2026-12-13T19:30:00+00:00",
  place: "La Bañeña",
}

const event: PublicTicket = {
  ...tour,
  kind: "business",
  id: "9b1c0d2e-0000-4000-8000-000000000def",
  seats: undefined,
  quantity: 3,
  fee: 0,
  qr_payload: JSON.stringify({ type: "business_ticket", ticket_id: "9b1c0d2e-0000-4000-8000-000000000def" }),
  title: "Columpio del fin del mundo",
  place: "Casa del Árbol",
}

Deno.test("hora de Ecuador: UTC-5 sin horario de verano", () => {
  assertEquals(toEcuadorIso("2026-12-13T19:30:00+00:00"), "2026-12-13T14:30:00-05:00")
  assertEquals(toEcuadorIso("2026-07-01T03:00:00Z"), "2026-06-30T22:00:00-05:00")
  assertEquals(toEcuadorIso(null), null)
  assertEquals(toEcuadorIso("no es fecha"), null)
  assertMatch(ecuadorLabel("2026-12-13T19:30:00+00:00"), /13.*diciembre.*14:30/)
})

Deno.test("walletReady exige id y QR", () => {
  assert(walletReady(tour))
  assert(!walletReady(null))
  assert(!walletReady({ ...tour, qr_payload: null }))
})

Deno.test("pass.json de Apple: QR idéntico al del ticket y datos del tour", () => {
  const p = applePassJson(tour, { passTypeIdentifier: "pass.com.chivaspass.ticket", teamIdentifier: "ABCDE12345" }, "https://chivaspass.com/ticket/x")
  // deno-lint-ignore no-explicit-any
  const pass = p as any
  assertEquals(pass.serialNumber, tour.id)
  assertEquals(pass.barcodes[0].format, "PKBarcodeFormatQR")
  assertEquals(pass.barcodes[0].message, tour.qr_payload)
  assertEquals(pass.eventTicket.primaryFields[0].value, "Ruta de las Cascadas")
  assertEquals(pass.eventTicket.headerFields[0].value, "3, 4")
  assertEquals(pass.eventTicket.headerFields[0].label, "ASIENTOS")
  // deno-lint-ignore no-explicit-any
  assertEquals((applePassJson({ ...tour, seats: [7] }, { passTypeIdentifier: "p", teamIdentifier: "t" }, "") as any).eventTicket.headerFields[0].label, "ASIENTO")
  assertEquals(pass.eventTicket.secondaryFields[0].value, "2026-12-13T14:30:00-05:00")
  assertEquals(pass.relevantDate, "2026-12-13T14:30:00-05:00")
  assertEquals(pass.expirationDate, "2026-12-14T14:30:00-05:00")
  assertEquals(pass.voided, undefined)
  assert(pass.eventTicket.backFields.some((f: { key: string }) => f.key === "fee"))
})

Deno.test("pass.json de Apple: evento sin cargo y ticket usado queda anulado", () => {
  // deno-lint-ignore no-explicit-any
  const pass = applePassJson({ ...event, used: true }, { passTypeIdentifier: "p", teamIdentifier: "t" }, "") as any
  assertEquals(pass.eventTicket.primaryFields[0].label, "EVENTO")
  assertEquals(pass.eventTicket.headerFields[0].value, "3")
  assertEquals(pass.voided, true)
  assert(!pass.eventTicket.backFields.some((f: { key: string }) => f.key === "fee" || f.key === "link"))
})

Deno.test("Google: objeto genérico con QR, estado y clase compartida", () => {
  // deno-lint-ignore no-explicit-any
  const o = googleObject(tour, "3388000000000000000", { logoUrl: "https://x/logo.png", ticketUrl: "https://x/t" }) as any
  assertEquals(o.id, `3388000000000000000.${tour.id}`)
  assertEquals(o.classId, googleClass("3388000000000000000").id)
  assertEquals(o.barcode.type, "QR_CODE")
  assertEquals(o.barcode.value, tour.qr_payload)
  assertEquals(o.state, "ACTIVE")
  assertMatch(o.id, /^[0-9]+\.[\w.-]+$/)
  // deno-lint-ignore no-explicit-any
  assertEquals((googleObject({ ...tour, used: true }, "1", { logoUrl: "", ticketUrl: "" }) as any).state, "COMPLETED")
})

// Certificado de prueba autofirmado (no sirve en un iPhone, pero permite
// comprobar que el zip, el manifiesto y la firma PKCS#7 quedan bien armados).
function testSigner(): { signer: AppleSigner; p12b64: string; wwdrPem: string } {
  const keys = forge.pki.rsa.generateKeyPair(1024)
  const cert = forge.pki.createCertificate()
  cert.publicKey = keys.publicKey
  cert.serialNumber = "01"
  cert.validity.notBefore = new Date(Date.now() - 86400_000)
  cert.validity.notAfter = new Date(Date.now() + 86400_000)
  const attrs = [{ name: "commonName", value: "Pass Type ID: pass.test" }]
  cert.setSubject(attrs)
  cert.setIssuer(attrs)
  cert.sign(keys.privateKey, forge.md.sha256.create())
  const p12 = forge.pkcs12.toPkcs12Asn1(keys.privateKey, [cert], "clave", { algorithm: "3des" })
  const p12b64 = forge.util.encode64(forge.asn1.toDer(p12).getBytes())
  const wwdrPem = forge.pki.certificateToPem(cert)
  return {
    signer: { passTypeIdentifier: "pass.test", teamIdentifier: "T", certificate: cert, privateKey: keys.privateKey, wwdr: cert },
    p12b64,
    wwdrPem,
  }
}

Deno.test("secrets de Apple: sin todos responde null; con .p12 + WWDR los lee", () => {
  assertEquals(appleSignerFromEnv(() => undefined), null)
  const { p12b64, wwdrPem } = testSigner()
  const vals: Record<string, string> = {
    APPLE_PASS_TYPE_ID: "pass.test", APPLE_TEAM_ID: "T", APPLE_PASS_P12_BASE64: p12b64,
    APPLE_PASS_P12_PASSWORD: "clave", APPLE_WWDR_CERT_BASE64: wwdrPem,
  }
  const s = appleSignerFromEnv((k) => vals[k])
  assert(s)
  assertEquals(s.certificate.subject.getField("CN").value, "Pass Type ID: pass.test")
})

Deno.test(".pkpass: zip con manifiesto SHA-1 correcto y firma PKCS#7 separada válida", async () => {
  const { signer } = testSigner()
  const pass = applePassJson(tour, signer, "")
  const zip = await buildPkpass(pass, { "icon.png": btoa("png-falso") }, signer)
  const files = unzipSync(zip)
  assertEquals(Object.keys(files).sort(), ["icon.png", "manifest.json", "pass.json", "signature"])

  const manifest = JSON.parse(new TextDecoder().decode(files["manifest.json"]))
  for (const name of ["pass.json", "icon.png"]) {
    const d = new Uint8Array(await crypto.subtle.digest("SHA-1", files[name] as Uint8Array<ArrayBuffer>))
    assertEquals(manifest[name], [...d].map((b) => b.toString(16).padStart(2, "0")).join(""))
  }

  // La firma es de manifest.json: el hash firmado coincide con el SHA-256 del manifiesto.
  const bin = String.fromCharCode(...files["signature"])
  const p7 = forge.pkcs7.messageFromAsn1(forge.asn1.fromDer(bin)) as unknown as {
    rawCapture: { authenticatedAttributes: ForgeObject[] }
  }
  const md = forge.md.sha256.create()
  md.update(String.fromCharCode(...files["manifest.json"]))
  const attrs = p7.rawCapture.authenticatedAttributes
  const digestAttr = attrs.find((a) => forge.asn1.derToOid((a.value as ForgeObject[])[0].value as string) === forge.pki.oids.messageDigest)!
  const digest = ((digestAttr.value as ForgeObject[])[1].value as ForgeObject[])[0].value as string
  assertEquals(forge.util.bytesToHex(digest), md.digest().toHex())
})
