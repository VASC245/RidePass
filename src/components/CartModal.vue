<template>
  <BaseCard>
    <h3 class="font-semibold mb-3">Carrito</h3>

    <div class="space-y-2">
      <!-- Asientos seleccionados -->
      <div class="flex flex-wrap gap-2">
        <div
          v-for="seat in selectedSeats"
          :key="seat"
          class="w-10 h-10 flex items-center justify-center rounded bg-green-600 text-white text-sm font-bold"
        >
          {{ seat }}
        </div>
      </div>

      <div class="pt-2 border-t mt-2">
        <p class="text-sm text-gray-600">Tour: {{ selectedTour?.name }}</p>
        <p class="text-sm text-gray-600">Fecha: {{ selectedTour?.date }}</p>
        <p class="text-sm text-gray-600">Hora salida: {{ selectedTour?.departure_time }}</p>
        <p class="font-bold mt-2">Subtotal: ${{ subtotal }}</p>
      </div>
    </div>

    <BaseButton full class="mt-4" @click="$emit('checkout')">
      Ir al Checkout
    </BaseButton>
  </BaseCard>
</template>

<script setup>
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseCard from '@/components/ui/BaseCard.vue';

const props = defineProps({
  selectedSeats: Array,
  selectedTour: Object,
  subtotal: Number
});
</script>
