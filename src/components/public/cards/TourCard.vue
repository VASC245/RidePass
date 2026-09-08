<template>
  <article
    class="group cursor-pointer rounded-2xl bg-white border border-gray-200 overflow-hidden hover:shadow-lg hover:shadow-gray-900/8 hover:-translate-y-0.5 transition-all duration-200"
    @click="$emit('open', tour)"
  >
    <div class="aspect-[16/9] overflow-hidden bg-gray-100">
      <!-- Foto placeholder determinística por tour; reemplazar con foto real del tour cuando exista -->
      <img
        :src="tour.image_url || placeholderFor(tour.id)"
        :alt="tour.title"
        loading="lazy"
        class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-300"
      />
    </div>

    <div class="p-4">
      <h3 class="font-bold text-gray-900 text-[15px] leading-snug line-clamp-2">
        {{ tour.title }}
      </h3>

      <p class="mt-1.5 text-sm font-semibold text-orange-700">
        {{ dateLabel }}
      </p>

      <p class="mt-1 text-sm text-gray-600 flex items-center gap-1.5">
        <PhVan :size="15" class="shrink-0 text-gray-400" />
        {{ tour.chiva_name || 'Chiva por confirmar' }}
      </p>

      <div class="mt-3 flex items-center justify-between">
        <p class="text-sm text-gray-900">
          Desde <span class="font-bold">${{ Number(tour.base_price).toFixed(2) }}</span>
        </p>
        <span class="text-sm font-semibold text-gray-500 group-hover:text-orange-700 inline-flex items-center gap-1 transition-colors">
          Reservar
          <PhArrowRight :size="14" />
        </span>
      </div>
    </div>
  </article>
</template>

<script setup>
import { computed } from 'vue'
import { PhVan, PhArrowRight } from '@phosphor-icons/vue'
import { placeholderFor } from '@/lib/placeholderImage'

const props = defineProps({ tour: { type: Object, required: true } })
defineEmits(['open'])

const dateLabel = computed(() => {
  const d = new Date(props.tour.departure_at)
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const diff = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000)
  const hora = d.toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' })
  if (diff === 0) return `Hoy, ${hora}`
  if (diff === 1) return `Mañana, ${hora}`
  const fecha = d.toLocaleDateString('es-EC', { weekday: 'short', day: 'numeric', month: 'short' })
  return `${fecha}, ${hora}`
})
</script>
