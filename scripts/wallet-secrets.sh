#!/usr/bin/env bash
# Carga en Supabase los secrets de Apple Wallet y/o Google Wallet.
#
#   bash scripts/wallet-secrets.sh apple  <pass.p12> <AppleWWDRCAG4.cer> <TEAM_ID>
#   bash scripts/wallet-secrets.sh google <ISSUER_ID> <clave-cuenta-servicio.json>
#
# La contraseña del .p12 se pide en pantalla (no queda en el historial ni
# en el chat). Antes de subir nada, comprueba que el certificado firma bien;
# si macOS lo exportó con un cifrado que la función no lee, lo convierte.
set -euo pipefail
cd "$(dirname "$0")/.."
REF=cyyzudhjpifpbpeiebsn
PASS_TYPE_ID=pass.com.chivaspass.ticket
DENO="${DENO:-$(command -v deno || echo "$HOME/.deno/bin/deno")}"

case "${1:-}" in
  apple)
    P12="${2:?Falta la ruta del .p12}"; WWDR="${3:?Falta la ruta del certificado WWDR G4}"; TEAM="${4:?Falta el Team ID}"
    [[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]] || { echo "El Team ID son 10 letras/números en mayúscula."; exit 1; }
    read -r -s -p "Contraseña del .p12: " P12_PASS; echo; export P12_PASS
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    check() {
      APPLE_PASS_TYPE_ID="$PASS_TYPE_ID" APPLE_TEAM_ID="$TEAM" APPLE_PASS_P12_PASSWORD="$P12_PASS" \
      APPLE_PASS_P12_BASE64="$(base64 -i "$1")" APPLE_WWDR_CERT_BASE64="$(base64 -i "$WWDR")" \
        "$DENO" run --quiet --allow-env --allow-net=esm.sh scripts/check-apple-pass.ts
    }
    if ! OUT="$(check "$P12")"; then
      echo "$OUT"
      if [[ "$OUT" == *"Invalid password"* ]]; then echo "La contraseña del .p12 no es correcta."; exit 1; fi
      echo "Convirtiendo el .p12 a un formato compatible..."
      openssl pkcs12 -in "$P12" -nodes -passin env:P12_PASS -out "$TMP/pass.pem" 2>/dev/null \
        || openssl pkcs12 -legacy -in "$P12" -nodes -passin env:P12_PASS -out "$TMP/pass.pem"
      openssl pkcs12 -export -legacy -in "$TMP/pass.pem" -passout env:P12_PASS -out "$TMP/pass.p12"
      P12="$TMP/pass.p12"
      check "$P12"
    else
      echo "$OUT"
    fi
    npx supabase secrets set --project-ref "$REF" \
      APPLE_PASS_TYPE_ID="$PASS_TYPE_ID" \
      APPLE_TEAM_ID="$TEAM" \
      APPLE_PASS_P12_BASE64="$(base64 -i "$P12")" \
      APPLE_PASS_P12_PASSWORD="$P12_PASS" \
      APPLE_WWDR_CERT_BASE64="$(base64 -i "$WWDR")"
    echo "Listo: secrets de Apple Wallet cargados."
    ;;
  google)
    ISSUER="${2:?Falta el Issuer ID}"; KEY="${3:?Falta la ruta del JSON de la cuenta de servicio}"
    [[ "$ISSUER" =~ ^[0-9]{10,25}$ ]] || { echo "El Issuer ID es solo números."; exit 1; }
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("client_email") and d.get("private_key"); print("OK:", d["client_email"])' "$KEY"
    npx supabase secrets set --project-ref "$REF" \
      GOOGLE_WALLET_ISSUER_ID="$ISSUER" \
      GOOGLE_WALLET_SERVICE_ACCOUNT="$(cat "$KEY")"
    echo "Listo: secrets de Google Wallet cargados."
    ;;
  *)
    sed -n '2,9p' "$0"; exit 1 ;;
esac
