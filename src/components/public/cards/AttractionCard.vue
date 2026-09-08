<template>
  <article
    class="group cursor-pointer rounded-2xl bg-white border border-gray-200 overflow-hidden hover:shadow-lg hover:shadow-gray-900/8 hover:-translate-y-0.5 transition-all duration-200"
    @click="$emit('open', biz)"
  >
    <div class="aspect-[16/9] overflow-hidden bg-gray-100">
      <img
        :src="biz.image_url || biz.image || placeholderFor(biz.id)"
        :alt="biz.name"
        loading="lazy"
        class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-300"
      />
    </div>

    <div class="p-4">
      <p class="text-xs font-bold text-orange-700 uppercase tracking-wide">{{ catLabel }}</p>

      <h3 class="mt-1 font-bold text-gray-900 text-[15px] leading-snug line-clamp-1">
        {{ biz.name }}
      </h3>

      <p v-if="biz.address" class="mt-1 text-sm text-gray-600 flex items-center gap-1.5 line-clamp-1">
        <PhMapPin :size="15" class="shrink-0 text-gray-400" />
        {{ biz.address }}
      </p>

      <p v-if="biz.description" class="mt-1.5 text-sm text-gray-500 line-clamp-2 leading-relaxed">
        {{ biz.description }}
      </p>

      <div class="mt-3 flex items-center justify-between">
        <p class="text-sm">
          <template v-if="biz.unaffiliated">
            <span class="text-gray-400">Aún sin venta en línea</span>
          </template>
          <template v-else-if="biz.events_count > 0">
            <span class="inline-flex items-center gap-1.5 font-semibold text-green-700">
              <PhSealCheck :size="15" weight="fill" />
              {{ biz.events_count }} {{ biz.events_count === 1 ? 'evento con entradas' : 'eventos con entradas' }}
            </span>
          </template>
          <template v-else>
            <span class="text-gray-600">Sin eventos por ahora</span>
          </template>
        </p>
        <span class="text-sm font-semibold text-gray-500 group-hover:text-orange-700 inline-flex items-center gap-1 transition-colors">
          Ver
          <PhArrowRight :size="14" />
        </span>
      </div>
    </div>
  </article>
</template>

<script setup>
import { computed } from 'vue'
import { PhMapPin, PhArrowRight, PhSealCheck } from '@phosphor-icons/vue'
import { placeholderFor } from '@/lib/placeholderImage'

const props = defineProps({ biz: { type: Object, required: true } })
defineEmits(['open'])

const catLabel = computed(() =>
  ({ cascada: 'Cascada', deporte: 'Deporte extremo', termas: 'Termas', restaurante: 'Restaurante', otro: 'Atracción' }[props.biz.category] ?? 'Atracción')
)
</script>
