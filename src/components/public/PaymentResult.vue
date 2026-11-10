<template>
  <div class="flex min-h-[80vh] items-center justify-center bg-gray-50 p-4">
    <div class="w-full max-w-md rounded-xl border border-gray-200 bg-white p-6 sm:p-8">

      <!-- Confirmando -->
      <div v-if="state === 'loading'" class="flex flex-col items-center gap-4 py-8 text-center" aria-live="polite">
        <div class="size-10 animate-spin rounded-full border-4 border-brand-600 border-t-transparent" aria-hidden="true" />
        <p class="font-semibold text-gray-900">Confirmando tu pago con PayPhone</p>
        <p class="text-sm text-gray-600">No cierres esta página. Tarda unos segundos.</p>
      </div>

      <!-- Pagado -->
      <div v-else-if="state === 'paid'" class="text-center">
        <div class="mx-auto mb-4 flex size-14 items-center justify-center rounded-full bg-ok-50 text-ok-700">
          <PhCheckCircle :size="30" weight="fill" />
        </div>
        <h1 class="text-2xl font-bold tracking-[-0.015em] text-gray-900">Pago confirmado</h1>
        <p class="mt-1 text-sm text-gray-600">Tu ticket ya está activo. Te enviamos una copia al correo.</p>

        <div v-if="qrUrl" class="mt-5 inline-block rounded-xl bg-gray-50 p-5">
          <p class="mb-3 text-sm font-medium text-gray-600">{{ result.kind === 'tour' ? 'Tu QR de embarque' : 'Tu QR de ingreso' }}</p>
          <img :src="qrUrl" class="mx-auto w-48 rounded-lg" alt="Código QR del ticket" />
          <p class="mt-3 text-xs text-gray-600">{{ result.kind === 'tour' ? 'Muéstralo al conductor al abordar' : 'Muéstralo en la entrada' }}</p>
        </div>

        <dl class="mt-5 space-y-2 rounded-xl border border-gray-200 p-4 text-left text-sm">
          <div v-if="result.title" class="flex justify-between gap-4"><dt class="text-gray-600">{{ result.kind === 'tour' ? 'Tour' : 'Evento' }}</dt><dd class="text-right font-semibold text-gray-900">{{ result.title }}</dd></div>
          <div v-if="result.seats?.length" class="flex justify-between gap-4"><dt class="text-gray-600">Asientos</dt><dd class="font-semibold text-gray-900 tabular-nums">{{ result.seats.join(', ') }}</dd></div>
          <div v-else-if="result.quantity" class="flex justify-between gap-4"><dt class="text-gray-600">Entradas</dt><dd class="font-semibold text-gray-900 tabular-nums">{{ result.quantity }}</dd></div>
          <div v-if="result.date" class="flex justify-between gap-4"><dt class="text-gray-600">{{ result.kind === 'tour' ? 'Salida' : 'Fecha' }}</dt><dd class="font-semibold text-gray-900">{{ formatDate(result.date) }}</dd></div>
          <div class="flex justify-between gap-4 border-t border-gray-200 pt-2"><dt class="text-gray-600">Total pagado</dt><dd class="font-bold text-gray-900 tabular-nums">${{ money(result.total) }}</dd></div>
          <div v-if="result.chargeId" class="flex justify-between gap-4"><dt class="text-gray-600">Referencia PayPhone</dt><dd class="font-mono text-gray-900">{{ result.chargeId }}</dd></div>
        </dl>

        <a v-if="result.ticketUrl" :href="result.ticketUrl"
          class="mt-5 inline-flex h-12 w-full items-center justify-center rounded-lg bg-brand-600 px-5 font-semibold text-white transition-colors duration-150 hover:bg-brand-700">
          Abrir mi ticket
        </a>
        <RouterLink to="/tours" class="mt-3 block text-sm font-semibold text-brand-700 hover:underline">Ver más tours</RouterLink>
      </div>

      <!-- Pagado pero hay que conciliar -->
      <div v-else-if="state === 'review'" class="text-center" role="alert">
        <div class="mx-auto mb-4 flex size-14 items-center justify-center rounded-full bg-warn-50 text-warn-700">
          <PhWarningCircle :size="30" />
        </div>
        <h1 class="text-xl font-bold text-gray-900">Tu pago está aprobado, falta emitir el ticket</h1>
        <p class="mt-2 text-sm text-gray-700">{{ message }}</p>
        <p v-if="result.chargeId" class="mt-4 rounded-lg bg-gray-50 px-4 py-3 font-mono text-sm text-gray-900">Referencia: {{ result.chargeId }}</p>
        <RouterLink to="/contacto" class="mt-5 inline-flex h-12 w-full items-center justify-center rounded-lg bg-brand-600 px-5 font-semibold text-white hover:bg-brand-700">
          Contactar a chivaspass
        </RouterLink>
      </div>

      <!-- Reintentable (PayPhone no respondió, o está en proceso) -->
      <div v-else-if="state === 'retry'" class="text-center" role="alert">
        <div class="mx-auto mb-4 flex size-14 items-center justify-center rounded-full bg-gray-100 text-gray-600">
          <PhArrowClockwise :size="28" />
        </div>
        <h1 class="text-xl font-bold text-gray-900">Todavía no pudimos confirmar tu pago</h1>
        <p class="mt-2 text-sm text-gray-700">{{ message }}</p>
        <p class="mt-2 text-xs text-gray-600">Reintentar no te cobra dos veces.</p>
        <button type="button" class="mt-5 inline-flex h-12 w-full items-center justify-center rounded-lg bg-brand-600 px-5 font-semibold text-white hover:bg-brand-700" @click="confirm">
          Reintentar
        </button>
      </div>

      <!-- No se cobró -->
      <div v-else class="text-center" role="alert">
        <div class="mx-auto mb-4 flex size-14 items-center justify-center rounded-full bg-gray-100 text-gray-600">
          <PhXCircle :size="30" />
        </div>
        <h1 class="text-xl font-bold text-gray-900">{{ state === 'cancelled' ? 'Pago cancelado' : 'El pago no se completó' }}</h1>
        <p class="mt-2 text-sm text-gray-700">{{ message }}</p>
        <RouterLink to="/tours" class="mt-5 inline-flex h-12 w-full items-center justify-center rounded-lg bg-brand-600 px-5 font-semibold text-white hover:bg-brand-700">
          Volver a reservar
        </RouterLink>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import QRCode from 'qrcode'
import { PhArrowClockwise, PhCheckCircle, PhWarningCircle, PhXCircle } from '@phosphor-icons/vue'
import { supabase } from '@/lib/supabase'
import { confirmPayphone } from '@/lib/reservations'
import { money } from '@/lib/fees'

const route = useRoute()
const state   = ref('loading')   // loading | paid | review | retry | failed | cancelled
const message = ref('')
const result  = ref({})
const qrUrl   = ref('')

// PayPhone vuelve con ?id=<número>&clientTransactionId=<nuestro id>.
// La cancelación vuelve con ?cancelado=1&tx=<nuestro id> (lo armamos al preparar).
const q = route.query
const clientTransactionId = String(q.clientTransactionId || q.tx || '')
const payphoneId = Number(q.id)
const cancelled = q.cancelado === '1'

// "Estamos confirmando" (otra pestaña o recarga en curso): reintentos cortos.
// PayPhone revierte a los 5 minutos si no se confirma, así que no se espera más.
let autoRetries = 0
const MAX_AUTO_RETRIES = 4

const formatDate = (d) =>
  new Date(d).toLocaleString('es-EC', { timeZone: 'America/Guayaquil', dateStyle: 'long', timeStyle: 'short' })

const confirm = async () => {
  if (!clientTransactionId || (!cancelled && !payphoneId)) {
    state.value = 'failed'
    message.value = 'Este enlace de pago no es válido. Si pagaste, revisa tu correo o contáctanos con tu referencia de PayPhone.'
    return
  }
  state.value = 'loading'
  const data = await confirmPayphone(supabase, cancelled
    ? { clientTransactionId, cancelled: true }
    : { clientTransactionId, id: payphoneId })

  result.value = data
  message.value = data.message || ''

  if (data.success) {
    if (data.qrPayload) qrUrl.value = await QRCode.toDataURL(data.qrPayload, { width: 320, margin: 1 })
    state.value = 'paid'
  } else if (data.needsReview) {
    state.value = 'review'
  } else if (data.retry) {
    if (autoRetries < MAX_AUTO_RETRIES) {
      autoRetries += 1
      setTimeout(confirm, 2500 * autoRetries)
      return
    }
    state.value = 'retry'
  } else {
    state.value = data.cancelled ? 'cancelled' : 'failed'
  }
}

onMounted(confirm)
</script>
