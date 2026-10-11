<template>
  <div>
    <PageHeader title="Resumen" :description="`Tus ventas pagadas ${periodPhrase}.`">
      <template #actions>
        <SegmentedControl v-model="period" :options="periods" label="Período" />
      </template>
    </PageHeader>

    <div class="space-y-6">

      <!-- Cifras del período -->
      <section class="grid overflow-hidden rounded-[var(--radius-card)] border border-gray-200 bg-white lg:grid-cols-[1.3fr_2fr]" aria-label="Cifras del período">
        <div class="border-b border-gray-200 p-5 sm:p-6 lg:border-b-0 lg:border-r">
          <p class="text-sm font-medium text-gray-600">Tu ganancia</p>
          <p class="mt-2 text-4xl font-bold tracking-[-0.02em] text-gray-900 tabular-nums">
            <span class="text-gray-400">$</span>{{ totalRevenue }}
          </p>
          <p class="mt-2 text-sm text-gray-600">Ventas de chivas y de negocios.</p>
        </div>
        <dl class="grid grid-cols-3 divide-x divide-gray-200">
          <div v-for="m in metrics" :key="m.label" class="p-5 sm:p-6">
            <dt class="text-sm font-medium text-gray-600">{{ m.label }}</dt>
            <dd class="mt-2 text-2xl font-bold text-gray-900 tabular-nums">{{ m.value }}</dd>
          </div>
        </dl>
      </section>

      <div class="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
        <!-- Por día -->
        <BaseCard>
          <template #title>Por día</template>
          <EmptyState v-if="chartData.labels.length === 0" :icon="PhChartBar"
            title="Sin ventas en este período"
            description="Cuando se pague una venta, aquí verás cuánto ganaste cada día." />
          <ul v-else class="space-y-3.5">
            <li v-for="(label, i) in chartData.labels" :key="label" class="grid grid-cols-[6.5rem_1fr_auto] items-center gap-x-3">
              <div>
                <p class="text-sm text-gray-800 first-letter:uppercase whitespace-nowrap">{{ label }}</p>
                <p class="text-xs text-gray-600 tabular-nums">{{ chartData.tickets[i] }} {{ chartData.tickets[i] === 1 ? 'entrada' : 'entradas' }}</p>
              </div>
              <div class="h-2 overflow-hidden rounded-full bg-gray-100">
                <div class="h-full rounded-full bg-brand-500 transition-[width] duration-300 ease-out" :style="{ width: barWidth(chartData.revenue[i], maxRevenue) }" />
              </div>
              <span class="w-16 text-right text-sm font-semibold text-gray-900 tabular-nums">${{ chartData.revenue[i].toFixed(2) }}</span>
            </li>
          </ul>
        </BaseCard>

        <!-- Últimas transacciones -->
        <BaseCard>
          <template #title>Últimas transacciones</template>
          <template v-if="recentSales.length" #actions>
            <RouterLink to="/panel/mis-ventas" class="text-sm font-semibold text-brand-700 hover:text-brand-800">Ver ventas</RouterLink>
          </template>
          <EmptyState v-if="recentSales.length === 0" :icon="PhReceipt"
            title="Todavía no hay transacciones"
            description="Las ventas pagadas en este período aparecerán aquí." />
          <ul v-else class="-my-2 divide-y divide-gray-100">
            <li v-for="s in recentSales" :key="s.id" class="flex items-center gap-3 py-3">
              <span class="inline-flex size-9 shrink-0 items-center justify-center rounded-full"
                :class="s.source === 'Chiva' ? 'bg-brand-50 text-brand-700' : 'bg-info-50 text-info-700'">
                <component :is="s.source === 'Chiva' ? PhBus : PhTicket" :size="18" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold text-gray-900">{{ s.label }}</p>
                <p class="text-xs text-gray-600">{{ s.date }}</p>
              </div>
              <span class="text-sm font-semibold text-gray-900 tabular-nums">${{ Number(s.amount).toFixed(2) }}</span>
            </li>
          </ul>
        </BaseCard>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'
import PageHeader from '@/components/ui/PageHeader.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import EmptyState from '@/components/ui/EmptyState.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import { PhBus, PhTicket, PhChartBar, PhReceipt } from '@phosphor-icons/vue'

const auth   = useAuthStore()
const period = ref('semana')

const periods = [
  { label: 'Hoy',      value: 'hoy'    },
  { label: 'Semana',   value: 'semana' },
  { label: 'Mes',      value: 'mes'    },
  { label: 'Todo',     value: 'todo'   },
]

const PERIOD_PHRASES = { hoy: 'de hoy', semana: 'de los últimos 7 días', mes: 'de este mes', todo: 'desde el inicio' }
const periodPhrase = computed(() => PERIOD_PHRASES[period.value])

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

const metrics = computed(() => [
  { label: 'Entradas',       value: totalTickets.value },
  { label: 'Ventas de tours', value: chivaSales.value.length },
  { label: 'Tickets de negocio', value: bizTickets.value.length },
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
    labels:  labels.map(l => new Date(l + 'T12:00:00').toLocaleDateString('es-EC', { weekday: 'short', day: 'numeric', month: 'short' })),
    revenue: labels.map(l => revenueMap[l]),
    tickets: labels.map(l => ticketsMap[l]),
  }
})

const maxRevenue = computed(() => Math.max(...chartData.value.revenue, 1))
const barWidth   = (val, max) => `${Math.round((val / max) * 100)}%`

// ── Últimas ventas ───────────────────────────────────────────
const recentSales = computed(() => {
  const list = [
    ...chivaSales.value.map(s => ({
      id: s.id, amount: s.owner_gain,
      label: 'Venta de tour',
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
