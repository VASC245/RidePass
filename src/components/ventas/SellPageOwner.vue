<template>
  <div class="max-w-7xl mx-auto space-y-8 p-6">
    <!-- Título -->
    <h1 class="text-3xl font-extrabold text-center text-gray-800">
      📊 Mis Ventas (Dueño)
    </h1>

    <!-- Lista de tours -->
    <BaseCard>
      <h3 class="font-semibold text-lg mb-6 text-gray-800">
        Selecciona un Tour
      </h3>

      <div v-if="loading" class="text-gray-500 italic">⏳ Cargando tours...</div>
      <div v-else-if="tours.length === 0" class="text-gray-500 text-center py-6">
        🚫 No hay tours activos.
      </div>

      <div v-else class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        <BaseCard
          v-for="tour in tours"
          :key="tour.id"
          class="cursor-pointer hover:shadow-lg border hover:border-green-300 transition-all duration-200 rounded-2xl"
          @click="selectTour(tour)"
        >
          <h4 class="font-bold text-xl text-gray-800 mb-1">{{ tour.name }}</h4>
          <p class="text-sm text-gray-600">🚌 Chiva: <span class="font-medium">{{ tour.chiva }}</span></p>
          <p class="text-sm text-gray-600">⏰ Hora salida: <span class="font-medium">{{ formatHour(tour.departure_time) }}</span></p>
          <p class="text-sm text-gray-600">💵 Precio: <span class="font-semibold text-green-600">${{ tour.base_price }}</span></p>
          <p class="text-xs mt-2">
            Estado:
            <span
              :class="{
                'text-yellow-600 font-medium': tour.status === 'pendiente',
                'text-green-600 font-semibold': tour.status === 'en_curso'
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
      <h3 class="font-semibold text-lg mb-6 text-gray-800">Selecciona tus Asientos</h3>
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
import { useAuthStore } from "@/stores/authStore";

import SeatGrid from "@/components/asientos/SeatGrid.vue";
import CartModal from "@/components/CartModal.vue";
import Checkout from "@/components/Checkout.vue";
import BaseCard from "@/components/ui/BaseCard.vue";

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
      .eq("tours.user_id", auth.user.id) // 🔹 solo tours creados por este dueño
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

  // 🔹 recargar asientos si cambia de tour
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