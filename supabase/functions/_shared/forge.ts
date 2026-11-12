// node-forge sin los tipos que sirve esm.sh: @types/node-forge arrastra
// @types/node, que no existe en el CI ni en Supabase (no hay node_modules).
// deno-lint-ignore-file no-explicit-any
// @ts-types="./forge.d.ts"
import forgeLib from "https://esm.sh/node-forge@1.3.1?target=es2022"

export const forge: any = forgeLib
// Objetos de node-forge (certificados, claves, nodos ASN.1).
export type ForgeObject = any
