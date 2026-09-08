<template>
  <Transition name="modal">
    <div v-if="show"
      class="fixed inset-0 z-[60] flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4"
      @click.self="$emit('close')"
    >
      <div class="bg-white w-full sm:max-w-sm rounded-t-2xl sm:rounded-2xl shadow-2xl p-8 space-y-5">
        <!-- Header -->
        <div class="text-center">
          <div class="w-14 h-14 bg-orange-50 rounded-2xl flex items-center justify-center mx-auto mb-3">
            <PhTicket :size="28" weight="duotone" class="text-orange-600" />
          </div>
          <h2 class="text-xl font-extrabold text-gray-900">Crea tu cuenta gratis</h2>
          <p class="text-sm text-gray-500 mt-1">Para comprar y gestionar tus entradas</p>
        </div>

        <!-- Beneficios -->
        <ul class="space-y-2.5 text-sm text-gray-600">
          <li class="flex items-center gap-2.5">
            <PhCheckCircle :size="18" weight="fill" class="text-orange-600 shrink-0" />
            Guarda todas tus entradas en un lugar
          </li>
          <li class="flex items-center gap-2.5">
            <PhCheckCircle :size="18" weight="fill" class="text-orange-600 shrink-0" />
            Accede a tu QR en cualquier momento
          </li>
          <li class="flex items-center gap-2.5">
            <PhCheckCircle :size="18" weight="fill" class="text-orange-600 shrink-0" />
            Comparte por WhatsApp con un toque
          </li>
        </ul>

        <!-- Acciones -->
        <div class="space-y-3">
          <RouterLink to="/cuenta/registro" @click="$emit('close')"
            class="w-full flex items-center justify-center bg-orange-600 hover:bg-orange-700 text-white font-bold py-3 rounded-[10px] transition-colors">
            Crear cuenta gratis
          </RouterLink>
          <RouterLink to="/cuenta/login" @click="$emit('close')"
            class="w-full flex items-center justify-center border border-gray-200 hover:border-orange-400 text-gray-600 font-semibold py-3 rounded-[10px] transition-colors text-sm">
            Ya tengo cuenta
          </RouterLink>
          <button @click="$emit('continue-as-guest')"
            class="w-full text-xs text-gray-400 hover:text-gray-600 py-2 transition-colors">
            Continuar sin cuenta (no podrás ver tus tickets después)
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { PhTicket, PhCheckCircle } from '@phosphor-icons/vue'
defineProps({ show: Boolean })
defineEmits(['close', 'continue-as-guest'])
</script>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.2s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-active > div, .modal-leave-active > div { transition: transform 0.3s cubic-bezier(0.4,0,0.2,1); }
.modal-enter-from > div, .modal-leave-to > div { transform: translateY(40px); }
</style>
