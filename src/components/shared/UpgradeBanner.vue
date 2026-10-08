<template>
  <div v-if="show"
    class="flex flex-col items-start justify-between gap-4 rounded-[var(--radius-card)] border p-4 sm:flex-row sm:items-center sm:p-5"
    :class="urgency === 'warn' ? 'bg-warn-50 border-warn-200' : 'bg-brand-50 border-brand-200'"
    role="status"
  >
    <div class="flex items-start gap-3">
      <component :is="urgency === 'warn' ? PhWarningCircle : PhInfo" :size="22" class="mt-0.5 shrink-0"
        :class="urgency === 'warn' ? 'text-warn-700' : 'text-brand-700'" />
      <div>
        <p class="font-semibold text-gray-900">{{ title }}</p>
        <p class="mt-0.5 text-sm text-gray-700">{{ subtitle }}</p>
      </div>
    </div>
    <RouterLink to="/panel/planes"
      class="inline-flex h-10 shrink-0 items-center rounded-lg px-4 text-sm font-semibold text-white transition-colors"
      :class="urgency === 'warn' ? 'bg-gray-900 hover:bg-gray-800' : 'bg-brand-600 hover:bg-brand-700'"
    >
      Ver planes
    </RouterLink>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { PhWarningCircle, PhInfo } from '@phosphor-icons/vue'
import { useAuthStore } from '@/stores/authStore'

const props = defineProps({
  ticketsUsed:  { type: Number, default: 0 },
  eventsActive: { type: Number, default: 0 },
})

const auth = useAuthStore()
const plan = computed(() => auth.user?.plan ?? 'free')

const limits = { free: { tickets: 50, events: 3 }, basico: { tickets: 300, events: 999 }, pro: { tickets: 999999, events: 999 } }

const ticketLimit  = computed(() => limits[plan.value]?.tickets ?? 50)
const eventLimit   = computed(() => limits[plan.value]?.events  ?? 3)
const ticketPct    = computed(() => props.ticketsUsed / ticketLimit.value)
const eventMaxed   = computed(() => props.eventsActive >= eventLimit.value)

const show = computed(() => plan.value === 'free' && (ticketPct.value >= 0.7 || eventMaxed.value))

const urgency = computed(() => (ticketPct.value >= 1 || eventMaxed.value) ? 'warn' : 'info')

const title = computed(() => {
  if (eventMaxed.value)        return `Límite de eventos alcanzado (${eventLimit.value} en plan Free)`
  if (ticketPct.value >= 0.9)  return `Casi sin tickets disponibles este mes`
  return `Estás usando el 70% de tu cuota mensual`
})

const subtitle = computed(() => {
  if (plan.value === 'free') return `Plan Free: ${ticketLimit.value} tickets/mes · ${eventLimit.value} eventos activos. Actualiza para crecer.`
  return ''
})
</script>
