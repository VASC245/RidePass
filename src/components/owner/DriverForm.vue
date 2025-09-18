<template>
  <div class="max-w-5xl mx-auto py-10 space-y-6">
    <h2 class="text-2xl font-bold text-center">Gestión de Conductores</h2>

    <!-- Buscador -->
    <div class="bg-white shadow rounded-xl p-4 flex items-center gap-3">
      <input
        v-model="search"
        type="text"
        placeholder="Buscar conductor por nombre..."
        class="flex-1 p-2 border rounded"
      />
      <button
        @click="fetchConductores"
        class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded"
      >
        Buscar
      </button>
    </div>

    <!-- Lista de conductores disponibles -->
    <div class="bg-white rounded-xl shadow p-4">
      <h3 class="font-semibold mb-4">Conductores disponibles</h3>
      <div v-if="conductores.length === 0" class="text-gray-500">No se encontraron conductores</div>

      <div
        v-for="conductor in conductores"
        :key="conductor.id"
        class="flex items-center justify-between border-b py-2"
      >
        <div>
          <p class="font-medium">{{ conductor.full_name }}</p>
          <p class="text-sm text-gray-500">{{ conductor.email }}</p>
        </div>
        <select
          v-model="selectedChiva[conductor.id]"
          class="p-2 border rounded"
        >
          <option disabled value="">Asignar a chiva</option>
          <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">
            {{ chiva.name }}
          </option>
        </select>
        <button
          @click="assignConductor(conductor)"
          class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded"
        >
          Asignar
        </button>
      </div>
    </div>

    <!-- Conductores ya asignados -->
    <div class="bg-white rounded-xl shadow p-4">
      <h3 class="font-semibold mb-4">Conductores asignados</h3>
      <table class="w-full text-sm">
        <thead>
          <tr class="bg-gray-100">
            <th class="p-2 text-left">Nombre</th>
            <th class="p-2 text-left">Email</th>
            <th class="p-2 text-left">Chiva</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="driver in drivers" :key="driver.id" class="border-t">
            <td class="p-2">{{ driver.full_name }}</td>
            <td class="p-2">{{ driver.email }}</td>
            <td class="p-2">{{ driver.chivas?.name }}</td>
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
const conductores = ref([]);
const drivers = ref([]);
const chivas = ref([]);
const search = ref("");
const selectedChiva = ref({});

// 🔹 Buscar conductores en tabla users
const fetchConductores = async () => {
  let query = supabase.from("users").select("id, full_name, email").eq("role", "conductor");

  if (search.value) {
    query = query.ilike("full_name", `%${search.value}%`);
  }

  const { data, error } = await query;
  if (!error) conductores.value = data || [];
};

// 🔹 Traer chivas del dueño
const fetchChivas = async () => {
  const { data } = await supabase.from("chivas").select("id, name").eq("user_id", auth.user.id);
  chivas.value = data || [];
};

// 🔹 Traer conductores ya asignados del dueño
const fetchDrivers = async () => {
  const { data } = await supabase
    .from("drivers")
    .select("id, full_name, email, chivas(name)")
    .eq("owner_id", auth.user.id);

  drivers.value = data || [];
};

// 🔹 Asignar conductor a chiva
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
