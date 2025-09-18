<template>
  <div class="bg-white rounded-xl shadow p-6">
    <h3 class="text-lg font-bold mb-4">
      {{ editing ? "Editar chiva" : "Registrar nueva chiva" }}
    </h3>

    <form @submit.prevent="saveChiva" class="space-y-4">
      <div>
        <label class="block mb-1 text-sm font-medium">Nombre</label>
        <input v-model="form.name" type="text" class="w-full border rounded px-3 py-2" required />
      </div>

      <div>
        <label class="block mb-1 text-sm font-medium">Placa</label>
        <input v-model="form.plate" type="text" class="w-full border rounded px-3 py-2" required />
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="block mb-1 text-sm font-medium">Código</label>
          <input v-model="form.code" type="text" class="w-full border rounded px-3 py-2" required />
        </div>

        <div>
          <label class="block mb-1 text-sm font-medium">Capacidad</label>
          <input v-model.number="form.capacity" type="number" class="w-full border rounded px-3 py-2" required />
        </div>
      </div>

      <div class="flex gap-2">
        <button type="submit" class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded">
          {{ editing ? "Guardar cambios" : "Guardar chiva" }}
        </button>
        <button v-if="editing" type="button" @click="cancelEdit" class="bg-gray-400 text-white px-4 py-2 rounded">
          Cancelar
        </button>
      </div>
    </form>

    <div v-if="chivas.length" class="mt-8 space-y-2">
      <h4 class="font-semibold">Chivas registradas</h4>
      <div v-for="chiva in chivas" :key="chiva.id" class="bg-gray-50 rounded-lg p-3 flex justify-between items-center">
        <div>
          <p class="font-bold">{{ chiva.name }} ({{ chiva.code }})</p>
          <p class="text-sm text-gray-600">Placa: {{ chiva.plate }}</p>
          <p class="text-sm text-gray-600">Capacidad: {{ chiva.capacity }} personas</p>
        </div>
        <div class="flex gap-2">
          <button @click="editChiva(chiva)" class="bg-yellow-500 hover:bg-yellow-600 text-white px-3 py-1 rounded">
            Editar
          </button>
          <button @click="deleteChiva(chiva.id)" class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded">
            Eliminar
          </button>
        </div>
      </div>
    </div>
    <p v-else class="text-gray-500 mt-4">No hay chivas registradas.</p>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();

const form = ref({ name: "", plate: "", code: "", capacity: 40 });
const chivas = ref([]);
const editing = ref(false);
const editingId = ref(null);

const fetchChivas = async () => {
  if (!auth.user) return;
  const { data, error } = await supabase
    .from("chivas")
    .select("id, name, plate, code, capacity")
    .eq("user_id", auth.user.id)
    .order("created_at", { ascending: false });
  if (!error) chivas.value = data;
};

const saveChiva = async () => {
  if (!auth.user) {
    alert("⚠️ Debes iniciar sesión antes de crear chivas.");
    return;
  }
  if (editing.value) {
    await supabase.from("chivas")
      .update({ ...form.value })
      .eq("id", editingId.value)
      .eq("user_id", auth.user.id);
  } else {
    await supabase.from("chivas").insert([{ ...form.value, user_id: auth.user.id }]);
  }
  cancelEdit();
  fetchChivas();
};

const editChiva = (chiva) => {
  editing.value = true;
  editingId.value = chiva.id;
  form.value = { ...chiva };
};

const deleteChiva = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar esta chiva?")) return;
  await supabase.from("chivas").delete().eq("id", id).eq("user_id", auth.user.id);
  fetchChivas();
};

const cancelEdit = () => {
  editing.value = false;
  editingId.value = null;
  form.value = { name: "", plate: "", code: "", capacity: 40 };
};

onMounted(fetchChivas);
</script>
