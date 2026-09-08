<template>
  <BaseCard class="border border-gray-200 rounded-2xl shadow-lg p-6 max-w-xl mx-auto mt-8">
    <h2 class="text-xl font-bold text-gray-900 mb-4">Resumen de la venta</h2>

    <div class="space-y-6">
      <div>
        <h3 class="text-sm font-semibold text-gray-700 mb-2">Asientos seleccionados</h3>
        <div class="flex flex-wrap gap-2">
          <div
            v-for="seat in selectedSeats"
            :key="seat"
            class="w-11 h-11 flex items-center justify-center rounded-full bg-orange-600 text-white text-sm font-bold"
          >
            {{ seat }}
          </div>
        </div>
      </div>

      <div class="bg-gray-50 border border-gray-200 rounded-xl p-4 text-sm text-gray-700 space-y-1">
        <p class="flex justify-between"><span class="text-gray-500">Tour</span><strong>{{ selectedTour.name }}</strong></p>
        <p class="flex justify-between"><span class="text-gray-500">Chiva</span><strong>{{ selectedTour.chiva }}</strong></p>
        <p class="flex justify-between"><span class="text-gray-500">Salida</span><strong>{{ formatHour(selectedTour.departure_time) }}</strong></p>
        <p class="flex justify-between"><span class="text-gray-500">Precio por asiento</span><strong>${{ Number(selectedTour.base_price).toFixed(2) }}</strong></p>
      </div>

      <div class="pt-3 border-t border-gray-200 flex justify-between items-baseline">
        <span class="text-gray-600">Total</span>
        <span class="text-2xl font-extrabold text-gray-900">${{ Number(subtotal).toFixed(2) }}</span>
      </div>

      <BaseButton full class="mt-2" @click="$emit('checkout')">
        Continuar
      </BaseButton>
    </div>
  </BaseCard>
</template>

<script setup>
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";

defineProps({
  selectedSeats: { type: Array, default: () => [] },
  selectedTour: { type: Object, required: true },
  subtotal: { type: Number, default: 0 },
});

defineEmits(["checkout"]);

const formatHour = (d) =>
  d ? new Date(d).toLocaleString("es-EC", { dateStyle: "short", timeStyle: "short" }) : "Sin hora";
</script>
