<template>
  <BaseCard>
    <!-- Título -->
    <h3 class="font-semibold text-lg mb-4 text-gray-800">🛒 Carrito</h3>

    <div class="space-y-4">
      <!-- Asientos seleccionados -->
      <div class="flex flex-wrap gap-2">
        <div
          v-for="seat in selectedSeats"
          :key="seat"
          class="w-12 h-12 flex items-center justify-center rounded-full bg-green-600 text-white text-sm font-bold shadow-sm hover:bg-green-700 transition"
        >
          {{ seat }}
        </div>
      </div>

      <!-- Info del tour -->
      <div class="pt-3 border-t space-y-1 text-sm text-gray-600">
        <p><span class="font-medium">🎟️ Tour:</span> {{ selectedTour?.name }}</p>
        <p><span class="font-medium">📅 Fecha:</span> {{ selectedTour?.date }}</p>
        <p><span class="font-medium">⏰ Hora salida:</span> {{ selectedTour?.departure_time }}</p>
      </div>

      <!-- Subtotal -->
      <div class="pt-3 border-t">
        <p class="text-lg font-bold text-gray-800">
          💵 Subtotal: <span class="text-green-600">${{ subtotal }}</span>
        </p>
      </div>
    </div>

    <!-- Botón Checkout -->
    <BaseButton
      full
      class="mt-6"
      @click="$emit('checkout')"
    >
      ✅ Ir al Checkout
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
