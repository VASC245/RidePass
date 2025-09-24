<template>
  <div class="space-y-4">
    <!-- Leyenda -->
    <div class="flex gap-4 mb-4 text-sm">
      <div class="flex items-center gap-1">
        <span class="w-4 h-4 bg-green-500 rounded"></span> Disponible
      </div>
      <div class="flex items-center gap-1">
        <span class="w-4 h-4 bg-red-500 rounded"></span> Ocupado
      </div>
      <div class="flex items-center gap-1">
        <span class="w-4 h-4 bg-blue-500 rounded"></span> Abordado
      </div>
    </div>

    <!-- Grilla de asientos -->
    <div class="grid grid-cols-5 gap-2">
      <template v-for="seat in seats" :key="seat.seat_number">
        <!-- Separación entre filas -->
        <div v-if="seat.seat_number === 36" class="col-span-5 h-4"></div>

        <!-- Asiento -->
        <div
          class="w-12 h-12 flex items-center justify-center rounded text-white font-bold cursor-pointer transition-all"
          :class="seatColor(seat)"
          @click="!readonly && toggleSeat(seat)"
        >
          {{ seat.seat_number }}
        </div>
      </template>
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

// 🔹 Observar cambios en el tour seleccionado
watch(
  () => props.assignedChivaId,
  () => {
    selectedSeats.value = [];
    loadSeats();
  },
  { immediate: true }
);

// 🔹 Exponer método público para refrescar manualmente
const refreshSeats = () => {
  loadSeats();
};
defineExpose({ refreshSeats });

// 🔹 Cambiar color según estado
const seatColor = (seat) => {
  if (seat.status === "abordado") return "bg-blue-500";
  if (seat.status === "pagado" || seat.status === "reservado") return "bg-red-500";
  if (selectedSeats.value.includes(seat.seat_number))
    return "bg-yellow-500"; // selección activa
  return "bg-green-500";
};

// 🔹 Seleccionar asiento (si no es readonly)
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
