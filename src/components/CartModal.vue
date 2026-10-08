<template>
  <BaseCard class="w-full">
    <template #title>Resumen de la venta</template>

    <div class="space-y-5">
      <div>
        <p class="field-label">Asientos ({{ selectedSeats.length }})</p>
        <ul class="flex flex-wrap gap-2">
          <li v-for="seat in selectedSeats" :key="seat"
            class="inline-flex size-10 items-center justify-center rounded-lg border border-brand-200 bg-brand-50 text-sm font-bold text-brand-800 tabular-nums">
            {{ seat }}
          </li>
        </ul>
      </div>

      <dl class="divide-y divide-gray-100 rounded-lg border border-gray-200 text-sm">
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Tour</dt><dd class="text-right font-semibold text-gray-900">{{ selectedTour.name }}</dd></div>
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Chiva</dt><dd class="text-right font-semibold text-gray-900">{{ selectedTour.chiva }}</dd></div>
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Salida</dt><dd class="text-right font-semibold text-gray-900">{{ formatHour(selectedTour.departure_time) }}</dd></div>
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Precio por asiento</dt><dd class="text-right font-semibold text-gray-900 tabular-nums">${{ Number(selectedTour.base_price).toFixed(2) }}</dd></div>
      </dl>

      <div class="flex items-baseline justify-between">
        <span class="text-sm font-medium text-gray-600">Total</span>
        <span class="text-3xl font-bold tracking-[-0.02em] text-gray-900 tabular-nums">${{ Number(subtotal).toFixed(2) }}</span>
      </div>

      <BaseButton block size="lg" @click="$emit('checkout')">
        Ingresar datos del pasajero
        <PhArrowRight :size="18" weight="bold" />
      </BaseButton>
    </div>
  </BaseCard>
</template>

<script setup>
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import { PhArrowRight } from "@phosphor-icons/vue";

defineProps({
  selectedSeats: { type: Array, default: () => [] },
  selectedTour: { type: Object, required: true },
  subtotal: { type: Number, default: 0 },
});

defineEmits(["checkout"]);

const formatHour = (d) =>
  d ? new Date(d).toLocaleString("es-EC", { dateStyle: "short", timeStyle: "short" }) : "Sin hora";
</script>
