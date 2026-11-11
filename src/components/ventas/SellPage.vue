<template>
  <div :class="selectedTour && !checkoutMode && 'pb-28 lg:pb-0'">
    <PageHeader title="Vender boletos" description="Elige la salida, marca los asientos y registra al pasajero." />

    <!-- Pasos -->
    <ol class="mb-6 flex flex-wrap items-center gap-x-2 gap-y-2 text-sm" aria-label="Pasos de la venta">
      <li v-for="(step, i) in steps" :key="step" class="flex items-center gap-2">
        <span class="inline-flex size-6 items-center justify-center rounded-full text-xs font-bold tabular-nums"
          :class="i < currentStep ? 'bg-gray-900 text-white' : i === currentStep ? 'bg-brand-600 text-white' : 'bg-gray-200 text-gray-600'">
          <PhCheck v-if="i < currentStep" :size="12" weight="bold" />
          <template v-else>{{ i + 1 }}</template>
        </span>
        <span :class="i === currentStep ? 'font-semibold text-gray-900' : 'text-gray-600'"
          :aria-current="i === currentStep ? 'step' : undefined">{{ step }}</span>
        <PhCaretRight v-if="i < steps.length - 1" :size="14" class="text-gray-400" aria-hidden="true" />
      </li>
    </ol>

    <div class="grid items-start gap-6" :class="!checkoutMode && 'lg:grid-cols-[minmax(0,1fr)_20rem]'">
      <div class="min-w-0 space-y-6">
        <!-- Paso 3: datos del pasajero y cobro -->
        <template v-if="checkoutMode">
          <button type="button" class="inline-flex h-10 items-center gap-1.5 rounded-lg px-2 -ml-2 text-sm font-semibold text-gray-700 hover:bg-gray-100 hover:text-gray-900"
            @click="checkoutMode = false">
            <PhArrowLeft :size="16" /> Volver a los asientos
          </button>
          <Checkout
            :selectedTour="selectedTour"
            :selectedSeats="selectedSeats"
            :total="subtotal"
            @purchaseConfirmed="resetForm"
          />
        </template>

        <template v-else>
          <!-- Paso 1: salida -->
          <BaseCard>
            <template #title>Salida</template>
            <template v-if="selectedTour" #actions>
              <BaseButton variant="ghost" size="sm" @click="changeTour">Cambiar salida</BaseButton>
            </template>

            <div v-if="toursStore.loading" class="space-y-2" aria-busy="true">
              <div v-for="n in 3" :key="n" class="h-16 animate-pulse rounded-lg bg-gray-100" />
            </div>

            <EmptyState v-else-if="displayTours.length === 0" :icon="PhCalendarBlank"
              title="No hay salidas a la venta"
              description="Aparecen aquí las salidas de hoy en adelante cuyo dueño permite vender por agencia." />

            <ul v-else class="space-y-2" role="radiogroup" aria-label="Salidas">
              <li v-for="tour in visibleTours" :key="tour.id">
                <button type="button" role="radio" :aria-checked="selectedTour?.id === tour.id"
                  class="tour-option" :class="selectedTour?.id === tour.id && 'tour-option--active'"
                  @click="selectTour(tour)">
                  <span class="w-16 shrink-0 text-left">
                    <span class="block text-lg font-bold text-gray-900 tabular-nums">{{ formatTime(tour.departure_time) }}</span>
                    <span class="block text-xs text-gray-600">{{ formatDay(tour.departure_time) }}</span>
                  </span>
                  <span class="min-w-0 flex-1 text-left">
                    <span class="flex flex-wrap items-center gap-2">
                      <span class="font-semibold text-gray-900">{{ tour.name }}</span>
                      <StatusBadge v-if="tour.status === 'en_curso'" tone="info">En curso</StatusBadge>
                    </span>
                    <span class="mt-0.5 flex items-center gap-1.5 text-sm text-gray-600">
                      <PhBus :size="15" class="text-gray-500" />{{ tour.chiva || 'Chiva sin nombre' }}
                    </span>
                  </span>
                  <span class="shrink-0 text-right">
                    <span class="block font-semibold text-gray-900 tabular-nums">${{ Number(tour.base_price).toFixed(2) }}</span>
                    <span class="block text-xs text-gray-600">por asiento</span>
                  </span>
                </button>
              </li>
            </ul>
          </BaseCard>

          <!-- Paso 2: asientos -->
          <BaseCard v-if="selectedTour">
            <template #title>Asientos</template>
            <SeatGrid
              :assignedChivaId="selectedTour.id"
              ref="seatGridRef"
              @selectSeats="updateSeats"
            />
          </BaseCard>
        </template>
      </div>

      <!-- Resumen (escritorio) -->
      <aside v-if="!checkoutMode" class="hidden lg:sticky lg:top-6 lg:block" aria-label="Resumen de la venta">
        <BaseCard>
          <template #title>Resumen</template>
          <dl class="space-y-2.5 text-sm">
            <div class="flex justify-between gap-3">
              <dt class="text-gray-600">Tour</dt>
              <dd class="text-right font-medium text-gray-900">{{ selectedTour?.name ?? 'Sin elegir' }}</dd>
            </div>
            <div class="flex justify-between gap-3">
              <dt class="text-gray-600">Salida</dt>
              <dd class="text-right font-medium text-gray-900 tabular-nums">{{ selectedTour ? formatHour(selectedTour.departure_time) : 'Sin elegir' }}</dd>
            </div>
            <div class="flex justify-between gap-3">
              <dt class="text-gray-600">Asientos</dt>
              <dd class="text-right font-medium text-gray-900 tabular-nums">{{ selectedSeats.length ? selectedSeats.join(', ') : 'Ninguno' }}</dd>
            </div>
            <div v-if="selectedTour" class="flex justify-between gap-3">
              <dt class="text-gray-600">Precio</dt>
              <dd class="text-right text-gray-900 tabular-nums">{{ selectedSeats.length }} × ${{ Number(selectedTour.base_price).toFixed(2) }}</dd>
            </div>
          </dl>
          <div class="mt-4 flex items-baseline justify-between border-t border-gray-200 pt-4">
            <span class="text-sm font-medium text-gray-700">Total</span>
            <span class="text-2xl font-bold tracking-[-0.02em] text-gray-900 tabular-nums">${{ Number(subtotal).toFixed(2) }}</span>
          </div>
          <BaseButton v-if="!checkoutMode" block size="lg" class="mt-4" :disabled="selectedSeats.length === 0" @click="checkoutMode = true">
            Continuar con el pasajero <PhArrowRight :size="18" />
          </BaseButton>
          <p v-if="!checkoutMode && selectedSeats.length === 0" class="mt-2 text-center text-xs text-gray-600">
            {{ selectedTour ? 'Marca al menos un asiento.' : 'Primero elige una salida.' }}
          </p>
        </BaseCard>
      </aside>
    </div>

    <!-- Barra de total (móvil y tablet) -->
    <div v-if="selectedTour && !checkoutMode"
      class="fixed inset-x-0 bottom-0 z-30 border-t border-gray-200 bg-white px-4 py-3 lg:hidden"
      style="padding-bottom: max(0.75rem, env(safe-area-inset-bottom))">
      <div class="mx-auto flex max-w-3xl items-center justify-between gap-4">
        <div class="min-w-0">
          <p class="text-xs text-gray-600 tabular-nums">
            {{ selectedSeats.length }} {{ selectedSeats.length === 1 ? 'asiento' : 'asientos' }}
          </p>
          <p class="text-xl font-bold text-gray-900 tabular-nums">${{ Number(subtotal).toFixed(2) }}</p>
        </div>
        <BaseButton size="lg" :disabled="selectedSeats.length === 0" @click="checkoutMode = true">
          Continuar <PhArrowRight :size="18" />
        </BaseButton>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { useRoute } from "vue-router";
import { useToursStore } from "@/stores/toursStore";
import SeatGrid from "@/components/asientos/SeatGrid.vue";
import Checkout from "@/components/Checkout.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import PageHeader from "@/components/ui/PageHeader.vue";
import StatusBadge from "@/components/ui/StatusBadge.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import {
  PhBus, PhCheck, PhCaretRight, PhArrowRight, PhArrowLeft, PhCalendarBlank,
} from "@phosphor-icons/vue";

const toursStore = useToursStore();
const route = useRoute();

const selectedTour = ref(null);
const selectedSeats = ref([]);
const checkoutMode = ref(false);
const seatGridRef = ref(null);

// Cargar tours al inicio. Si llega ?assignedId= (desde "Tours disponibles"),
// esa salida queda elegida.
onMounted(async () => {
  await toursStore.fetchTours();
  const preselected = displayTours.value.find((t) => t.id === route.query.assignedId);
  if (preselected) selectTour(preselected);
});

// Convertimos el resultado del store a la estructura que SellPage espera
// Solo tours cuyo dueño permite venta por agencias
const displayTours = computed(() =>
  toursStore.tours.filter((item) => item.allow_agency_sales).map((item) => ({
    id: item.id,
    name: item.title,             // ← antes item.tours.title
    base_price: item.base_price,  // ← antes item.tours.base_price
    chiva: item.chiva_name,       // ← antes item.chivas.name
    status: item.status,
    departure_time: item.departure_at,
  }))
);

// Formatear hora
const formatHour = (dateTime) => {
  if (!dateTime) return "Sin hora";
  return new Date(dateTime).toLocaleString("es-EC", {
    day: "numeric", month: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  });
};

const formatTime = (d) =>
  d ? new Date(d).toLocaleTimeString("es-EC", { hour: "2-digit", minute: "2-digit", hourCycle: "h23" }) : "--:--";

const formatDay = (d) => {
  if (!d) return "";
  const date = new Date(d);
  const today = new Date();
  const tomorrow = new Date(); tomorrow.setDate(today.getDate() + 1);
  if (date.toDateString() === today.toDateString()) return "Hoy";
  if (date.toDateString() === tomorrow.toDateString()) return "Mañana";
  return date.toLocaleDateString("es-EC", { weekday: "short", day: "numeric", month: "short" });
};

const steps = ["Salida", "Asientos", "Pasajero y cobro"];
const currentStep = computed(() => (checkoutMode.value ? 2 : selectedTour.value ? 1 : 0));

// Con una salida elegida, la lista se reduce a esa salida para no hacer scroll
const visibleTours = computed(() =>
  selectedTour.value ? displayTours.value.filter((t) => t.id === selectedTour.value.id) : displayTours.value
);

const changeTour = () => {
  selectedTour.value = null;
  selectedSeats.value = [];
  checkoutMode.value = false;
};

const selectTour = (tour) => {
  selectedTour.value = tour;
  selectedSeats.value = [];
  checkoutMode.value = false;
};

const updateSeats = (seats) => {
  selectedSeats.value = seats;
};

const subtotal = computed(() => {
  if (!selectedTour.value) return 0;
  return selectedSeats.value.length * selectedTour.value.base_price;
});

const resetForm = () => {
  selectedTour.value = null;
  selectedSeats.value = [];
  checkoutMode.value = false;
  toursStore.fetchTours();
  if (seatGridRef.value) seatGridRef.value.refreshSeats();
};
</script>

<style scoped>
.tour-option {
  display: flex;
  width: 100%;
  min-height: 3.5rem;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1rem;
  border: 1px solid var(--color-gray-200);
  border-radius: 8px;
  background: #fff;
  transition: border-color 150ms ease-out, background-color 150ms ease-out;
}
.tour-option:hover { border-color: var(--color-gray-400); }
.tour-option--active,
.tour-option--active:hover {
  border-color: var(--color-brand-600);
  background: var(--color-brand-50);
  box-shadow: inset 0 0 0 1px var(--color-brand-600);
}
</style>
