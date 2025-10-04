<template>
  <div class="space-y-6">
    <!-- Leyenda -->
    <div
      class="flex flex-wrap items-center justify-center gap-6 text-sm font-medium text-gray-700 bg-gray-50 py-3 px-4 rounded-xl shadow-sm"
    >
      <div class="flex items-center gap-2">
        <span class="w-4 h-4 bg-green-500 rounded shadow-sm"></span> Disponible
      </div>
      <div class="flex items-center gap-2">
        <span class="w-4 h-4 bg-yellow-500 rounded shadow-sm"></span> Seleccionado
      </div>
      <div class="flex items-center gap-2">
        <span class="w-4 h-4 bg-red-500 rounded shadow-sm"></span> Pagado / Reservado
      </div>
      <div class="flex items-center gap-2">
        <span class="w-4 h-4 bg-blue-500 rounded shadow-sm"></span> Abordado
      </div>
    </div>

    <!-- Grilla de asientos -->
    <div
      class="grid grid-cols-5 gap-3 justify-items-center p-6 bg-white border border-gray-200 rounded-2xl shadow-md"
    >
      <template v-for="seat in seats" :key="seat.seat_number">
        <!-- Separación entre filas -->
        <div v-if="seat.seat_number === 36" class="col-span-5 h-6"></div>

        <!-- Asiento -->
        <div
          class="w-12 h-12 flex items-center justify-center rounded-xl font-bold cursor-pointer transition-all duration-200 select-none text-white shadow-sm"
          :class="[seatColor(seat), !readonly ? 'hover:scale-110' : 'opacity-80']"
          @click="!readonly && toggleSeat(seat)"
        >
          {{ seat.seat_number }}
        </div>
      </template>
    </div>

    <!-- Indicador de asientos seleccionados -->
    <div
      v-if="selectedSeats.length && !readonly"
      class="text-center text-sm text-gray-700"
    >
      <p class="font-semibold">
        🎟️ Asientos seleccionados: <span class="text-yellow-600">{{ selectedSeats.join(", ") }}</span>
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, defineExpose } from "vue";
import { supabase } from "@/lib/supabase";

const props = defineProps({
  assignedChivaId: { type: String, required: true },
  readonly: { type: Boolean, default: false },
});

const emit = defineEmits(["selectSeats"]);

const seats = ref([]);
const selectedSeats = ref([]);

// 🔹 Cargar asientos desde Supabase
const loadSeats = async () => {
  if (!props.assignedChivaId) return;

  const { data, error } = await supabase
    .from("seats")
    .select("id, seat_number, status")
    .eq("assigned_chiva_id", props.assignedChivaId)
    .order("seat_number", { ascending: true });

  if (!error) seats.value = data || [];
  else console.error("Error cargando asientos:", error);
};

// 🔹 Observar cambios
watch(
  () => props.assignedChivaId,
  () => {
    selectedSeats.value = [];
    loadSeats();
  },
  { immediate: true }
);

// 🔹 Exponer método público
const refreshSeats = () => loadSeats();
defineExpose({ refreshSeats });

// 🔹 Color según estado
const seatColor = (seat) => {
  if (seat.status === "abordado") return "bg-blue-500";
  if (seat.status === "pagado" || seat.status === "reservado")
    return "bg-red-500";
  if (selectedSeats.value.includes(seat.seat_number))
    return "bg-yellow-500";
  return "bg-green-500";
};

// 🔹 Seleccionar asiento
const toggleSeat = (seat) => {
  if (props.readonly) return;
  if (seat.status !== "disponible") return;

  if (selectedSeats.value.includes(seat.seat_number)) {
    selectedSeats.value = selectedSeats.value.filter(
      (s) => s !== seat.seat_number
    );
  } else {
    selectedSeats.value.push(seat.seat_number);
  }

  emit("selectSeats", selectedSeats.value);
};
</script>
