<template>
  <div class="space-y-8">
    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
      <h1 class="text-2xl font-extrabold text-gray-800">Dashboard</h1>

      <!-- Filtros de período -->
      <div class="flex gap-2">
        <button v-for="f in periods" :key="f.value" @click="period = f.value"
          class="px-4 py-2 rounded-xl text-sm font-semibold transition"
          :class="period === f.value ? 'bg-green-600 text-white shadow-sm' : 'bg-white border border-gray-200 text-gray-600 hover:border-green-400'">
          {{ f.label }}
        </button>
      </div>
    </div>

    <UpgradeBanner :tickets-used="totalTickets" :events-active="totalEvents" />

    <!-- KPIs -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <div v-for="kpi in kpis" :key="kpi.label"
        class="bg-white rounded-2xl shadow-sm border p-5">
        <p class="text-sm text-gray-500 font-medium">{{ kpi.label }}</p>
        <p class="text-3xl font-extrabold mt-1" :class="kpi.color">{{ kpi.value }}</p>
        <p v-if="kpi.sub" class="text-xs text-gray-400 mt-1">{{ kpi.sub }}</p>
      </div>
    </div>

    <!-- Gráficas -->
    <div class="grid lg:grid-cols-2 gap-6">
      <!-- Ingresos por día -->
      <div class="bg-white rounded-2xl shadow-sm border p-5">
        <h3 class="font-bold text-gray-700 mb-4">Ingresos por día ($)</h3>
        <div v-if="chartData.labels.length === 0" class="text-center py-8 text-gray-400 text-sm">Sin datos en este período</div>
        <div v-else class="space-y-2">
          <div v-for="(label, i) in chartData.labels" :key="label" class="flex items-center gap-3">
            <span class="text-xs text-gray-400 w-20 shrink-0">{{ label }}</span>
            <div class="flex-1 bg-gray-100 rounded-full h-5 overflow-hidden">
              <div class="h-full bg-green-500 rounded-full transition-all duration-500"
                :style="{ width: barWidth(chartData.revenue[i], maxRevenue) }"></div>
            </div>
            <span class="text-xs font-bold text-gray-700 w-16 text-right">${{ chartData.revenue[i].toFixed(2) }}</span>
          </div>
        </div>
      </div>

      <!-- Ventas por fuente -->
      <div class="bg-white rounded-2xl shadow-sm border p-5">
        <h3 class="font-bold text-gray-700 mb-4">Entradas vendidas por día</h3>
        <div v-if="chartData.labels.length === 0" class="text-center py-8 text-gray-400 text-sm">Sin datos en este período</div>
        <div v-else class="space-y-2">
          <div v-for="(label, i) in chartData.labels" :key="label + '-v'" class="flex items-center gap-3">
            <span class="text-xs text-gray-400 w-20 shrink-0">{{ label }}</span>
            <div class="flex-1 bg-gray-100 rounded-full h-5 overflow-hidden">
              <div class="h-full bg-blue-500 rounded-full transition-all duration-500"
                :style="{ width: barWidth(chartData.tickets[i], maxTickets) }"></div>
            </div>
            <span class="text-xs font-bold text-gray-700 w-16 text-right">{{ chartData.tickets[i] }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Últimas ventas -->
    <div class="bg-white rounded-2xl shadow-sm border p-6">
      <h3 class="font-bold text-gray-700 mb-4">Últimas transacciones</h3>
      <div v-if="recentSales.length === 0" class="text-center py-6 text-gray-400 text-sm">Sin ventas en este período</div>
      <div v-else class="space-y-2">
        <div v-for="s in recentSales" :key="s.id"
          class="flex items-center justify-between py-2.5 border-b border-gray-50 last:border-0">
          <div>
            <p class="font-semibold text-gray-800 text-sm">{{ s.label }}</p>
            <p class="text-xs text-gray-400">{{ s.date }} · {{ s.source }}</p>
          </div>
          <span class="font-extrabold text-green-600">${{ Number(s.amount).toFixed(2) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'
import UpgradeBanner from '@/components/shared/UpgradeBanner.vue'

const auth   = useAuthStore()
const period = ref('semana')

const periods = [
  { label: 'Hoy',      value: 'hoy'    },
  { label: 'Semana',   value: 'semana' },
  { label: 'Mes',      value: 'mes'    },
  { label: 'Todo',     value: 'todo'   },
]

const chivaSales = ref([])
const bizTickets = ref([])

const periodStart = () => {
  const now = new Date()
  if (period.value === 'hoy')    { const d = new Date(now); d.setHours(0,0,0,0); return d }
  if (period.value === 'semana') { const d = new Date(now); d.setDate(d.getDate() - 6); d.setHours(0,0,0,0); return d }
  if (period.value === 'mes')    { return new Date(now.getFullYear(), now.getMonth(), 1) }
  return new Date(0)
}

const load = async () => {
  const uid   = auth.user?.id
  const from  = periodStart().toISOString()

  const [csRes, btRes] = await Promise.all([
    supabase.from('sales_simple')
      .select('id, created_at, total_sale, owner_gain, seats, status')
      .eq('owner_id', uid)
      .eq('status', 'pagado')
      .gte('created_at', from),
    supabase.from('business_tickets')
      .select('id, created_at, total_price, quantity, payment_status, business_events(title)')
      .eq('owner_id', uid)
      .eq('payment_status', 'verificado')
      .gte('created_at', from),
  ])
  chivaSales.value = csRes.data ?? []
  bizTickets.value = btRes.data ?? []
}

onMounted(load)
watch(period, load)

// ── KPIs ────────────────────────────────────────────────────
const totalRevenue = computed(() => {
  const chiva = chivaSales.value.reduce((s, x) => s + Number(x.owner_gain ?? 0), 0)
  const biz   = bizTickets.value.reduce((s, x) => s + Number(x.total_price ?? 0), 0)
  return (chiva + biz).toFixed(2)
})

const totalEvents = computed(() => chivaSales.value.length)

// seats llega como array (ventas nuevas) o como texto JSON (ventas antiguas)
const seatCount = (seats) => {
  if (Array.isArray(seats)) return seats.length
  try { return JSON.parse(seats || '[]').length } catch { return 0 }
}

const totalTickets = computed(() => {
  const chiva = chivaSales.value.reduce((s, x) => s + seatCount(x.seats), 0)
  const biz   = bizTickets.value.reduce((s, x) => s + (x.quantity ?? 0), 0)
  return chiva + biz
})

const kpis = computed(() => [
  { label: 'Ingresos totales',  value: `$${totalRevenue.value}`,     color: 'text-green-600',  sub: 'chivas + negocios' },
  { label: 'Entradas vendidas', value: totalTickets.value,            color: 'text-blue-600',   sub: null },
  { label: 'Tours (chivas)',    value: chivaSales.value.length,       color: 'text-orange-500', sub: null },
  { label: 'Tickets (negocio)', value: bizTickets.value.length,       color: 'text-purple-600', sub: null },
])

// ── Gráficas por día ─────────────────────────────────────────
const chartData = computed(() => {
  const revenueMap = {}
  const ticketsMap = {}

  const addDay = (dateStr, amount, qty) => {
    const d = dateStr.slice(0, 10)
    revenueMap[d] = (revenueMap[d] ?? 0) + Number(amount)
    ticketsMap[d] = (ticketsMap[d] ?? 0) + qty
  }

  chivaSales.value.forEach(s => addDay(s.created_at, s.owner_gain, seatCount(s.seats)))
  bizTickets.value.forEach(t => addDay(t.created_at, t.total_price, t.quantity))

  const labels = Object.keys(revenueMap).sort()
  return {
    labels:  labels.map(l => new Date(l).toLocaleDateString('es-EC', { weekday: 'short', day: 'numeric', month: 'short' })),
    revenue: labels.map(l => revenueMap[l]),
    tickets: labels.map(l => ticketsMap[l]),
  }
})

const maxRevenue = computed(() => Math.max(...chartData.value.revenue, 1))
const maxTickets = computed(() => Math.max(...chartData.value.tickets, 1))
const barWidth   = (val, max) => `${Math.round((val / max) * 100)}%`

// ── Últimas ventas ───────────────────────────────────────────
const recentSales = computed(() => {
  const list = [
    ...chivaSales.value.map(s => ({
      id: s.id, amount: s.owner_gain,
      label: `Tour chiva`,
      source: 'Chiva',
      date: new Date(s.created_at).toLocaleDateString('es-EC', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }),
      ts: s.created_at,
    })),
    ...bizTickets.value.map(t => ({
      id: t.id, amount: t.total_price,
      label: t.business_events?.title ?? 'Evento',
      source: 'Negocio',
      date: new Date(t.created_at).toLocaleDateString('es-EC', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }),
      ts: t.created_at,
    })),
  ]
  return list.sort((a, b) => new Date(b.ts) - new Date(a.ts)).slice(0, 10)
})
</script>
