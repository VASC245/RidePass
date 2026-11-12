// Comprueba que el certificado de Apple Wallet se puede leer y firmar con el
// mismo código de la edge function, antes de subirlo como secret.
// Lo usa scripts/wallet-secrets.sh. Variables: las mismas APPLE_* del secret.
import { appleSignerFromEnv, signManifest } from "../supabase/functions/_shared/pkpass.ts"

try {
  const signer = appleSignerFromEnv((k) => Deno.env.get(k))
  if (!signer) throw new Error("faltan datos")
  signManifest(new TextEncoder().encode("{}"), signer)
  const cn = signer.certificate.subject.getField("CN")?.value ?? "?"
  const until = signer.certificate.validity.notAfter.toISOString().slice(0, 10)
  console.log(`OK: ${cn} (vence ${until})`)
  if (!String(cn).includes(signer.passTypeIdentifier)) {
    console.log(`AVISO: el certificado no menciona ${signer.passTypeIdentifier}`)
  }
} catch (e) {
  console.log(`ERROR: ${(e as Error).message}`)
  Deno.exit(1)
}
