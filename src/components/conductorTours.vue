<template>
  <div class="max-w-5xl mx-auto py-10 space-y-8">
    <!-- Título -->
    <h2 class="text-3xl font-extrabold text-center text-gray-800">
      🚌 Mis Tours Asignados
    </h2>

    <!-- Cargando -->
    <div v-if="loading" class="text-gray-500 text-center italic">
      ⏳ Cargando tours...
    </div>

    <!-- Sin tours -->
    <div v-else-if="tours.length === 0" class="text-gray-500 text-center">
      🚫 No tienes tours asignados.
    </div>

    <!-- Lista de tours -->
    <div
      v-for="tour in tours"
      :key="tour.id"
      class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 flex flex-col md:flex-row md:items-center md:justify-between gap-6 hover:shadow-md transition-all"
    >
      <!-- Info del tour -->
      <div class="space-y-1">
        <p class="font-bold text-xl text-gray-800">
          {{ tour.tours.title }}
        </p>
        <p class="text-sm text-gray-600">
          🚌 Chiva: <span class="font-medium">{{ tour.chivas.name }}</span>
        </p>
        <p class="text-sm text-gray-600">
          ⏰ Salida:
          <span class="font-medium">
            {{ new Date(tour.departure_at).toLocaleString() }}
          </span>
        </p>
        <p class="text-sm">
          Estado:
          <span
            :class="{
              'text-yellow-600 font-semibold': tour.status === 'pendiente',
              'text-green-600 font-semibold': tour.status === 'en_curso',
              'text-gray-500 font-medium': tour.status === 'finalizado'
            }"
          >
            {{ tour.status }}
          </span>
        </p>
      </div>

      <!-- Acciones -->
      <div class="flex gap-3">
        <button
          v-if="tour.status === 'pendiente'"
          @click="updateStatus(tour.id, 'en_curso')"
          class="bg-green-600 hover:bg-green-700 text-white px-5 py-2.5 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          ▶️ Comenzar
        </button>

        <button
          v-if="tour.status === 'en_curso'"
          @click="updateStatus(tour.id, 'finalizado')"
          class="bg-red-600 hover:bg-red-700 text-white px-5 py-2.5 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          ⏹️ Finalizar
        </button>
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
  loading.value = true;
  if (!auth.user) return;

  // 1️⃣ Buscar TODAS las chivas asignadas al conductor
  const { data: driverRows, error: driverError } = await supabase
    .from("drivers")
    .select("chiva_id")
    .eq("user_id", auth.user.id);

  if (driverError) {
    console.error("Error buscando conductor:", driverError);
    tours.value = [];
    loading.value = false;
    return;
  }

  if (!driverRows || driverRows.length === 0) {
    tours.value = [];
    loading.value = false;
    return;
  }

  const chivaIds = driverRows.map((d) => d.chiva_id);

  // 2️⃣ Traer tours de TODAS esas chivas
  const { data, error } = await supabase
    .from("assigned_chivas")
    .select("id, departure_at, status, tours(title), chivas(name)")
    .in("chiva_id", chivaIds)
    .order("departure_at", { ascending: true });

  if (error) {
    console.error("Error cargando tours:", error);
    tours.value = [];
  } else {
    tours.value = data || [];
  }

  loading.value = false;
};

const updateStatus = async (id, newStatus) => {
  const { error } = await supabase
    .from("assigned_chivas")
    .update({ status: newStatus })
    .eq("id", id);

  if (error) {
    console.error("Error actualizando estado:", error);
  }

  fetchTours();
};

onMounted(fetchTours);
</script>
