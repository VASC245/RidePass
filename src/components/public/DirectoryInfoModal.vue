<template>
  <Transition name="modal">
    <div v-if="biz"
      class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4"
      @click.self="$emit('close')">

      <div class="bg-white w-full sm:max-w-lg rounded-t-2xl sm:rounded-2xl max-h-[93vh] overflow-y-auto shadow-2xl">

        <div class="relative aspect-[16/9] bg-gray-100">
          <img :src="biz.image || placeholderFor(biz.id)" :alt="biz.name" class="w-full h-full object-cover" />
          <button @click="$emit('close')"
            class="absolute top-4 right-4 w-9 h-9 flex items-center justify-center rounded-full bg-white/90 hover:bg-white text-gray-700 shadow transition-colors"
            aria-label="Cerrar">
            <PhX :size="16" weight="bold" />
          </button>
        </div>

        <div class="p-6">
          <p class="text-xs font-bold text-orange-700 uppercase tracking-wide">{{ catLabel }}</p>
          <h2 class="mt-1 text-xl font-extrabold text-gray-900">{{ biz.name }}</h2>

          <p v-if="biz.address" class="mt-2 text-sm text-gray-600 flex items-center gap-1.5">
            <PhMapPin :size="15" class="shrink-0 text-gray-400" />
            {{ biz.address }}
          </p>

          <p class="mt-3 text-[15px] text-gray-600 leading-relaxed">{{ biz.description }}</p>

          <div class="mt-5 bg-gray-50 border border-gray-200 rounded-xl p-4">
            <p class="text-sm text-gray-700">
              Esta atracción todavía no vende entradas en chivaspass. Puedes visitarla y pagar en el lugar.
            </p>
          </div>

          <div class="mt-4 border-t border-gray-100 pt-4">
            <p class="font-bold text-gray-900 text-sm">¿Este negocio es tuyo?</p>
            <p class="mt-1 text-sm text-gray-600">
              Afíliate gratis, publica tus eventos y empieza a vender entradas con código QR.
            </p>
            <RouterLink to="/panel/register" @click="$emit('close')"
              class="mt-3 inline-flex items-center gap-2 bg-orange-600 hover:bg-orange-700 text-white font-bold text-sm px-4 py-2.5 rounded-[10px] transition-colors">
              Afiliar mi negocio
              <PhArrowRight :size="14" weight="bold" />
            </RouterLink>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { computed } from 'vue'
import { PhX, PhMapPin, PhArrowRight } from '@phosphor-icons/vue'
import { placeholderFor } from '@/lib/placeholderImage'

const props = defineProps({ biz: { type: Object, default: null } })
defineEmits(['close'])

const catLabel = computed(() =>
  ({ cascada: 'Cascada', deporte: 'Deporte extremo', termas: 'Termas', restaurante: 'Restaurante', otro: 'Atracción' }[props.biz?.category] ?? 'Atracción')
)
</script>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.25s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-active > div, .modal-leave-active > div { transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1); }
.modal-enter-from > div, .modal-leave-to > div { transform: translateY(40px); }
</style>
