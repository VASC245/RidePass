<template>
  <BaseCard class="border border-gray-200 rounded-2xl shadow-lg p-6 max-w-xl mx-auto mt-8">
    <!-- Título -->
    <h2 class="text-2xl font-extrabold text-gray-800 mb-4 text-center">
      🛒 Carrito de Compras
    </h2>

    <div class="space-y-6">
      <!-- Asientos -->
      <div>
        <h3 class="font-semibold text-gray-800 mb-2">🪑 Asientos seleccionados:</h3>

        <div class="flex flex-wrap gap-2">
          <div
            v-for="seat in selectedSeats"
            :key="seat"
            class="w-12 h-12 flex items-center justify-center rounded-full bg-green-600 text-white shadow text-sm font-bold"
          >
            {{ seat }}
          </div>
        </div>
      </div>

      <!-- Información del Tour -->
      <div class="bg-gray-50 border rounded-xl p-4 text-sm text-gray-700 space-y-1">
        <p><strong>🎟️ Tour:</strong> {{ selectedTour.title }}</p>

        <p><strong>🚌 Chiva:</strong> {{ selectedTour.chiva_name }}</p>

        <p>
          <strong>⏰ Hora salida:</strong>
          {{ selectedTour.formattedHour }}
        </p>

        <p>
          <strong>💸 Precio por asiento:</strong>
          <span class="text-green-600 font-semibold">
            ${{ customPrice || selectedTour.base_price }}
          </span>
        </p>
      </div>

      <!-- Subtotal -->
      <div class="pt-3 border-t">
        <p class="text-lg font-bold text-gray-800">
          💵 Subtotal:
          <span class="text-green-600 font-extrabold">${{ subtotal }}</span>
        </p>
      </div>

      <!-- Botón Checkout -->
      <BaseButton full class="mt-6" @click="$emit('checkout')">
        👉 Continuar al Checkout
      </BaseButton>
    </div>
  </BaseCard>
</template>

<script setup>
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";

const props = defineProps({
  selectedSeats: Array,
  selectedTour: Object,
  subtotal: Number,
  customPrice: Number
});
</script>
