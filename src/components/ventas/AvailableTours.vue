<template>
  <div class="max-w-6xl mx-auto p-6 space-y-8">
    <!-- Título -->
    <h1 class="text-3xl font-extrabold text-center text-gray-800">
      🎟️ Tours disponibles
    </h1>

    <!-- Lista de tours -->
    <div
      v-for="tour in assignedTours"
      :key="tour.id"
      class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 flex flex-col md:flex-row md:items-center md:justify-between gap-6 hover:shadow-md transition-all"
    >
      <!-- Información del tour -->
      <div class="space-y-1">
        <p class="font-bold text-xl text-gray-800">
          {{ tour.tours.title }}
        </p>
        <p class="text-sm text-gray-500">
          🚌 Chiva: <span class="font-medium">{{ tour.chivas.name }}</span>
        </p>
        <p class="text-sm text-gray-500">
          ⏰ Hora de salida:
          <span class="font-medium">{{ formatDate(tour.departure_at) }}</span>
        </p>
        <p class="text-sm text-gray-500">
          ⏳ Duración: <span class="font-medium">{{ convertirDuracion(tour.tours.duration) }}</span>
        </p>
        <p class="text-sm text-gray-500">
          💵 Precio: <span class="font-semibold text-green-600">${{ tour.tours.base_price }}</span>
        </p>
      </div>

      <!-- Botones -->
      <div class="flex gap-3">
        <button
          @click="openSeatModal(tour.id)"
          class="bg-blue-600 hover:bg-blue-700 text-white px-5 py-2.5 rounded-xl font-medium shadow-sm transition-all active:scale-95"
        >
          🔍 Ver asientos
        </button>

        <RouterLink
          :to="{ name: 'SellPage', query: { assignedId: tour.id } }"
          class="bg-green-600 hover:bg-green-700 text-white px-5 py-2.5 rounded-xl font-medium shadow-sm transition-all active:scale-95"
        >
          🛒 Vender boletos
        </RouterLink>
      </div>
    </div>

    <!-- Modal de asientos -->
    <div
      v-if="showSeatsModal"
      class="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50"
    >
      <div class="bg-white rounded-2xl shadow-2xl p-8 max-w-3xl w-full relative animate-fadeIn">
        <!-- Botón cerrar -->
        <button
          @click="closeSeatModal"
          class="absolute top-3 right-3 text-gray-500 hover:text-gray-800 text-xl"
        >
          ✖
        </button>

        <h3 class="text-xl font-bold mb-6 text-gray-800">🪑 Mapa de asientos</h3>
        <SeatGrid :assignedChivaId="selectedTourId" :readonly="true" />
      </div>
    </div>

    <!-- Si no hay tours -->
    <p
      v-if="!loading && assignedTours.length === 0"
      class="text-gray-500 text-center text-lg"
    >
      🚫 No hay tours programados.
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
