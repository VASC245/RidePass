<template>
  <div class="max-w-2xl mx-auto px-4 py-10 space-y-6">
    <div class="flex items-center justify-between">
      <h1 class="text-2xl font-extrabold text-gray-900">Mis entradas</h1>
      <RouterLink to="/" class="text-sm text-indigo-600 font-semibold hover:underline">+ Comprar más</RouterLink>
    </div>

    <!-- Filtros -->
    <div class="flex gap-2 flex-wrap">
      <button v-for="f in filters" :key="f.value" @click="activeFilter = f.value"
        class="px-4 py-2 rounded-xl text-sm font-semibold transition"
        :class="activeFilter === f.value ? 'bg-indigo-600 text-white' : 'bg-white border border-gray-200 text-gray-600 hover:border-indigo-400'">
        {{ f.label }}
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="flex flex-col items-center py-16 gap-3">
      <div class="w-10 h-10 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
      <p class="text-gray-400 text-sm">Cargando tus entradas...</p>
    </div>

    <!-- Sin tickets -->
    <div v-else-if="filtered.length === 0" class="text-center py-16">
      <p class="text-5xl mb-3">🎟️</p>
      <p class="font-bold text-gray-700 text-lg">No tienes entradas {{ activeFilter !== 'todos' ? 'en esta categoría' : 'aún' }}</p>
      <p class="text-gray-400 text-sm mt-1">Explora las atracciones y tours disponibles</p>
      <RouterLink to="/" class="mt-4 inline-block bg-indigo-600 hover:bg-indigo-700 text-white font-bold px-6 py-3 rounded-xl transition">
        Ver tours y atracciones →
      </RouterLink>
    </div>

    <!-- Lista de tickets -->
    <div v-else class="space-y-4">
      <div v-for="tk in filtered" :key="tk.id"
        class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-md transition">

        <!-- Header con color por estado -->
        <div class="px-5 py-3 flex items-center justify-between"
          :class="{
            'bg-yellow-50 border-b border-yellow-100': tk.payment_status === 'pendiente',
            'bg-green-50 border-b border-green-100':  tk.payment_status === 'verificado',
            'bg-red-50 border-b border-red-100':      tk.payment_status === 'rechazado',
          }">
          <span class="text-xs font-bold uppercase tracking-wide"
            :class="{
              'text-yellow-700': tk.payment_status === 'pendiente',
              'text-green-700':  tk.payment_status === 'verificado',
              'text-red-600':    tk.payment_status === 'rechazado',
            }">
            {{ statusLabel(tk.payment_status) }}
          </span>
          <span v-if="tk.used" class="text-xs bg-gray-200 text-gray-600 font-bold px-2 py-0.5 rounded-full">Usada</span>
        </div>

        <div class="p-5 flex items-start justify-between gap-4">
          <div class="flex-1 min-w-0">
            <p class="font-extrabold text-gray-900 text-base truncate">{{ tk.business_events?.title }}</p>
            <p class="text-sm text-gray-500 mt-0.5">{{ formatDate(tk.business_events?.event_date) }}</p>
            <p class="text-sm text-gray-400 mt-1">{{ tk.quantity }} entrada(s) · <strong class="text-gray-700">${{ tk.total_price }}</strong></p>
            <p v-if="tk.payment_number" class="text-xs text-gray-400 mt-0.5">Ref: {{ tk.payment_number }}</p>
          </div>

          <!-- Acciones -->
          <div class="flex flex-col items-end gap-2 shrink-0">
            <RouterLink v-if="tk.payment_status === 'verificado'"
              :to="`/ticket/${tk.id}`"
              class="bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold px-4 py-2 rounded-xl transition">
              Ver QR →
            </RouterLink>
            <a v-if="tk.payment_status === 'verificado'"
              :href="whatsAppUrl(tk)"
              target="_blank"
              class="bg-[#25D366] text-white text-xs font-bold px-4 py-2 rounded-xl transition flex items-center gap-1">
              <svg class="w-3.5 h-3.5 fill-white" viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347z"/><path d="M12 0C5.373 0 0 5.373 0 12c0 2.127.558 4.126 1.532 5.857L.054 23.25a.75.75 0 0 0 .936.935l5.446-1.476A11.952 11.952 0 0 0 12 24c6.627 0 12-5.373 12-12S18.627 0 12 0zm0 22a9.956 9.956 0 0 1-5.13-1.418l-.36-.217-3.735 1.013 1.018-3.636-.235-.374A9.956 9.956 0 0 1 2 12C2 6.477 6.477 2 12 2s10 4.477 10 10-4.477 10-10 10z"/></svg>
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
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'

const auth    = useAuthStore()
const loading = ref(true)
const tickets = ref([])
const activeFilter = ref('todos')

const filters = [
  { label: 'Todos',      value: 'todos'     },
  { label: 'Pendientes', value: 'pendiente' },
  { label: 'Verificados', value: 'verificado' },
]

const filtered = computed(() =>
  activeFilter.value === 'todos'
    ? tickets.value
    : tickets.value.filter(t => t.payment_status === activeFilter.value)
)

const formatDate = (d) => d
  ? new Date(d).toLocaleDateString('es-EC', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
  : '–'

const statusLabel = (s) => ({ pendiente: '⏳ Pago pendiente de verificación', verificado: '✓ Entrada válida', rechazado: '✗ Pago rechazado' }[s] ?? s)

const whatsAppUrl = (tk) => {
  const msg = [
    `🎟️ *Mi entrada: ${tk.business_events?.title}*`,
    `📅 ${formatDate(tk.business_events?.event_date)}`,
    `🎫 ${tk.quantity} entrada(s) · $${tk.total_price}`,
    ``,
    `👇 Ver QR:`,
    `${window.location.origin}/ticket/${tk.id}`,
  ].join('\n')
  return `https://wa.me/?text=${encodeURIComponent(msg)}`
}

onMounted(async () => {
  const { data } = await supabase
    .from('business_tickets')
    .select('*, business_events(title, event_date)')
    .eq('customer_email', auth.user?.email)
    .order('created_at', { ascending: false })
  tickets.value = data ?? []
  loading.value = false
})
</script>
