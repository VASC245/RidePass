<template>
  <div class="max-w-6xl mx-auto p-4 space-y-6">
    <h1 class="text-2xl font-bold text-center">Tours disponibles</h1>

    <!-- Lista de tours -->
    <div
      v-for="tour in assignedTours"
      :key="tour.id"
      class="bg-white rounded-lg shadow p-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4"
    >
      <div>
        <p class="font-semibold text-lg">{{ tour.tours.title }}</p>
        <p class="text-sm text-gray-600">Chiva: {{ tour.chivas.name }}</p>
        <p class="text-sm text-gray-600">
          Hora de salida: {{ formatDate(tour.departure_at) }}
        </p>
        <p class="text-sm text-gray-600">
          Duración: {{ convertirDuracion(tour.tours.duration) }}
        </p>
        <p class="text-sm text-gray-600">Precio: ${{ tour.tours.base_price }}</p>
      </div>

      <div class="flex gap-2">
        <!-- Modal readonly -->
        <button
          @click="openSeatModal(tour.id)"
          class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded"
        >
          Ver asientos
        </button>

        <!-- Redirige a SellPage -->
        <RouterLink
          :to="{ name: 'SellPage', query: { assignedId: tour.id } }"
          class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded"
        >
          Vender Boletos
        </RouterLink>
      </div>
    </div>

    <!-- Modal de asientos -->
    <div
      v-if="showSeatsModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
    >
      <div class="bg-white rounded-2xl shadow-lg p-6 max-w-3xl w-full relative">
        <button
          @click="closeSeatModal"
          class="absolute top-3 right-3 text-gray-500 hover:text-gray-800"
        >
          ✖
        </button>

        <h3 class="text-lg font-bold mb-4">Mapa de asientos</h3>
        <SeatGrid :assignedChivaId="selectedTourId" :readonly="true" />
      </div>
    </div>

    <!-- Si no hay tours -->
    <p
      v-if="!loading && assignedTours.length === 0"
      class="text-gray-500 text-center"
    >
      No hay tours programados.
    </p>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import dayjs from "dayjs";
import SeatGrid from "@/components/asientos/SeatGrid.vue";

const auth = useAuthStore();

const assignedTours = ref([]);
const showSeatsModal = ref(false);
const selectedTourId = ref(null);
const loading = ref(true);

const openSeatModal = (tourId) => {
  selectedTourId.value = tourId;
  showSeatsModal.value = true;
};
const closeSeatModal = () => {
  showSeatsModal.value = false;
  selectedTourId.value = null;
};

// 🔹 Cargar tours programados
const fetchTours = async () => {
  try {
    let query = supabase
      .from("assigned_chivas")
      .select(`
        id,
        departure_at,
        tours (
          id,
          title,
          duration,
          base_price,
          user_id
        ),
        chivas (
          id,
          name,
          user_id
        )
      `);

    // 🔹 Si es dueño, solo sus tours
    if (auth.user && auth.user.role === "dueño") {
      query = query.eq("tours.user_id", auth.user.id);
    }

    const { data, error } = await query;

    if (error) throw error;

    // 🔹 Mostrar solo tours válidos
    assignedTours.value = (data || []).filter(
      (item) => item.tours?.title && item.tours?.base_price > 0
    );
  } catch (err) {
    console.error("Error al cargar tours asignados:", err);
    assignedTours.value = [];
  } finally {
    loading.value = false;
  }
};

const formatDate = (dateStr) => {
  return dayjs(dateStr).format("DD MMM YYYY, HH:mm");
};

const convertirDuracion = (minutos) => {
  if (!minutos) return "Sin duración";
  const horas = Math.floor(minutos / 60);
  const mins = minutos % 60;
  if (horas > 0 && mins > 0) return `${horas}h ${mins}m`;
  if (horas > 0) return `${horas}h`;
  return `${mins}m`;
};

onMounted(fetchTours);
</script>
