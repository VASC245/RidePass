<template>
  <div class="max-w-6xl mx-auto py-10 px-6 space-y-10">
    <!-- Título -->
    <h2 class="text-3xl font-extrabold text-center text-gray-800">
      👨‍✈️ Gestión de Conductores
    </h2>

    <!-- Buscador -->
    <div
      class="bg-white border border-gray-200 rounded-2xl shadow-sm p-6 flex flex-col md:flex-row md:items-center gap-4"
    >
      <input
        v-model="search"
        type="text"
        placeholder="🔍 Buscar conductor por nombre..."
        class="flex-1 px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
      />
      <button
        @click="fetchConductores"
        class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2.5 rounded-xl font-semibold shadow-sm transition active:scale-95"
      >
        Buscar
      </button>
    </div>

    <!-- Lista de conductores disponibles -->
    <div class="bg-white rounded-2xl shadow-md border border-gray-200 p-8 space-y-4">
      <h3 class="text-lg font-bold text-gray-800 mb-4">
        🚦 Conductores Disponibles
      </h3>

      <div v-if="conductores.length === 0" class="text-gray-500 italic text-center">
        🚫 No se encontraron conductores.
      </div>

      <div
        v-for="conductor in conductores"
        :key="conductor.id"
        class="flex flex-col md:flex-row md:items-center justify-between border-b py-4 gap-3"
      >
        <div>
          <p class="font-semibold text-gray-800 text-lg">
            {{ conductor.full_name }}
          </p>
          <p class="text-sm text-gray-500">{{ conductor.email }}</p>
        </div>

        <div class="flex items-center gap-3">
          <select
            v-model="selectedChiva[conductor.id]"
            class="px-3 py-2 border border-gray-300 rounded-lg shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          >
            <option disabled value="">🚌 Asignar a chiva</option>
            <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">
              {{ chiva.name }}
            </option>
          </select>

          <button
            @click="assignConductor(conductor)"
            class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg font-medium shadow-sm transition active:scale-95"
          >
            ✅ Asignar
          </button>
        </div>
      </div>
    </div>

    <!-- Conductores asignados -->
    <div class="bg-white rounded-2xl shadow-md border border-gray-200 p-8 space-y-4">
      <h3 class="text-lg font-bold text-gray-800 mb-4">📋 Conductores Asignados</h3>

      <div v-if="drivers.length === 0" class="text-gray-500 italic text-center">
        🚫 No hay conductores asignados todavía.
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-sm text-left border-collapse">
          <thead class="bg-gray-100 text-gray-600 uppercase tracking-wide text-xs">
            <tr>
              <th class="px-4 py-3">Nombre</th>
              <th class="px-4 py-3">Email</th>
              <th class="px-4 py-3">Chiva</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-200">
            <tr
              v-for="driver in drivers"
              :key="driver.id"
              class="hover:bg-gray-50 transition"
            >
              <td class="px-4 py-3 font-medium text-gray-800">
                {{ driver.full_name }}
              </td>
              <td class="px-4 py-3 text-gray-600">
                {{ driver.email }}
              </td>
              <td class="px-4 py-3 text-gray-700">
                {{ driver.chivas?.name }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();
const conductores = ref([]);
const drivers = ref([]);
const chivas = ref([]);
const search = ref("");
const selectedChiva = ref({});

// 🔹 Buscar conductores
const fetchConductores = async () => {
  let query = supabase
    .from("users")
    .select("id, full_name, email")
    .eq("role", "conductor");

  if (search.value) {
    query = query.ilike("full_name", `%${search.value}%`);
  }

  const { data, error } = await query;
  if (!error) conductores.value = data || [];
};

// 🔹 Chivas del dueño
const fetchChivas = async () => {
  const { data } = await supabase
    .from("chivas")
    .select("id, name")
    .eq("user_id", auth.user.id);
  chivas.value = data || [];
};

// 🔹 Conductores asignados
const fetchDrivers = async () => {
  const { data } = await supabase
    .from("drivers")
    .select("id, full_name, email, chivas(name)")
    .eq("owner_id", auth.user.id);
  drivers.value = data || [];
};

// 🔹 Asignar conductor
const assignConductor = async (conductor) => {
  if (!selectedChiva.value[conductor.id]) {
    alert("Selecciona una chiva para asignar");
    return;
  }

  await supabase.from("drivers").insert([
    {
      user_id: conductor.id,
      full_name: conductor.full_name,
      email: conductor.email,
      chiva_id: selectedChiva.value[conductor.id],
      owner_id: auth.user.id,
    },
  ]);

  fetchDrivers();
};

onMounted(() => {
  fetchConductores();
  fetchChivas();
  fetchDrivers();
});
</script>
