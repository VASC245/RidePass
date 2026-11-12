// Arma y firma un archivo .pkpass de Apple Wallet.
//
// Un .pkpass es un zip con pass.json, las imágenes, manifest.json (SHA-1 de
// cada archivo) y signature (firma PKCS#7 separada de manifest.json, hecha
// con el certificado del Pass Type ID e incluyendo el intermedio WWDR de
// Apple). https://developer.apple.com/documentation/walletpasses/building-a-pass
//
// Secrets (los carga Valentin):
//   APPLE_PASS_TYPE_ID        p. ej. pass.com.chivaspass.ticket
//   APPLE_TEAM_ID             10 caracteres, de developer.apple.com → Membership
//   APPLE_PASS_P12_BASE64     el certificado del Pass Type ID exportado desde
//                             Llavero como .p12, en base64 (base64 -i cert.p12)
//   APPLE_PASS_P12_PASSWORD   la contraseña con que se exportó el .p12
//   APPLE_WWDR_CERT_BASE64    certificado intermedio "Apple WWDR G4" (.cer) en
//                             base64; también acepta el texto PEM

import { forge, type ForgeObject } from "./forge.ts"
import { zipSync } from "https://esm.sh/fflate@0.8.2"

export interface AppleSigner {
  passTypeIdentifier: string
  teamIdentifier: string
  certificate: ForgeObject
  privateKey: ForgeObject
  wwdr: ForgeObject
}

const enc = new TextEncoder()

function bytesToBinary(b: Uint8Array): string {
  let s = ""
  for (let i = 0; i < b.length; i += 0x8000) s += String.fromCharCode(...b.subarray(i, i + 0x8000))
  return s
}

function binaryToBytes(s: string): Uint8Array {
  const out = new Uint8Array(s.length)
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i) & 0xff
  return out
}

// Acepta un certificado en PEM o en DER codificado en base64.
function parseCert(value: string): ForgeObject {
  const v = value.trim()
  if (v.startsWith("-----BEGIN")) return forge.pki.certificateFromPem(v)
  const der = forge.util.decode64(v.replace(/\s+/g, ""))
  return forge.pki.certificateFromAsn1(forge.asn1.fromDer(der))
}

// Lee los secrets. Devuelve null si falta alguno (la función responde 503).
export function appleSignerFromEnv(env: (k: string) => string | undefined): AppleSigner | null {
  const passTypeIdentifier = env("APPLE_PASS_TYPE_ID")?.trim()
  const teamIdentifier = env("APPLE_TEAM_ID")?.trim()
  const p12b64 = env("APPLE_PASS_P12_BASE64")?.trim()
  const wwdrRaw = env("APPLE_WWDR_CERT_BASE64")?.trim()
  if (!passTypeIdentifier || !teamIdentifier || !p12b64 || !wwdrRaw) return null

  const p12Der = forge.util.decode64(p12b64.replace(/\s+/g, ""))
  const p12 = forge.pkcs12.pkcs12FromAsn1(forge.asn1.fromDer(p12Der), env("APPLE_PASS_P12_PASSWORD") ?? "")
  const certBag = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag]?.[0]
  const keyBag = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0]
    ?? p12.getBags({ bagType: forge.pki.oids.keyBag })[forge.pki.oids.keyBag]?.[0]
  if (!certBag?.cert || !keyBag?.key) throw new Error("El .p12 no trae certificado y clave privada.")

  return {
    passTypeIdentifier,
    teamIdentifier,
    certificate: certBag.cert,
    privateKey: keyBag.key,
    wwdr: parseCert(wwdrRaw),
  }
}

async function sha1Hex(data: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-1", data as Uint8Array<ArrayBuffer>)
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("")
}

// Firma PKCS#7 separada (detached) de manifest.json, SHA-256.
export function signManifest(manifest: Uint8Array, signer: AppleSigner): Uint8Array {
  const p7 = forge.pkcs7.createSignedData()
  p7.content = forge.util.createBuffer(bytesToBinary(manifest))
  p7.addCertificate(signer.certificate)
  p7.addCertificate(signer.wwdr)
  p7.addSigner({
    key: signer.privateKey,
    certificate: signer.certificate,
    digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType, value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest },
      { type: forge.pki.oids.signingTime, value: new Date().toISOString() },
    ],
  })
  p7.sign({ detached: true })
  return binaryToBytes(forge.asn1.toDer(p7.toAsn1()).getBytes())
}

// pass.json + imágenes (base64) → bytes del .pkpass firmado.
export async function buildPkpass(
  passJson: Record<string, unknown>,
  imagesB64: Record<string, string>,
  signer: AppleSigner | null,
): Promise<Uint8Array> {
  const files: Record<string, Uint8Array> = {
    "pass.json": enc.encode(JSON.stringify(passJson)),
  }
  for (const [name, b64] of Object.entries(imagesB64)) {
    files[name] = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  }
  const manifest: Record<string, string> = {}
  for (const [name, data] of Object.entries(files)) manifest[name] = await sha1Hex(data)
  files["manifest.json"] = enc.encode(JSON.stringify(manifest))
  // Sin firmante (solo en pruebas) el zip sale sin signature: el iPhone lo rechaza.
  if (signer) files["signature"] = signManifest(files["manifest.json"], signer)
  return zipSync(files, { level: 6 })
}
