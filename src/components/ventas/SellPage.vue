<template>
  <div class="max-w-7xl mx-auto space-y-6">
    <h1 class="text-2xl font-bold">Venta de Tickets (Agencia)</h1>

    <!-- Lista de tours -->
    <BaseCard>
      <h3 class="font-semibold mb-4">Selecciona un Tour</h3>

      <div v-if="loading" class="text-gray-500">Cargando tours...</div>
      <div v-else-if="tours.length === 0" class="text-gray-500">
        No hay tours activos.
      </div>

      <div v-else class="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        <BaseCard
          v-for="tour in tours"
          :key="tour.id"
          class="cursor-pointer hover:shadow-lg transition"
          @click="selectTour(tour)"
        >
          <h4 class="font-bold">{{ tour.name }}</h4>
          <p class="text-sm text-gray-600">Chiva: {{ tour.chiva }}</p>
          <p class="text-sm text-gray-600">
            Hora salida: {{ formatHour(tour.departure_time) }}
          </p>
          <p class="text-sm text-gray-600">Precio: ${{ tour.base_price }}</p>
          <p class="text-xs mt-1">
            Estado:
            <span
              :class="{
                'text-yellow-600': tour.status === 'pendiente',
                'text-green-600': tour.status === 'en_curso'
              }"
            >
              {{ tour.status }}
            </span>
          </p>
        </BaseCard>
      </div>
    </BaseCard>

    <!-- Selección de asientos -->
    <BaseCard v-if="selectedTour && !checkoutMode">
      <h3 class="font-semibold mb-4">Selecciona tus Asientos</h3>
      <SeatGrid
        :assignedChivaId="selectedTour.id"
        ref="seatGridRef"
        @selectSeats="updateSeats"
      />
    </BaseCard>

    <!-- Carrito -->
    <CartModal
      v-if="selectedSeats.length > 0 && !checkoutMode"
      :selectedSeats="selectedSeats"
      :selectedTour="selectedTour"
      :subtotal="subtotal"
      @checkout="checkoutMode = true"
    />

    <!-- Checkout -->
    <Checkout
      v-if="checkoutMode"
      :selectedTour="selectedTour"
      :selectedSeats="selectedSeats"
      :total="subtotal"
      @purchaseConfirmed="resetForm"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useRoute } from "vue-router";

import SeatGrid from "@/components/asientos/SeatGrid.vue";
import CartModal from "@/components/CartModal.vue";
import Checkout from "@/components/Checkout.vue";
import BaseCard from "@/components/ui/BaseCard.vue";

const tours = ref([]);
const selectedTour = ref(null);
const selectedSeats = ref([]);
const loading = ref(true);
const checkoutMode = ref(false);
const seatGridRef = ref(null);

const route = useRoute();

const loadTours = async () => {
  try {
    const { data, error } = await supabase
      .from("assigned_chivas")
      .select(`
        id,
        departure_at,
        status,
        tours ( id, title, base_price ),
        chivas ( id, name )
      `)
      .in("status", ["pendiente", "en_curso"]); // 🔹 solo mostrar activos

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

const formatHour = (dateTime) => {
  if (!dateTime) return "Sin hora";
  return new Date(dateTime).toLocaleString([], {
    dateStyle: "short",
    timeStyle: "short",
  });
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
  loadTours();
  if (seatGridRef.value) seatGridRef.value.refreshSeats();
};
</script>
