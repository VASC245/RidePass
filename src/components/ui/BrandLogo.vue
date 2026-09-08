<template>
  <span class="inline-flex items-center select-none" :style="{ gap: gap + 'px' }" role="img" aria-label="chivaspass">
    <!-- Isotipo: la curva de la carretera de montaña, dibujada inline para que
         herede el color y escale nítida en cualquier tamaño -->
    <svg viewBox="4 10 62 46" :height="size" :width="Math.round(size * 62 / 46)" aria-hidden="true" focusable="false">
      <path d="M10 50 C 24 50 20 16 34 16 C 46 16 44 32 54 32"
        :stroke="markColor" stroke-width="8" stroke-linecap="round" fill="none" />
      <circle cx="54" cy="32" r="7" :fill="markColor" />
    </svg>
    <span v-if="!iconOnly" class="font-brand leading-none whitespace-nowrap"
      :style="{ color: textColor, fontSize: Math.round(size * 0.92) + 'px', fontWeight: 800, letterSpacing: '-0.03em' }">
      chivaspass
    </span>
  </span>
</template>

<script setup>
import { computed } from 'vue'

// variant:
//   orange → marca y texto en naranja (fondos claros)
//   dark   → marca naranja, texto casi negro (paneles)
//   white  → todo blanco (fondos oscuros o naranjas)
const props = defineProps({
  size:     { type: Number, default: 28 },
  variant:  { type: String, default: 'orange' },
  iconOnly: { type: Boolean, default: false },
})

const BRAND = '#F77F00'
const markColor = computed(() => (props.variant === 'white' ? '#FFFFFF' : BRAND))
const textColor = computed(() =>
  props.variant === 'white' ? '#FFFFFF' : props.variant === 'dark' ? '#111827' : BRAND)
const gap = computed(() => Math.max(4, Math.round(props.size * 0.3)))
</script>
