<template>
  <div class="max-w-2xl mx-auto px-4 py-10 space-y-6">
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-extrabold text-gray-900">Mis entradas</h1>
      <RouterLink to="/" class="text-sm text-orange-600 font-semibold hover:underline">Comprar más</RouterLink>
    </div>

    <!-- Filtros -->
    <div class="flex gap-2 flex-wrap">
      <button v-for="f in filters" :key="f.value" @click="activeFilter = f.value"
        class="px-4 py-2 rounded-xl text-sm font-semibold transition"
        :class="activeFilter === f.value ? 'bg-orange-600 text-white' : 'bg-white border border-gray-200 text-gray-600 hover:border-orange-400'">
        {{ f.label }}
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex flex-col items-center py-16 gap-3">
      <div class="w-10 h-10 border-4 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
      <p class="text-gray-400 text-sm">Cargando tus entradas...</p>
    </div>

    <!-- Error -->
    <p v-else-if="loadError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">
      {{ loadError }}
    </p>

    <!-- Sin tickets -->
    <div v-else-if="filtered.length === 0" class="text-center py-16">
      <PhTicket :size="48" class="mx-auto mb-3 text-gray-300" />
      <p class="font-bold text-gray-700 text-lg">No tienes entradas {{ activeFilter !== 'todos' ? 'en esta categoría' : 'aún' }}</p>
      <p class="text-gray-400 text-sm mt-1">Explora los tours y atracciones disponibles</p>
      <RouterLink to="/" class="mt-4 inline-block bg-orange-600 hover:bg-orange-700 text-white font-bold px-6 py-3 rounded-xl transition">
        Ver tours y atracciones
      </RouterLink>
    </div>

    <!-- Lista de tickets -->
    <div v-else class="space-y-4">
      <div v-for="tk in filtered" :key="tk.key"
        class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-md transition">

        <!-- Cabecera con color por estado -->
        <div class="px-5 py-3 flex items-center justify-between gap-3"
          :class="{
            'bg-yellow-50 border-b border-yellow-100': tk.status === 'pendiente',
            'bg-green-50 border-b border-green-100':  tk.status === 'verificado',
            'bg-red-50 border-b border-red-100':      tk.status === 'rechazado',
          }">
          <span class="text-xs font-bold uppercase tracking-wide"
            :class="{
              'text-yellow-700': tk.status === 'pendiente',
              'text-green-700':  tk.status === 'verificado',
              'text-red-600':    tk.status === 'rechazado',
            }">
            {{ statusLabel(tk.status) }}
          </span>
          <div class="flex items-center gap-2">
            <span class="text-xs bg-white/70 text-gray-600 font-semibold px-2 py-0.5 rounded-full border border-gray-200">
              {{ tk.kind === 'tour' ? 'Tour en chiva' : 'Atracción' }}
            </span>
            <span v-if="tk.used" class="text-xs bg-gray-200 text-gray-600 font-bold px-2 py-0.5 rounded-full">Usada</span>
          </div>
        </div>

        <div class="p-5 flex items-start justify-between gap-4">
          <div class="flex-1 min-w-0">
            <p class="font-extrabold text-gray-900 text-base truncate">{{ tk.title }}</p>
            <p class="text-sm text-gray-500 mt-0.5">{{ formatDate(tk.date) }}</p>
            <p class="text-sm text-gray-400 mt-1">
              <template v-if="tk.kind === 'tour'">Asientos {{ tk.seats }}</template>
              <template v-else>{{ tk.quantity }} entrada(s)</template>
              · <strong class="text-gray-700">${{ tk.total }}</strong>
            </p>
            <p v-if="tk.ref" class="text-xs text-gray-400 mt-0.5">Ref: {{ tk.ref }}</p>
          </div>

          <!-- Acciones -->
          <div v-if="tk.status === 'verificado' && !tk.used" class="flex flex-col items-end gap-2 shrink-0">
            <RouterLink :to="`/ticket/${tk.id}`"
              class="bg-orange-600 hover:bg-orange-700 text-white text-xs font-bold px-4 py-2 rounded-xl transition">
              Ver QR
            </RouterLink>
            <a :href="whatsAppUrl(tk)" target="_blank" rel="noopener"
              class="bg-[#25D366] text-white text-xs font-bold px-4 py-2 rounded-xl transition flex items-center gap-1.5">
              <PhWhatsappLogo :size="14" weight="fill" />
              WhatsApp
            </a>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { PhTicket, PhWhatsappLogo } from '@phosphor-icons/vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'

const auth      = useAuthStore()
const loading   = ref(true)
const loadError = ref('')
const tickets   = ref([])
const activeFilter = ref('todos')

const filters = [
  { label: 'Todos',       value: 'todos'      },
  { label: 'Pendientes',  value: 'pendiente'  },
  { label: 'Verificados', value: 'verificado' },
]

const filtered = computed(() =>
  activeFilter.value === 'todos'
    ? tickets.value
    : tickets.value.filter(t => t.status === activeFilter.value)
)

const formatDate = (d) => d
  ? new Date(d).toLocaleDateString('es-EC', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
  : 'Fecha por confirmar'

const statusLabel = (s) => ({
  pendiente:  'Pago pendiente de verificación',
  verificado: 'Entrada válida',
  rechazado:  'Pago rechazado',
}[s] ?? s)

const whatsAppUrl = (tk) => {
  const detail = tk.kind === 'tour' ? `Asientos ${tk.seats}` : `${tk.quantity} entrada(s)`
  const msg = [
    `Mi entrada: ${tk.title}`,
    formatDate(tk.date),
    `${detail} · $${tk.total}`,
    '',
    'Ver QR:',
    `${window.location.origin}/ticket/${tk.id}`,
  ].join('\n')
  return `https://wa.me/?text=${encodeURIComponent(msg)}`
}

// get_my_tickets devuelve en un solo formato las entradas de atracciones y
// de tours en chiva del correo autenticado (sin cédula, teléfono ni comprobante).
const money = (n) => Number(n ?? 0).toFixed(2)

const normalize = (r) => {
  let seats = r.seats
  if (typeof seats === 'string') { try { seats = JSON.parse(seats) } catch { seats = [] } }
  return {
    key: `${r.kind}-${r.id}`, id: r.id, kind: r.kind,
    title: r.title ?? (r.kind === 'tour' ? 'Tour en chiva' : 'Atracción'),
    place: r.place, date: r.date,
    quantity: r.quantity ?? 1,
    seats: Array.isArray(seats) && seats.length ? seats.join(', ') : 'por asignar',
    total: money(r.total), ref: r.ref,
    status: r.status, used: !!r.used,
  }
}

onMounted(async () => {
  if (!auth.user?.email) { loading.value = false; return }
  const { data, error } = await supabase.rpc('get_my_tickets')
  if (error) {
    console.error('get_my_tickets:', error.message)
    loadError.value = 'No se pudieron cargar tus entradas. Intenta de nuevo.'
  }
  tickets.value = (data ?? []).map(normalize)
  loading.value = false
})
</script>
