<template>
  <div
    class="w-12 h-12 flex items-center justify-center rounded font-bold cursor-pointer transition-all"
    :class="seatClasses"
    @click="toggleSeat"
  >
    {{ seat.seat_number }}
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  seat: Object,
  isSelected: Boolean
});
const emit = defineEmits(['toggle']);

const toggleSeat = () => {
  if (props.seat.status === 'disponible') {
    emit('toggle', props.seat);
  }
};

const seatClasses = computed(() => {
  if (props.seat.status === 'pagado') return 'bg-gray-400 text-white cursor-not-allowed';
  if (props.seat.status === 'abordado') return 'bg-blue-500 text-white cursor-not-allowed';
  if (props.isSelected) return 'bg-green-600 text-white';
  return 'bg-green-300 hover:bg-green-400 text-black';
});
</script>
