<template>
  <div class="max-w-4xl mx-auto py-10 space-y-6">
    <h2 class="text-2xl font-bold text-center">Asignar Chiva a Tour</h2>

    <!-- Formulario -->
    <div
      class="grid grid-cols-1 md:grid-cols-3 gap-4 items-end bg-white p-4 rounded-2xl shadow"
    >
      <div>
        <label class="block text-sm mb-1">Tour</label>
        <select v-model="selectedTour" class="w-full p-2 border rounded">
          <option disabled value="">Selecciona un tour</option>
          <option v-for="tour in tours" :key="tour.id" :value="tour.id">
            {{ tour.title }}
          </option>
        </select>
      </div>

      <div>
        <label class="block text-sm mb-1">Chiva</label>
        <select v-model="selectedChiva" class="w-full p-2 border rounded">
          <option disabled value="">Selecciona una chiva</option>
          <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">
            {{ chiva.name }}
          </option>
        </select>
      </div>

      <div>
        <label class="block text-sm mb-1">Hora de salida</label>
        <input
          type="time"
          v-model="departureTime"
          class="w-full p-2 border rounded"
        />
      </div>

      <div class="md:col-span-3">
        <button
          @click="saveSalida"
          class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
        >
          {{ editingId ? "Guardar cambios" : "Asignar" }}
        </button>
        <button
          v-if="editingId"
          @click="cancelEdit"
          class="bg-gray-400 text-white px-4 py-2 rounded ml-2"
        >
          Cancelar
        </button>
      </div>
    </div>

    <!-- Tabla -->
    <div v-if="salidas.length" class="mt-10">
      <h3 class="text-lg font-semibold mb-2">Salidas Programadas</h3>
      <table class="w-full bg-white rounded-xl overflow-hidden">
        <thead class="bg-gray-100 text-left text-sm">
          <tr>
            <th class="p-2">Tour</th>
            <th class="p-2">Chiva</th>
            <th class="p-2">Hora de salida</th>
            <th class="p-2 text-center">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="salida in salidas"
            :key="salida.id"
            class="border-t text-sm"
          >
            <td class="p-2">{{ salida.tours?.title || "Sin tour" }}</td>
            <td class="p-2">{{ salida.chivas?.name || "Sin chiva" }}</td>
            <td class="p-2">
              {{
                salida.departure_at
                  ? new Date(salida.departure_at).toLocaleTimeString([], {
                      hour: "2-digit",
                      minute: "2-digit",
                    })
                  : "-"
              }}
            </td>
            <td class="p-2 text-center flex gap-2 justify-center">
              <button
                @click="editSalida(salida)"
                class="bg-yellow-500 hover:bg-yellow-600 text-white px-3 py-1 rounded"
              >
                Editar
              </button>
              <button
                @click="deleteSalida(salida.id)"
                class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded"
              >
                Eliminar
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
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
    // ✅ Mostrar solo asignaciones activas (evitar tours borrados o finalizados)
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
        status: "pendiente", // 👈 por defecto cuando se edita
      })
      .eq("id", editingId.value);
  } else {
    const { error } = await supabase.from("assigned_chivas").insert([
      {
        tour_id: selectedTour.value,
        chiva_id: selectedChiva.value,
        departure_at: departureTimestamp.toISOString(),
        user_id: auth.user.id,
        status: "pendiente", // 👈 nuevo campo para controlar estados
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

// 🔹 Eliminar salida manualmente (dueño)
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


