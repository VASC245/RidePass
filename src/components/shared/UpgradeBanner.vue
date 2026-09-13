<template>
  <div v-if="show"
    class="rounded-2xl border-2 p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4"
    :class="urgency === 'warn' ? 'bg-yellow-50 border-yellow-300' : 'bg-orange-50 border-orange-300'"
  >
    <div>
      <p class="font-bold text-gray-900 flex items-center gap-2">
                {{ title }}
      </p>
      <p class="text-sm text-gray-500 mt-0.5">{{ subtitle }}</p>
    </div>
    <RouterLink to="/panel/planes"
      class="shrink-0 font-bold text-sm px-5 py-2.5 rounded-xl transition"
      :class="urgency === 'warn' ? 'bg-yellow-500 hover:bg-yellow-600 text-white' : 'bg-orange-600 hover:bg-orange-700 text-white'"
    >
      Ver planes
    </RouterLink>
  </div>
</template>

<script setup>
import { computed } from 'vue'
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
