<template>
  <div class="space-y-4">
    <div class="rounded-xl bg-gray-50 p-4 text-sm">
      <div class="flex items-center justify-between">
        <span class="text-gray-600">Total a cobrar <span class="text-xs text-gray-500">(incluye cargo por servicio)</span></span>
        <strong class="text-base text-orange-700 tabular-nums">${{ total }}</strong>
      </div>
      <p class="mt-3 leading-relaxed text-gray-700">
        Te llevamos a la página segura de PayPhone para pagar con tu tarjeta de débito o crédito.
        Tus asientos quedan apartados mientras pagas; al terminar vuelves aquí con tu ticket.
      </p>
      <p class="mt-2 text-xs text-gray-600">Tienes 10 minutos para completar el pago. No cierres la página de PayPhone hasta que te devuelva aquí.</p>
    </div>

    <p v-if="error" role="alert" class="rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-600">{{ error }}</p>

    <div class="flex gap-3 pt-1">
      <button type="button" class="btn-secondary flex-1" :disabled="loading" @click="$emit('back')">Volver</button>
      <button type="button" class="btn-primary flex-[2] disabled:opacity-50" :disabled="loading || disabled" @click="pay">
        {{ loading ? 'Abriendo PayPhone...' : `Pagar $${total} con PayPhone` }}
      </button>
    </div>
    <p class="text-center text-xs text-gray-500">Pago procesado por PayPhone. Los datos de tu tarjeta nunca pasan por chivaspass.</p>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { supabase } from '@/lib/supabase'
import { preparePayphone } from '@/lib/reservations'

const props = defineProps({
  type:     { type: String, required: true },     // 'tour' | 'business'
  payload:  { type: Function, required: true },   // () => payload para el servidor
  total:    { type: [String, Number], required: true },
  disabled: { type: Boolean, default: false },
})
defineEmits(['back'])

const loading = ref(false)
const error   = ref('')

const pay = async () => {
  error.value = ''
  loading.value = true
  try {
    const { payUrl } = await preparePayphone(supabase, props.type, props.payload())
    // Misma pestaña: PayPhone no permite abrirse en iframes ni webviews.
    window.location.assign(payUrl)
  } catch (e) {
    error.value = e.message
    loading.value = false
  }
}
</script>

<style scoped>
/* Mismos botones que los modales de reserva (allí son estilos locales). */
.btn-primary {
  background: #ea580c;
  color: #fff;
  font-weight: 700;
  padding: 0.75rem 1rem;
  border-radius: 10px;
  transition: background .15s, transform .1s;
}
.btn-primary:hover:not(:disabled) { background: #c2410c; }
.btn-primary:active:not(:disabled) { transform: scale(0.98); }
.btn-secondary {
  border: 1px solid #e5e7eb;
  color: #4b5563;
  font-weight: 600;
  padding: 0.75rem 1rem;
  border-radius: 10px;
  transition: background .15s;
}
.btn-secondary:hover { background: #f9fafb; }
</style>
