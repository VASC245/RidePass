<template>
  <div class="max-w-6xl mx-auto py-10 px-6 space-y-8">
    <div>
      <h2 class="text-2xl font-bold text-gray-900">Conductores</h2>
      <p class="text-sm text-gray-500 mt-1">
        El conductor se registra en chivaspass con el rol "conductor". Búscalo por su correo exacto y asígnalo a una de tus chivas.
      </p>
    </div>

    <!-- Buscador por correo -->
    <form @submit.prevent="fetchConductor" class="bg-white border border-gray-200 rounded-2xl p-6 space-y-4">
      <div class="flex flex-col md:flex-row md:items-end gap-4">
        <div class="flex-1">
          <label class="field-label">Correo del conductor</label>
          <input v-model="search" type="email" placeholder="conductor@correo.com" class="field-input" required />
        </div>
        <button type="submit" :disabled="searching"
          class="px-5 py-2.5 rounded-xl bg-gray-900 text-white text-sm font-semibold hover:bg-gray-800 disabled:opacity-50">
          {{ searching ? 'Buscando...' : 'Buscar' }}
        </button>
      </div>

      <p v-if="searchMsg" class="text-sm text-gray-500">{{ searchMsg }}</p>
      <p v-if="formError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ formError }}</p>

      <div v-if="found" class="flex flex-col md:flex-row md:items-center justify-between gap-4 border-t border-gray-100 pt-4">
        <div>
          <p class="font-semibold text-gray-900">{{ found.full_name }}</p>
          <p class="text-sm text-gray-500">{{ found.email }}</p>
        </div>
        <div class="flex items-center gap-3">
          <select v-model="selectedChiva" class="field-input bg-white md:w-56">
            <option disabled value="">Asignar a chiva</option>
            <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">{{ chiva.name }}</option>
          </select>
          <button type="button" @click="assignConductor" :disabled="saving"
            class="px-4 py-2.5 rounded-xl bg-orange-600 hover:bg-orange-700 text-white text-sm font-semibold disabled:opacity-50">
            {{ saving ? 'Guardando...' : 'Asignar' }}
          </button>
        </div>
      </div>
    </form>

    <!-- Conductores asignados -->
    <div v-if="drivers.length > 0" class="overflow-x-auto border border-gray-200 rounded-2xl">
      <table class="w-full text-left text-sm">
        <thead class="bg-gray-50 text-xs uppercase tracking-wide text-gray-500">
          <tr>
            <th class="px-5 py-3">Nombre</th>
            <th class="px-5 py-3">Correo</th>
            <th class="px-5 py-3">Chiva</th>
            <th class="px-5 py-3 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          <tr v-for="driver in drivers" :key="driver.id" class="hover:bg-gray-50">
            <td class="px-5 py-3 font-medium text-gray-800">{{ driver.full_name }}</td>
            <td class="px-5 py-3 text-gray-600">{{ driver.email }}</td>
            <td class="px-5 py-3 text-gray-700">{{ driver.chivas?.name }}</td>
            <td class="px-5 py-3 text-right">
              <button @click="removeDriver(driver)"
                class="px-3 py-1.5 rounded-lg border border-red-200 text-xs font-semibold text-red-700 hover:bg-red-50">
                Quitar
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <p v-else class="text-gray-500 text-center py-10 rounded-2xl border border-dashed border-gray-300">
      Aún no tienes conductores asignados.
    </p>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();
const search = ref("");
const searching = ref(false);
const searchMsg = ref("");
const found = ref(null);
const selectedChiva = ref("");
const saving = ref(false);
const formError = ref("");
const drivers = ref([]);
const chivas = ref([]);

// find_conductor devuelve un solo conductor por correo exacto: un dueño ya
// no puede listar a todos los conductores registrados en la plataforma.
const fetchConductor = async () => {
  formError.value = "";
  found.value = null;
  searchMsg.value = "";
  searching.value = true;
  const { data, error } = await supabase.rpc("find_conductor", { p_email: search.value.trim() });
  searching.value = false;
  if (error) {
    console.error("find_conductor:", error.message);
    formError.value = "No se pudo buscar el conductor.";
    return;
  }
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    searchMsg.value = "No hay ningún conductor registrado con ese correo. Pídele que se registre en chivaspass con el rol conductor.";
    return;
  }
  found.value = row;
};

const fetchChivas = async () => {
  const { data } = await supabase.from("chivas").select("id, name").eq("user_id", auth.user.id).order("name");
  chivas.value = data || [];
};

const fetchDrivers = async () => {
  const { data } = await supabase
    .from("drivers")
    .select("id, full_name, email, chivas(name)")
    .eq("owner_id", auth.user.id)
    .order("full_name");
  drivers.value = data || [];
};

const assignConductor = async () => {
  if (!found.value) return;
  if (!selectedChiva.value) { formError.value = "Selecciona una chiva para asignar."; return; }
  saving.value = true;
  formError.value = "";
  const { error } = await supabase.from("drivers").insert([{
    user_id: found.value.id,
    full_name: found.value.full_name,
    email: found.value.email,
    chiva_id: selectedChiva.value,
    owner_id: auth.user.id,
  }]);
  saving.value = false;
  if (error) {
    console.error("drivers insert:", error.message);
    formError.value = "No se pudo asignar el conductor.";
    return;
  }
  found.value = null;
  search.value = "";
  selectedChiva.value = "";
  fetchDrivers();
};

const removeDriver = async (driver) => {
  if (!confirm(`¿Quitar a ${driver.full_name} de ${driver.chivas?.name ?? "la chiva"}?`)) return;
  const { error } = await supabase.from("drivers").delete().eq("id", driver.id).eq("owner_id", auth.user.id);
  if (error) { formError.value = "No se pudo quitar el conductor."; return; }
  fetchDrivers();
};

onMounted(() => {
  fetchChivas();
  fetchDrivers();
});
</script>

<style scoped>
.field-input {
  width: 100%;
  padding: 0.625rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.75rem;
  font-size: 0.875rem;
  outline: none;
}
.field-input:focus { box-shadow: 0 0 0 2px #ea580c; }
.field-label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.375rem;
}
</style>
