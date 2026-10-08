<template>
  <div>
    <PageHeader
      title="Vender boletos"
      description="Vende en taquilla: elige la salida, marca los asientos y registra el cobro."
    />

    <div class="space-y-6">
      <!-- 1. Salida -->
      <BaseCard>
        <template #title>
          <span class="flex items-center gap-2.5"><span class="step">1</span> Elige la salida</span>
        </template>

        <div v-if="loading" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" aria-busy="true">
          <div v-for="n in 3" :key="n" class="h-28 animate-pulse rounded-lg bg-gray-100" />
        </div>

        <EmptyState v-else-if="tours.length === 0" :icon="PhCalendarBlank"
          title="No tienes salidas programadas"
          description="Programa una salida con chiva y hora para poder vender boletos.">
          <RouterLink to="/panel/asignar"
            class="inline-flex h-10 items-center gap-2 rounded-lg bg-brand-600 px-4 text-sm font-semibold text-white transition-colors hover:bg-brand-700">
            <PhPlus :size="18" /> Programar salida
          </RouterLink>
        </EmptyState>

        <div v-else class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3" role="radiogroup" aria-label="Salidas">
          <button
            v-for="tour in tours" :key="tour.id"
            type="button" role="radio" :aria-checked="selectedTour?.id === tour.id"
            class="salida group flex flex-col rounded-lg border p-4 text-left transition-colors duration-150"
            :class="selectedTour?.id === tour.id
              ? 'border-brand-600 bg-brand-50 ring-1 ring-brand-600'
              : 'border-gray-200 bg-white hover:border-gray-400'"
            @click="selectTour(tour)"
          >
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="text-2xl font-bold leading-none text-gray-900 tabular-nums">{{ formatTime(tour.departure_time) }}</p>
                <p class="mt-1 text-sm font-medium text-gray-600 first-letter:uppercase">{{ formatDay(tour.departure_time) }}</p>
              </div>
              <StatusBadge :tone="tour.status === 'en_curso' ? 'success' : 'info'">
                {{ tour.status === 'en_curso' ? 'En curso' : 'Programada' }}
              </StatusBadge>
            </div>
            <p class="mt-3 font-semibold text-gray-900">{{ tour.name }}</p>
            <div class="mt-1 flex items-center justify-between gap-3 text-sm text-gray-600">
              <span class="flex items-center gap-1.5 truncate"><PhBus :size="16" class="shrink-0" /> {{ tour.chiva }}</span>
              <span class="font-semibold text-gray-900 tabular-nums">${{ Number(tour.base_price).toFixed(2) }}</span>
            </div>
          </button>
        </div>
      </BaseCard>

      <!-- 2. Asientos -->
      <BaseCard v-if="selectedTour && !checkoutMode">
        <template #title>
          <span class="flex items-center gap-2.5"><span class="step">2</span> Marca los asientos</span>
        </template>
        <template #actions>
          <span class="hidden text-sm text-gray-600 sm:inline">{{ selectedTour.name }} · {{ formatTime(selectedTour.departure_time) }}</span>
        </template>
        <SeatGrid
          :assignedChivaId="selectedTour.id"
          ref="seatGridRef"
          @selectSeats="updateSeats"
        />
      </BaseCard>

      <!-- 3. Cobro -->
      <CartModal
        v-if="selectedSeats.length > 0 && !checkoutMode"
        :selectedSeats="selectedSeats"
        :selectedTour="selectedTour"
        :subtotal="subtotal"
        @checkout="checkoutMode = true"
      />

      <template v-if="checkoutMode">
        <button type="button" class="inline-flex h-10 items-center gap-1.5 rounded-lg px-2 text-sm font-semibold text-gray-700 hover:bg-gray-100"
          @click="checkoutMode = false">
          <PhCaretLeft :size="16" /> Cambiar asientos
        </button>
        <Checkout
          :selectedTour="selectedTour"
          :selectedSeats="selectedSeats"
          :total="subtotal"
          @purchaseConfirmed="resetForm"
        />
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useRoute } from "vue-router";
import { useAuthStore } from "@/stores/authStore";

import SeatGrid from "@/components/asientos/SeatGrid.vue";
import CartModal from "@/components/CartModal.vue";
import Checkout from "@/components/Checkout.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import PageHeader from "@/components/ui/PageHeader.vue";
import StatusBadge from "@/components/ui/StatusBadge.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import { PhBus, PhCalendarBlank, PhPlus, PhCaretLeft } from "@phosphor-icons/vue";

const auth = useAuthStore();

const tours = ref([]);
const selectedTour = ref(null);
const selectedSeats = ref([]);
const loading = ref(true);
const checkoutMode = ref(false);
const seatGridRef = ref(null);

const route = useRoute();

const loadTours = async () => {
  try {
    if (!auth.user) return;

    const { data, error } = await supabase
      .from("assigned_chivas")
      .select(`
        id,
        departure_at,
        status,
        tours (
          id,
          title,
          base_price,
          user_id
        ),
        chivas (
          id,
          name
        )
      `)
      .eq("tours.user_id", auth.user.id) // solo tours creados por este dueño
      .in("status", ["pendiente", "en_curso"]) // solo salidas por vender
      .order("departure_at", { ascending: true });

    if (error) throw error;

    tours.value = (data || [])
      .filter((item) => item.tours?.title && item.tours?.base_price > 0)
      .map((item) => ({
        id: item.id,
        departure_time: item.departure_at,
        name: item.tours?.title,
        base_price: item.tours?.base_price,
        chiva: item.chivas?.name || "Sin chiva asignada",
        status: item.status,
      }));

    if (route.query.assignedId) {
      const found = tours.value.find(
        (t) => String(t.id) === String(route.query.assignedId)
      );
      if (found) selectTour(found);
    }
  } catch (err) {
    console.error("Error cargando tours:", err);
    tours.value = [];
  } finally {
    loading.value = false;
  }
};

onMounted(loadTours);

const formatTime = (dateTime) =>
  dateTime ? new Date(dateTime).toLocaleTimeString("es-EC", { hour: "2-digit", minute: "2-digit" }) : "Sin hora";

const formatDay = (dateTime) => {
  if (!dateTime) return "";
  const d = new Date(dateTime);
  const today = new Date();
  const tomorrow = new Date(); tomorrow.setDate(today.getDate() + 1);
  if (d.toDateString() === today.toDateString()) return "hoy";
  if (d.toDateString() === tomorrow.toDateString()) return "mañana";
  return d.toLocaleDateString("es-EC", { weekday: "long", day: "numeric", month: "short" });
};

const selectTour = (tour) => {
  selectedTour.value = tour;
  selectedSeats.value = [];
  checkoutMode.value = false;

  // recargar asientos si cambia de salida
  if (seatGridRef.value) seatGridRef.value.refreshSeats();
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
  loadTours();
  if (seatGridRef.value) seatGridRef.value.refreshSeats();
};
</script>
<style scoped>
.step {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem; height: 1.5rem;
  border-radius: 999px;
  background: var(--color-gray-900);
  color: #fff;
  font-size: 0.75rem;
  font-weight: 700;
}
</style>
