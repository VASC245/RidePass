<template>
  <div class="bg-white rounded-xl shadow p-6 max-w-3xl mx-auto">
    <h3 class="text-lg font-bold mb-4">{{ editing ? "Editar tour" : "Crear nuevo tour" }}</h3>

    <form @submit.prevent="saveTour" class="space-y-4">
      <div>
        <label class="block mb-1 text-sm font-medium">Título</label>
        <input v-model="form.title" type="text" class="w-full border rounded px-3 py-2" required />
      </div>

      <div>
        <label class="block mb-1 text-sm font-medium">Descripción</label>
        <textarea v-model="form.description" class="w-full border rounded px-3 py-2" rows="3"></textarea>
      </div>

      <div>
        <label class="block mb-1 text-sm font-medium">Precio base</label>
        <input v-model.number="form.base_price" type="number" step="0.01" class="w-full border rounded px-3 py-2" required />
      </div>

      <div>
        <label class="block mb-1 text-sm font-medium">Duración (minutos)</label>
        <input v-model.number="form.duration" type="number" min="1" class="w-full border rounded px-3 py-2" required />
      </div>

      <div class="flex gap-2">
        <button type="submit" class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded">
          {{ editing ? "Guardar cambios" : "Guardar tour" }}
        </button>
        <button v-if="editing" type="button" @click="cancelEdit" class="bg-gray-400 text-white px-4 py-2 rounded">Cancelar</button>
      </div>
    </form>

    <div v-if="tours.length" class="mt-8 space-y-2">
      <h4 class="font-semibold">Tours registrados</h4>
      <div v-for="tour in tours" :key="tour.id" class="bg-gray-50 rounded-lg p-3 flex justify-between items-center">
        <div>
          <p class="font-bold">{{ tour.title }} – ${{ tour.base_price }}</p>
          <p class="text-sm text-gray-600">{{ tour.description }}</p>
          <p class="text-sm text-gray-600">Duración: {{ tour.duration }} min</p>
        </div>
        <div class="flex gap-2">
          <button @click="editTour(tour)" class="bg-yellow-500 hover:bg-yellow-600 text-white px-3 py-1 rounded">Editar</button>
          <button @click="deleteTour(tour.id)" class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded">Eliminar</button>
        </div>
      </div>
    </div>
    <p v-else class="text-gray-500 mt-4">No hay tours registrados.</p>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();

const form = ref({ title: "", description: "", base_price: 0, duration: 60 });
const tours = ref([]);
const editing = ref(false);
const editingId = ref(null);

const fetchTours = async () => {
  if (!auth.user) return;
  const { data, error } = await supabase
    .from("tours")
    .select("id, title, description, base_price, duration")
    .eq("user_id", auth.user.id)
    .order("created_at", { ascending: false });
  if (!error) tours.value = data;
};

const saveTour = async () => {
  if (!auth.user) {
    alert("⚠️ Debes iniciar sesión antes de crear tours.");
    return;
  }
  if (editing.value) {
    await supabase.from("tours")
      .update({ ...form.value })
      .eq("id", editingId.value)
      .eq("user_id", auth.user.id);
  } else {
    await supabase.from("tours").insert([{ ...form.value, user_id: auth.user.id }]);
  }
  cancelEdit();
  fetchTours();
};

const editTour = (tour) => {
  editing.value = true;
  editingId.value = tour.id;
  form.value = { ...tour };
};

const deleteTour = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar este tour?")) return;
  await supabase.from("tours").delete().eq("id", id).eq("user_id", auth.user.id);
  fetchTours();
};

const cancelEdit = () => {
  editing.value = false;
  editingId.value = null;
  form.value = { title: "", description: "", base_price: 0, duration: 60 };
};

onMounted(fetchTours);
</script>
