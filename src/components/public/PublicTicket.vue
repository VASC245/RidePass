<template>
  <div class="min-h-screen bg-gray-50 flex items-center justify-center p-4">

    <!-- Cargando -->
    <div v-if="loading" class="flex flex-col items-center gap-4">
      <div class="w-10 h-10 border-4 border-orange-500 border-t-transparent rounded-full animate-spin"></div>
      <p class="text-gray-400 font-medium">Cargando ticket...</p>
    </div>

    <!-- No encontrado -->
    <div v-else-if="!ticket" class="text-center max-w-sm">
      <div class="w-14 h-14 mx-auto mb-4 rounded-full bg-gray-200 flex items-center justify-center">
        <PhTicket :size="26" class="text-gray-500" />
      </div>
      <h2 class="text-xl font-bold text-gray-800">Ticket no disponible</h2>
      <p class="text-gray-500 mt-2 text-sm">
        El enlace puede ser incorrecto, o el pago todavía no fue verificado por el vendedor.
        Cuando lo verifique, este mismo enlace mostrará tu código QR.
      </p>
      <RouterLink to="/" class="mt-6 inline-block text-orange-600 font-semibold hover:underline">Volver al inicio</RouterLink>
    </div>

    <!-- Ticket válido -->
    <div v-else class="w-full max-w-sm">

      <div
        class="rounded-t-3xl p-5 text-center text-white"
        :class="ticket.used ? 'bg-gray-600' : 'bg-gray-900'"
      >
        <p class="text-[11px] font-semibold tracking-[0.2em] uppercase opacity-70">ChivaPass</p>
        <h1 class="text-xl font-extrabold mt-1">
          {{ ticket.used ? (isTour ? 'Ticket usado' : 'Entrada usada') : (isTour ? 'Ticket de embarque' : 'Entrada válida') }}
        </h1>
        <p class="text-sm opacity-80 mt-1">Baños de Agua Santa</p>
      </div>

      <div class="bg-white rounded-b-3xl shadow-xl overflow-hidden">

        <div class="flex items-center">
          <div class="w-6 h-6 rounded-full bg-gray-50 -ml-3 border-r border-gray-100"></div>
          <div class="flex-1 border-t border-dashed border-gray-200 mx-2"></div>
          <div class="w-6 h-6 rounded-full bg-gray-50 -mr-3 border-l border-gray-100"></div>
        </div>

        <div class="px-6 pt-4 pb-2 flex flex-col items-center">
          <div class="bg-white p-3 rounded-2xl shadow-sm border border-gray-100 inline-block" :class="ticket.used && 'opacity-40'">
            <img :src="qrUrl" class="w-52 h-52 rounded-lg" alt="Código QR" />
          </div>
          <p class="text-xs text-gray-400 mt-2">
            {{ isTour ? 'Muéstralo al conductor al abordar' : 'Muéstralo al ingresar' }}
          </p>
        </div>

        <div class="px-6 pb-6 space-y-3 mt-4">
          <div class="bg-gray-50 rounded-2xl p-4 space-y-2 text-sm">
            <div class="flex justify-between gap-4">
              <span class="text-gray-500">{{ isTour ? 'Tour' : 'Evento' }}</span>
              <strong class="text-gray-900 text-right">{{ ticket.title }}</strong>
            </div>
            <div class="flex justify-between gap-4">
              <span class="text-gray-500">{{ isTour ? 'Chiva' : 'Lugar' }}</span>
              <strong class="text-gray-900 text-right">{{ ticket.place }}</strong>
            </div>
            <div class="flex justify-between gap-4">
              <span class="text-gray-500">{{ isTour ? 'Salida' : 'Fecha' }}</span>
              <strong class="text-gray-900 text-right">{{ dateLabel }}</strong>
            </div>
            <div class="flex justify-between gap-4">
              <span class="text-gray-500">Titular</span>
              <strong class="text-gray-900 text-right">{{ ticket.customer_name }}</strong>
            </div>
            <div class="flex justify-between gap-4">
              <span class="text-gray-500">{{ isTour ? 'Asientos' : 'Entradas' }}</span>
              <strong class="text-gray-900 text-right">{{ isTour ? seatList : ticket.quantity }}</strong>
            </div>
            <div class="flex justify-between border-t border-gray-200 pt-2 mt-1">
              <span class="text-gray-500">Total pagado</span>
              <strong class="text-orange-700">${{ Number(ticket.total).toFixed(2) }}</strong>
            </div>
          </div>

          <p class="text-center text-xs text-gray-400 pt-2">
            ID: {{ ticket.id.slice(0, 8).toUpperCase() }}
          </p>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import QRCode from 'qrcode'
import { PhTicket } from '@phosphor-icons/vue'
import { supabase } from '@/lib/supabase'

const route   = useRoute()
const loading = ref(true)
const ticket  = ref(null)
const qrUrl   = ref('')

const isTour = computed(() => ticket.value?.kind === 'tour')

const seatList = computed(() => {
  let s = ticket.value?.seats
  if (typeof s === 'string') { try { s = JSON.parse(s) } catch { s = [] } }
  return Array.isArray(s) ? s.join(', ') : '–'
})

const dateLabel = computed(() => {
  const d = ticket.value?.date
  if (!d) return '–'
  return new Date(d).toLocaleDateString('es-EC', {
    weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit',
  })
})

// get_public_ticket devuelve solo los campos necesarios para mostrar el
// ticket (sin cédula, teléfono ni comprobante) y únicamente si está pagado.
onMounted(async () => {
  const id = String(route.params.id ?? '')
  if (/^[0-9a-f-]{36}$/i.test(id)) {
    const { data, error } = await supabase.rpc('get_public_ticket', { p_id: id })
    if (error) console.error('get_public_ticket:', error.message)
    if (data) {
      ticket.value = data
      if (data.qr_payload) {
        qrUrl.value = await QRCode.toDataURL(data.qr_payload, { width: 300, margin: 1 })
      }
    }
  }
  loading.value = false
})
</script>
