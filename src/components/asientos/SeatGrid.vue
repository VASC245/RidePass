<template>
  <div class="space-y-4">
    <!-- Leyenda: cada estado se distingue por forma e icono, no solo por color -->
    <ul class="flex flex-wrap items-center gap-x-5 gap-y-2 text-sm text-gray-700" aria-label="Leyenda de asientos">
      <li class="flex items-center gap-2">
        <span class="legend-swatch seat--free" aria-hidden="true" /> Libre
      </li>
      <li v-if="!readonly" class="flex items-center gap-2">
        <span class="legend-swatch seat--selected" aria-hidden="true"><PhCheck :size="11" weight="bold" /></span> Elegido
      </li>
      <li class="flex items-center gap-2">
        <span class="legend-swatch seat--taken" aria-hidden="true"><PhX :size="11" weight="bold" /></span> Ocupado
      </li>
      <li class="flex items-center gap-2">
        <span class="legend-swatch seat--boarded" aria-hidden="true"><PhUserCheck :size="11" weight="bold" /></span> Embarcado
      </li>
    </ul>

    <!-- Planta de la chiva -->
    <div class="rounded-[var(--radius-card)] border border-gray-200 bg-gray-50 p-3 sm:p-4">
      <div class="mb-3 flex items-center justify-between text-xs font-medium text-gray-600">
        <span class="inline-flex items-center gap-1.5"><PhSteeringWheel :size="16" /> Frente</span>
        <span class="tabular-nums">{{ freeCount }} de {{ seats.length }} libres</span>
      </div>

      <div v-if="seats.length === 0" class="py-8 text-center text-sm text-gray-600">
        {{ loaded ? 'Esta salida no tiene asientos registrados.' : 'Cargando asientos...' }}
      </div>

      <div v-else class="mx-auto grid w-fit grid-cols-5 gap-2 sm:gap-2.5">
        <template v-for="seat in seats" :key="seat.seat_number">
          <!-- Separación visual antes de la última fila -->
          <div v-if="seat.seat_number === 36" class="col-span-5 h-4" aria-hidden="true"></div>

          <button
            type="button"
            class="seat"
            :class="[seatClass(seat), readonly && 'seat--readonly']"
            :disabled="readonly || isTaken(seat)"
            :aria-pressed="readonly ? undefined : isSelected(seat)"
            :aria-label="`Asiento ${seat.seat_number}, ${seatLabel(seat)}`"
            @click="!readonly && toggleSeat(seat)"
          >
            <span :class="isTaken(seat) && !isBoarded(seat) && 'line-through decoration-2'">{{ seat.seat_number }}</span>
            <span v-if="isSelected(seat)" class="seat-mark bg-gray-900 text-white"><PhCheck :size="10" weight="bold" /></span>
            <span v-else-if="isBoarded(seat)" class="seat-mark bg-info-700 text-white"><PhUserCheck :size="10" weight="bold" /></span>
            <span v-else-if="isTaken(seat)" class="seat-mark bg-gray-500 text-white"><PhX :size="10" weight="bold" /></span>
          </button>
        </template>
      </div>
    </div>

    <p v-if="selectedSeats.length && !readonly" class="text-sm text-gray-700" aria-live="polite">
      {{ selectedSeats.length === 1 ? 'Asiento elegido:' : 'Asientos elegidos:' }}
      <strong class="font-semibold text-gray-900 tabular-nums">{{ selectedSeats.join(', ') }}</strong>
    </p>
  </div>
</template>

<script setup>
import { ref, computed, watch } from "vue";
import { PhCheck, PhX, PhUserCheck, PhSteeringWheel } from "@phosphor-icons/vue";
import { supabase } from "@/lib/supabase";

const props = defineProps({
  assignedChivaId: { type: String, required: true },
  readonly: { type: Boolean, default: false },
});

const emit = defineEmits(["selectSeats"]);

const seats = ref([]);
const selectedSeats = ref([]);
const loaded = ref(false);

const loadSeats = async () => {
  if (!props.assignedChivaId) return;

  try {
    const { data, error } = await supabase
      .from("seats")
      .select("id, assigned_chiva_id, seat_number, status")
      .eq("assigned_chiva_id", props.assignedChivaId)
      .order("seat_number", { ascending: true });

    if (error) throw error;

    seats.value = data || [];
  } catch (err) {
    console.error("Error cargando asientos:", err);
  } finally {
    loaded.value = true;
  }
};

// Recargar asientos si cambia la salida
watch(
  () => props.assignedChivaId,
  () => {
    selectedSeats.value = [];
    loadSeats();
  },
  { immediate: true }
);

// Método público: el padre recarga tras una venta
const refreshSeats = () => loadSeats();
defineExpose({ refreshSeats });

const BOARDED = ["boarded", "abordado"];
const TAKEN = ["paid", "pagado", "reservado", ...BOARDED];

const isBoarded  = (seat) => BOARDED.includes(seat.status);
const isTaken    = (seat) => TAKEN.includes(seat.status);
const isSelected = (seat) => selectedSeats.value.includes(seat.seat_number);

const seatClass = (seat) => {
  if (isBoarded(seat)) return "seat--boarded";
  if (isTaken(seat)) return "seat--taken";
  if (isSelected(seat)) return "seat--selected";
  return "seat--free";
};

const seatLabel = (seat) => {
  if (isBoarded(seat)) return "embarcado";
  if (isTaken(seat)) return "ocupado";
  if (isSelected(seat)) return "elegido";
  return "libre";
};

const freeCount = computed(() => seats.value.filter((s) => !isTaken(s)).length);

// Selección: solo asientos libres
const toggleSeat = (seat) => {
  if (props.readonly) return;

  const estadosNoPermitidos = ["paid", "pagado", "reservado", "boarded", "abordado"];
  if (estadosNoPermitidos.includes(seat.status)) return;

  if (selectedSeats.value.includes(seat.seat_number)) {
    selectedSeats.value = selectedSeats.value.filter((s) => s !== seat.seat_number);
  } else {
    selectedSeats.value.push(seat.seat_number);
  }

  emit("selectSeats", selectedSeats.value);
};
</script>

<style scoped>
.seat {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.75rem;
  height: 2.75rem;
  border-radius: 8px;
  border: 1px solid transparent;
  font-size: 0.9rem;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  user-select: none;
  transition: background-color 150ms ease-out, border-color 150ms ease-out, color 150ms ease-out, transform 150ms ease-out;
}
@media (min-width: 640px) { .seat { width: 3rem; height: 3rem; } }

.seat--free { background: #fff; border-color: var(--color-gray-300); color: var(--color-gray-800); cursor: pointer; }
.seat--free:hover { border-color: var(--color-brand-500); background: var(--color-brand-50); color: var(--color-brand-800); }
.seat--free:active { transform: scale(0.95); }
.seat--selected { background: var(--color-brand-600); border-color: var(--color-brand-700); color: #fff; cursor: pointer; }
.seat--selected:active { transform: scale(0.95); }
.seat--taken { background: var(--color-gray-200); color: var(--color-gray-500); cursor: not-allowed; }
.seat--boarded { background: var(--color-info-50); border-color: var(--color-info-200); color: var(--color-info-700); cursor: not-allowed; }
.seat--readonly { cursor: default; }
.seat--readonly.seat--free:hover { border-color: var(--color-gray-300); background: #fff; color: var(--color-gray-800); }

.seat-mark {
  position: absolute;
  top: -5px;
  right: -5px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 16px;
  height: 16px;
  border-radius: 999px;
  box-shadow: 0 0 0 2px var(--color-gray-50);
}

.legend-swatch {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.25rem;
  height: 1.25rem;
  border-radius: 5px;
  border-width: 1px;
  border-style: solid;
}
.legend-swatch.seat--taken { color: var(--color-gray-600); }
</style>
