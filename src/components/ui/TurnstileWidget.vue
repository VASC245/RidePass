<template>
  <div v-if="enabled" ref="box" class="min-h-[65px]"></div>
</template>

<script setup>
// Captcha de Cloudflare Turnstile. Solo se muestra si hay
// VITE_TURNSTILE_SITE_KEY; sin ella el servidor tampoco lo exige.
// Emite el token con v-model y expone reset() porque cada token sirve
// para una sola verificación.
import { onBeforeUnmount, onMounted, ref } from 'vue'

const SITE_KEY = import.meta.env.VITE_TURNSTILE_SITE_KEY || ''
const SCRIPT_URL = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'

const emit = defineEmits(['update:modelValue'])
defineProps({ modelValue: { type: String, default: '' } })

const enabled = Boolean(SITE_KEY)
const box = ref(null)
let widgetId = null

let scriptPromise = null
const loadScript = () => {
  if (window.turnstile) return Promise.resolve()
  if (!scriptPromise) {
    scriptPromise = new Promise((resolve, reject) => {
      const s = document.createElement('script')
      s.src = SCRIPT_URL
      s.async = true
      s.onload = resolve
      s.onerror = () => { scriptPromise = null; reject(new Error('turnstile')) }
      document.head.appendChild(s)
    })
  }
  return scriptPromise
}

onMounted(async () => {
  if (!enabled) return
  try {
    await loadScript()
    if (!box.value) return
    widgetId = window.turnstile.render(box.value, {
      sitekey: SITE_KEY,
      language: 'es',
      callback: (token) => emit('update:modelValue', token),
      'expired-callback': () => emit('update:modelValue', ''),
      'error-callback': () => emit('update:modelValue', ''),
    })
  } catch {
    // Sin el script la verificación falla en el servidor y el usuario ve el mensaje.
  }
})

onBeforeUnmount(() => {
  if (widgetId !== null && window.turnstile) window.turnstile.remove(widgetId)
})

const reset = () => {
  emit('update:modelValue', '')
  if (widgetId !== null && window.turnstile) window.turnstile.reset(widgetId)
}

defineExpose({ reset, enabled })
</script>
