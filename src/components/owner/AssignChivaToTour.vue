<template>
  <div class="max-w-6xl mx-auto py-10 px-6 space-y-10">
    <!-- Título -->
    <h2 class="text-3xl font-extrabold text-center text-gray-800">
      🚍 Gestión de Salidas
    </h2>

    <!-- Formulario -->
    <form
      @submit.prevent="saveSalida"
      class="bg-white p-8 rounded-2xl shadow-md border border-gray-200 space-y-6"
    >
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <!-- Tours -->
        <div>
          <label class="block font-semibold text-gray-700 mb-2">Tour</label>
          <select
            v-model="selectedTour"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
          >
            <option disabled value="">Seleccione un tour</option>
            <option v-for="tour in tours" :key="tour.id" :value="tour.id">
              {{ tour.title }}
            </option>
          </select>
        </div>

        <!-- Chivas -->
        <div>
          <label class="block font-semibold text-gray-700 mb-2">Chiva</label>
          <select
            v-model="selectedChiva"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          >
            <option disabled value="">Seleccione una chiva</option>
            <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">
              {{ chiva.name }}
            </option>
          </select>
        </div>

        <!-- Hora salida -->
        <div>
          <label class="block font-semibold text-gray-700 mb-2">Hora de salida</label>
          <input
            type="time"
            v-model="departureTime"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-indigo-500 focus:outline-none"
          />
        </div>
      </div>

      <!-- Botones -->
      <div class="flex gap-4 justify-center">
        <button
          type="submit"
          class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          {{ editingId ? "💾 Guardar cambios" : "✅ Asignar salida" }}
        </button>

        <button
          v-if="editingId"
          type="button"
          @click="cancelEdit"
          class="bg-gray-400 hover:bg-gray-500 text-white px-6 py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          ❌ Cancelar
        </button>
      </div>
    </form>

    <!-- Lista de salidas -->
    <div v-if="salidas.length > 0" class="space-y-4">
      <h3 class="text-xl font-bold text-gray-800">📋 Salidas programadas</h3>
      <div class="overflow-hidden border border-gray-200 rounded-2xl shadow-sm">
        <table class="w-full text-left">
          <thead class="bg-gray-100 text-sm uppercase tracking-wide text-gray-600">
            <tr>
              <th class="px-6 py-3">Tour</th>
              <th class="px-6 py-3">Chiva</th>
              <th class="px-6 py-3">Salida</th>
              <th class="px-6 py-3">Estado</th>
              <th class="px-6 py-3 text-center">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr
              v-for="salida in salidas"
              :key="salida.id"
              class="hover:bg-gray-50 transition"
            >
              <td class="px-6 py-3 font-medium text-gray-700">
                {{ salida.tours?.title }}
              </td>
              <td class="px-6 py-3 text-gray-600">
                {{ salida.chivas?.name }}
              </td>
              <td class="px-6 py-3 text-gray-600">
                {{ new Date(salida.departure_at).toLocaleString() }}
              </td>
              <td class="px-6 py-3">
                <span
                  :class="{
                    'text-yellow-600 font-medium': salida.status === 'pendiente',
                    'text-green-600 font-semibold': salida.status === 'en_curso',
                    'text-gray-500 italic': salida.status === 'finalizado'
                  }"
                >
                  {{ salida.status }}
                </span>
              </td>
              <td class="px-6 py-3 flex gap-3 justify-center">
                <button
                  @click="editSalida(salida)"
                  class="bg-yellow-500 hover:bg-yellow-600 text-white px-4 py-2 rounded-lg text-sm font-medium shadow-sm transition active:scale-95"
                >
                  ✏️ Editar
                </button>
                <button
                  @click="deleteSalida(salida.id)"
                  class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium shadow-sm transition active:scale-95"
                >
                  🗑️ Eliminar
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <p v-else class="text-gray-500 text-center italic">
      🚫 No hay salidas programadas.
    </p>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();

const selectedTour = ref("");
const selectedChiva = ref("");
const departureTime = ref("");
const tours = ref([]);
const chivas = ref([]);
const salidas = ref([]);
const editingId = ref(null);

// 🔹 Cargar tours del dueño
const fetchTours = async () => {
  if (!auth.user) return;
  const { data, error } = await supabase
    .from("tours")
    .select("id, title")
    .eq("user_id", auth.user.id);

  if (!error) tours.value = data;
};

// 🔹 Cargar chivas del dueño
const fetchChivas = async () => {
  if (!auth.user) return;
  const { data, error } = await supabase
    .from("chivas")
    .select("id, name")
    .eq("user_id", auth.user.id);

  if (!error) chivas.value = data;
};

// 🔹 Cargar salidas activas solo del dueño
const fetchSalidas = async () => {
  if (!auth.user) return;

  const { data, error } = await supabase
    .from("assigned_chivas")
    .select(`
      id,
      departure_at,
      tours (id, title, user_id),
      chivas (id, name, user_id),
      status
    `)
    .eq("tours.user_id", auth.user.id)
    .order("departure_at", { ascending: true });

  if (!error) {
    salidas.value = (data || []).filter(
      (s) => s.tours !== null && s.chivas !== null
    );
  } else {
    console.error("Error cargando salidas:", error);
  }
};

// 🔹 Guardar/editar salida
const saveSalida = async () => {
  if (!selectedTour.value || !selectedChiva.value || !departureTime.value) {
    alert("Por favor completa todos los campos.");
    return;
  }

  const today = new Date().toISOString().split("T")[0];
  const departureTimestamp = new Date(`${today}T${departureTime.value}:00`);

  if (editingId.value) {
    await supabase
      .from("assigned_chivas")
      .update({
        tour_id: selectedTour.value,
        chiva_id: selectedChiva.value,
        departure_at: departureTimestamp.toISOString(),
        status: "pendiente",
      })
      .eq("id", editingId.value);
  } else {
    const { error } = await supabase.from("assigned_chivas").insert([
      {
        tour_id: selectedTour.value,
        chiva_id: selectedChiva.value,
        departure_at: departureTimestamp.toISOString(),
        user_id: auth.user.id,
        status: "pendiente",
      },
    ]);
    if (error) {
      console.error("Error al asignar salida:", error);
      alert("No se pudo asignar la salida.");
    }
  }

  cancelEdit();
  fetchSalidas();
};

// 🔹 Editar salida
const editSalida = (salida) => {
  editingId.value = salida.id;
  selectedTour.value = salida.tours?.id || "";
  selectedChiva.value = salida.chivas?.id || "";
  departureTime.value = salida.departure_at
    ? new Date(salida.departure_at).toISOString().substring(11, 16)
    : "";
};

// 🔹 Eliminar salida
const deleteSalida = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar esta salida?")) return;
  await supabase.from("assigned_chivas").delete().eq("id", id);
  fetchSalidas();
};

// 🔹 Cancelar edición
const cancelEdit = () => {
  editingId.value = null;
  selectedTour.value = "";
  selectedChiva.value = "";
  departureTime.value = "";
};

onMounted(() => {
  fetchTours();
  fetchChivas();
  fetchSalidas();
});
</script>
