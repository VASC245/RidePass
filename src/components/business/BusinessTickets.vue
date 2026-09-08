<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between flex-wrap gap-3">
      <h2 class="text-2xl font-bold text-gray-800">Tickets Vendidos</h2>
      <div class="flex gap-2">
        <button
          v-for="f in filters"
          :key="f.value"
          @click="activeFilter = f.value"
          class="px-4 py-2 rounded-xl text-sm font-semibold transition"
          :class="activeFilter === f.value ? 'bg-purple-600 text-white' : 'bg-white border border-gray-300 text-gray-600 hover:border-purple-400'"
        >{{ f.label }}</button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-12 text-gray-400">Cargando tickets...</div>
    <div v-else-if="filtered.length === 0" class="text-center py-12 text-gray-400">No hay tickets para mostrar.</div>
    <div v-else class="space-y-3">
      <div
        v-for="tk in filtered"
        :key="tk.id"
        class="bg-white rounded-2xl shadow-sm border p-5"
      >
        <div class="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <p class="font-bold text-gray-800">{{ tk.customer_name }}</p>
            <p class="text-sm text-gray-500">{{ tk.customer_email }} · {{ tk.customer_phone }}</p>
            <p class="text-sm text-gray-500">Cédula: {{ tk.customer_cedula }}</p>
            <p class="text-sm text-gray-600 mt-1 font-medium">{{ tk.business_events?.title }} — {{ formatDate(tk.business_events?.event_date) }}</p>
            <div class="flex items-center gap-3 mt-2 text-xs text-gray-500">
              <span>{{ tk.quantity }} entrada(s)</span>
              <span class="font-semibold text-gray-700">${{ tk.total_price }}</span>
              <span v-if="tk.payment_number">Ref: {{ tk.payment_number }}</span>
            </div>
          </div>
          <div class="flex flex-col items-end gap-2">
            <span
              class="text-xs px-2.5 py-1 rounded-full font-bold"
              :class="{
                'bg-yellow-100 text-yellow-700': tk.payment_status === 'pendiente',
                'bg-green-100 text-green-700':  tk.payment_status === 'verificado',
                'bg-red-100 text-red-600':      tk.payment_status === 'rechazado',
              }"
            >{{ tk.payment_status }}</span>
            <span
              v-if="tk.used"
              class="text-xs px-2.5 py-1 rounded-full bg-gray-200 text-gray-600 font-semibold"
            >Usado</span>
            <!-- Comprobante -->
            <button v-if="tk.payment_proof_path || tk.payment_proof_url" @click="openProof(tk)" class="text-xs text-purple-600 hover:underline font-semibold">Ver comprobante</button>
          </div>
        </div>

        <!-- Acciones -->
        <div v-if="tk.payment_status === 'pendiente'" class="flex gap-2 mt-4">
          <button @click="setStatus(tk.id, 'verificado')" class="flex-1 py-2 rounded-xl bg-green-600 hover:bg-green-700 text-white text-sm font-semibold transition">
            ✓ Aprobar
          </button>
          <button @click="setStatus(tk.id, 'rechazado')" class="flex-1 py-2 rounded-xl bg-red-500 hover:bg-red-600 text-white text-sm font-semibold transition">
            ✗ Rechazar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'

const authStore = useAuthStore()
const loading = ref(true)
const tickets = ref([])
const activeFilter = ref('pendiente')

const filters = [
  { label: 'Pendientes', value: 'pendiente' },
  { label: 'Verificados', value: 'verificado' },
  { label: 'Rechazados', value: 'rechazado' },
  { label: 'Todos', value: 'todos' },
]

const filtered = computed(() =>
  activeFilter.value === 'todos' ? tickets.value : tickets.value.filter(t => t.payment_status === activeFilter.value)
)

const formatDate = (d) => d ? new Date(d).toLocaleDateString('es-EC', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '–'

// El bucket de comprobantes es privado: se abre con URL firmada
const openProof = async (tk) => {
  let url = ''
  if (tk.payment_proof_path) {
    const { data } = await supabase.storage
      .from('comprobantes')
      .createSignedUrl(tk.payment_proof_path, 3600)
    url = data?.signedUrl || ''
  }
  // respaldo para tickets antiguos con URL pública completa
  if (!url && tk.payment_proof_url?.startsWith('http')) url = tk.payment_proof_url
  if (url) window.open(url, '_blank')
  else alert('No se pudo abrir el comprobante.')
}

onMounted(fetchTickets)

async function fetchTickets() {
  loading.value = true
  const uid = authStore.user?.id
  const { data } = await supabase
    .from('business_tickets')
    .select('*, business_events(title, event_date)')
    .eq('owner_id', uid)
    .order('created_at', { ascending: false })
  tickets.value = data ?? []
  loading.value = false
}

// review_business_ticket valida que el ticket sea de este negocio y, si se
// rechaza, libera el cupo del evento.
const setStatus = async (id, status) => {
  const { error } = await supabase.rpc('review_business_ticket', { p_ticket_id: id, p_status: status })
  if (error) {
    console.error('review_business_ticket:', error.message)
    alert('No se pudo actualizar el ticket.')
  }
  await fetchTickets()
}
</script>
