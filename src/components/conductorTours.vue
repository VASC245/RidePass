<template>
  <div class="max-w-4xl mx-auto py-10 space-y-6">
    <h2 class="text-2xl font-bold text-center">Mis Tours Asignados</h2>

    <div v-if="tours.length === 0" class="text-gray-500 text-center">
      No tienes tours asignados.
    </div>

    <div
      v-for="tour in tours"
      :key="tour.id"
      class="bg-white rounded-xl shadow p-4 flex flex-col md:flex-row md:items-center md:justify-between gap-4"
    >
      <div>
        <p class="font-semibold text-lg">{{ tour.tours.title }}</p>
        <p class="text-sm text-gray-600">Chiva: {{ tour.chivas.name }}</p>
        <p class="text-sm text-gray-600">
          Salida: {{ new Date(tour.departure_at).toLocaleString() }}
        </p>
        <p class="text-sm text-gray-600">
          Estado:
          <span :class="{
            'text-yellow-600': tour.status === 'pendiente',
            'text-green-600': tour.status === 'en_curso',
            'text-red-600': tour.status === 'finalizado'
          }">
            {{ tour.status }}
          </span>
        </p>
      </div>

      <div class="flex gap-2">
        <button
          v-if="tour.status === 'pendiente'"
          @click="updateStatus(tour.id, 'en_curso')"
          class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded"
        >
          Comenzar
        </button>

        <button
          v-if="tour.status === 'en_curso'"
          @click="updateStatus(tour.id, 'finalizado')"
          class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded"
        >
          Finalizar
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

const fetchTours = async () => {
  if (!auth.user) return;

  // 🔹 Buscar chiva asignada al conductor logueado
  const { data: driver } = await supabase
    .from("drivers")
    .select("chiva_id")
    .eq("user_id", auth.user.id)
    .single();

  if (!driver) {
    tours.value = [];
    return;
  }

  // 🔹 Obtener tours de esa chiva
  const { data } = await supabase
    .from("assigned_chivas")
    .select("id, departure_at, status, tours(title), chivas(name)")
    .eq("chiva_id", driver.chiva_id)
    .order("departure_at", { ascending: true });

  tours.value = data || [];
};

const updateStatus = async (id, newStatus) => {
  await supabase.from("assigned_chivas").update({ status: newStatus }).eq("id", id);
  fetchTours(); // 🔄 refrescar la lista del conductor
};

onMounted(fetchTours);
</script>
