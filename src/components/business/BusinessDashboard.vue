<template>
  <div class="space-y-6">
    <h2 class="text-2xl font-bold text-gray-800">Panel de mi Negocio</h2>

    <UpgradeBanner :tickets-used="stats.tickets" :events-active="stats.activeEvents" />

    <!-- KPIs -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
      <div class="bg-white rounded-2xl p-5 shadow-sm border">
        <p class="text-sm text-gray-500 font-medium">Eventos activos</p>
        <p class="text-3xl font-extrabold text-orange-600 mt-1">{{ stats.activeEvents }}</p>
      </div>
      <div class="bg-white rounded-2xl p-5 shadow-sm border">
        <p class="text-sm text-gray-500 font-medium">Tickets vendidos</p>
        <p class="text-3xl font-extrabold text-blue-600 mt-1">{{ stats.tickets }}</p>
      </div>
      <div class="bg-white rounded-2xl p-5 shadow-sm border">
        <p class="text-sm text-gray-500 font-medium">Pendientes verificar</p>
        <p class="text-3xl font-extrabold text-yellow-500 mt-1">{{ stats.pending }}</p>
      </div>
      <div class="bg-white rounded-2xl p-5 shadow-sm border">
        <p class="text-sm text-gray-500 font-medium">Ingresos totales</p>
        <p class="text-3xl font-extrabold text-green-600 mt-1">${{ stats.revenue }}</p>
      </div>
    </div>

    <!-- Próximos eventos -->
    <div class="bg-white rounded-2xl shadow-sm border p-6">
      <h3 class="text-lg font-bold text-gray-700 mb-4">Próximos eventos</h3>
      <div v-if="loading" class="text-center py-8 text-gray-400">Cargando...</div>
      <div v-else-if="upcomingEvents.length === 0" class="text-center py-8 text-gray-400">
        No hay eventos próximos. <RouterLink to="/panel/negocio-eventos" class="text-orange-600 font-semibold hover:underline">Crear uno</RouterLink>
      </div>
      <div v-else class="space-y-3">
        <div
          v-for="ev in upcomingEvents"
          :key="ev.id"
          class="flex items-center justify-between py-3 border-b last:border-0"
        >
          <div>
            <p class="font-semibold text-gray-800">{{ ev.title }}</p>
            <p class="text-sm text-gray-500">{{ formatDate(ev.event_date) }} · {{ ev.capacity }} cupos</p>
          </div>
          <div class="text-right">
            <p class="font-bold text-green-600">${{ ev.price }}</p>
            <span
              class="text-xs px-2 py-0.5 rounded-full font-semibold"
              :class="ev.status === 'activo' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'"
            >{{ ev.status }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'
import UpgradeBanner from '@/components/shared/UpgradeBanner.vue'

const authStore = useAuthStore()
const loading = ref(true)
const upcomingEvents = ref([])
const stats = ref({ activeEvents: 0, tickets: 0, pending: 0, revenue: 0 })

const formatDate = (d) => new Date(d).toLocaleDateString('es-EC', { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })

onMounted(async () => {
  const uid = authStore.user?.id
  if (!uid) return

  const [evRes, tkRes] = await Promise.all([
    supabase.from('business_events').select('*').eq('owner_id', uid).order('event_date'),
    supabase.from('business_tickets').select('quantity, total_price, payment_status').eq('owner_id', uid),
  ])

  const events = evRes.data ?? []
  const tickets = tkRes.data ?? []

  upcomingEvents.value = events.filter(e => e.status === 'activo').slice(0, 5)
  stats.value = {
    activeEvents: events.filter(e => e.status === 'activo').length,
    tickets: tickets.reduce((s, t) => s + t.quantity, 0),
    pending: tickets.filter(t => t.payment_status === 'pendiente').length,
    revenue: tickets.filter(t => t.payment_status === 'verificado').reduce((s, t) => s + Number(t.total_price), 0).toFixed(2),
  }
  loading.value = false
})
</script>
