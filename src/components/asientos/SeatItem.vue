<template>
  <div
    class="w-12 h-12 flex items-center justify-center rounded-xl font-bold transition-all duration-200 select-none shadow-sm"
    :class="seatClasses"
    @click="toggleSeat"
  >
    {{ seat.seat_number }}
  </div>
</template>

<script setup>
import { computed } from "vue";

const props = defineProps({
  seat: { type: Object, required: true },
  isSelected: { type: Boolean, default: false },
});
const emit = defineEmits(["toggle"]);

const toggleSeat = () => {
  if (props.seat.status === "disponible") {
    emit("toggle", props.seat);
  }
};

// 🔹 Clases dinámicas según estado
const seatClasses = computed(() => {
  if (props.seat.status === "pagado" || props.seat.status === "reservado")
    return "bg-red-500 text-white cursor-not-allowed opacity-70";
  if (props.seat.status === "abordado")
    return "bg-blue-500 text-white cursor-not-allowed opacity-80";
  if (props.isSelected)
    return "bg-yellow-400 text-gray-900 shadow-md ring-2 ring-yellow-500 scale-105";
  return "bg-green-500 hover:bg-green-600 text-white hover:scale-110 cursor-pointer";
});
</script>
