import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'
import tailwindcss from '@tailwindcss/vite'

// CSP preparado para Kushki + Supabase
const securityHeaders = [
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      // Scripts: propio + Kushki tokenizador (NO permite inline arbitrario en prod)
      "script-src 'self' 'unsafe-inline' https://cdn.kushkipagos.com",
      // Estilos: propio + inline (Tailwind inyecta styles)
      "style-src 'self' 'unsafe-inline'",
      // Conexiones: Supabase + Kushki API + Twilio (solo desde Edge Functions, pero por si acaso)
      "connect-src 'self' https://*.supabase.co https://*.kushkipagos.com",
      // Imágenes: propio + data URIs (para los QR generados)
      "img-src 'self' data: https://*.supabase.co",
      // Fuentes propias
      "font-src 'self'",
      // Iframes: Kushki puede abrir 3DS en iframe
      "frame-src https://*.kushkipagos.com",
      // Nunca ejecutar objetos embebidos
      "object-src 'none'",
    ].join("; "),
  },
  { key: "X-Content-Type-Options",    value: "nosniff"        },
  { key: "X-Frame-Options",           value: "DENY"           },
  { key: "Referrer-Policy",           value: "strict-origin-when-cross-origin" },
  { key: "Permissions-Policy",        value: "camera=(self), microphone=()" },
]

// https://vite.dev/config/
export default defineConfig(({ mode }) => ({
  plugins: [
    vue(),
    ...(mode === 'development' ? [vueDevTools()] : []),
    tailwindcss()
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    },
  },
  server: {
    headers: Object.fromEntries(securityHeaders.map(h => [h.key, h.value])),
  },
  build: {
    rollupOptions: {
      output: {
        // Librerías grandes en chunks propios para que se cacheen aparte
        manualChunks: {
          vue:      ['vue', 'vue-router', 'pinia'],
          supabase: ['@supabase/supabase-js'],
          qr:       ['qrcode', 'jsqr'],
        },
      },
    },
  },
}))
