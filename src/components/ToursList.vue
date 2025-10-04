<template>
  <div class="max-w-7xl mx-auto p-8 space-y-10">
    <!-- Título -->
    <h1 class="text-3xl font-extrabold text-gray-800 text-center">
      🗺️ Lista de Tours
    </h1>

    <!-- Estado de carga -->
    <div v-if="loading" class="text-gray-500 text-center">
      Cargando tours...
    </div>

    <!-- Sin tours -->
    <div
      v-else-if="tours.length === 0"
      class="text-gray-500 italic text-center"
    >
      🚫 No tienes tours creados todavía.
    </div>

    <!-- Lista de tours -->
    <div
      v-else
      class="grid sm:grid-cols-2 lg:grid-cols-3 gap-8"
    >
      <div
        v-for="tour in tours"
        :key="tour.id"
        class="bg-white border border-gray-200 rounded-2xl shadow-sm hover:shadow-md transition-all p-6 flex flex-col justify-between"
      >
        <!-- Información del tour -->
        <div>
          <h2 class="font-bold text-xl text-gray-800 mb-1">
            {{ tour.title }}
          </h2>
          <p class="text-sm text-gray-600 mb-2">
            {{ tour.description || "Sin descripción disponible" }}
          </p>
          <p class="text-sm text-gray-500">
            🕒 Duración: {{ tour.duration ? tour.duration + ' min' : 'No especificada' }}
          </p>
        </div>

        <!-- Precio -->
        <div
          class="mt-4 flex items-center justify-between border-t border-gray-100 pt-3"
        >
          <p class="text-green-600 font-semibold text-lg">
            💵 ${{ tour.base_price.toFixed(2) }}
          </p>
          <button
            class="text-sm text-blue-600 hover:underline font-semibold"
          >
            Ver detalles
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();
const tours = ref([]);
const loading = ref(true);

const fetchTours = async () => {
  try {
    if (!auth.user) return;

    const { data, error } = await supabase
      .from("tours")
      .select("id, title, description, base_price, duration, user_id")
      .eq("user_id", auth.user.id);

    if (error) throw error;
    tours.value = data || [];
  } catch (err) {
    console.error("Error cargando tours:", err);
    tours.value = [];
  } finally {
    loading.value = false;
  }
};

onMounted(fetchTours);
</script>
