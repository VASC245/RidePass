<template>
  <span :class="['inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap', tones[resolvedTone]]">
    <span class="size-1.5 rounded-full bg-current" aria-hidden="true" />
    <slot>{{ resolvedLabel }}</slot>
  </span>
</template>

<script setup>
import { computed } from 'vue'

// Uso: <StatusBadge status="pagado" />  o  <StatusBadge tone="warning">Texto</StatusBadge>
const props = defineProps({
  status: { type: String, default: '' },
  tone:   { type: String, default: '' }, // 'success' | 'warning' | 'danger' | 'info' | 'brand' | 'neutral'
})

const tones = {
  success: 'bg-ok-50 border-ok-200 text-ok-700',
  warning: 'bg-warn-50 border-warn-200 text-warn-700',
  danger:  'bg-bad-50 border-bad-200 text-bad-700',
  info:    'bg-info-50 border-info-200 text-info-700',
  brand:   'bg-brand-50 border-brand-200 text-brand-800',
  neutral: 'bg-gray-100 border-gray-200 text-gray-700',
}

// Estados que aparecen en ventas, comprobantes, tickets y salidas
const STATUS = {
  pagado:     ['success', 'Pagado'],
  verificado: ['success', 'Verificado'],
  aprobado:   ['success', 'Aprobado'],
  embarcado:  ['info', 'Embarcado'],
  usado:      ['info', 'Usado'],
  activo:     ['success', 'Activo'],
  pendiente:  ['warning', 'Pendiente'],
  en_revision:['warning', 'En revisión'],
  rechazado:  ['danger', 'Rechazado'],
  cancelado:  ['danger', 'Cancelado'],
  expirado:   ['neutral', 'Expirado'],
  inactivo:   ['neutral', 'Inactivo'],
}

const key = computed(() => (props.status || '').toLowerCase())
const resolvedTone = computed(() => props.tone || STATUS[key.value]?.[0] || 'neutral')
const resolvedLabel = computed(() => STATUS[key.value]?.[1] || props.status)
</script>
