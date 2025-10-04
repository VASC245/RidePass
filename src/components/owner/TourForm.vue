<template>
  <div class="bg-white rounded-2xl shadow-lg border border-gray-200 p-8 max-w-4xl mx-auto space-y-8">
    <!-- Título -->
    <h3 class="text-3xl font-extrabold text-center text-gray-800">
      {{ editing ? "✏️ Editar Tour" : "🎯 Crear Nuevo Tour" }}
    </h3>

    <!-- Formulario -->
    <form @submit.prevent="saveTour" class="space-y-6">
      <div>
        <label class="block mb-2 text-sm font-semibold text-gray-700">Título</label>
        <input
          v-model="form.title"
          type="text"
          class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
          required
        />
      </div>

      <div>
        <label class="block mb-2 text-sm font-semibold text-gray-700">Descripción</label>
        <textarea
          v-model="form.description"
          rows="3"
          class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
        ></textarea>
      </div>

      <div class="grid md:grid-cols-2 gap-6">
        <div>
          <label class="block mb-2 text-sm font-semibold text-gray-700">Precio base (USD)</label>
          <input
            v-model.number="form.base_price"
            type="number"
            step="0.01"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
            required
          />
        </div>

        <div>
          <label class="block mb-2 text-sm font-semibold text-gray-700">Duración (minutos)</label>
          <input
            v-model.number="form.duration"
            type="number"
            min="1"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-indigo-500 focus:outline-none"
            required
          />
        </div>
      </div>

      <!-- Botones -->
      <div class="flex gap-3 justify-center">
        <button
          type="submit"
          class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          {{ editing ? "💾 Guardar cambios" : "✅ Guardar tour" }}
        </button>
        <button
          v-if="editing"
          type="button"
          @click="cancelEdit"
          class="bg-gray-400 hover:bg-gray-500 text-white px-6 py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          ❌ Cancelar
        </button>
      </div>
    </form>

    <!-- Lista de tours -->
    <div v-if="tours.length" class="space-y-4 mt-10">
      <h4 class="font-bold text-lg text-gray-800 mb-4">📋 Tours Registrados</h4>

      <div
        v-for="tour in tours"
        :key="tour.id"
        class="bg-gray-50 rounded-xl p-5 border border-gray-200 shadow-sm flex justify-between items-start hover:shadow-md transition"
      >
        <div>
          <p class="font-bold text-gray-800 text-lg">{{ tour.title }} – ${{ tour.base_price }}</p>
          <p class="text-sm text-gray-600 mt-1">{{ tour.description }}</p>
          <p class="text-sm text-gray-600 mt-1">🕒 Duración: {{ tour.duration }} min</p>
        </div>

        <div class="flex gap-2">
          <button
            @click="editTour(tour)"
            class="bg-yellow-500 hover:bg-yellow-600 text-white px-4 py-2 rounded-lg text-sm font-medium shadow-sm transition active:scale-95"
          >
            ✏️ Editar
          </button>
          <button
            @click="deleteTour(tour.id)"
            class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium shadow-sm transition active:scale-95"
          >
            🗑️ Eliminar
          </button>
        </div>
      </div>
    </div>
    <p v-else class="text-gray-500 text-center italic mt-8">
      🚫 No hay tours registrados.
    </p>
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

// 🔹 Cargar tours del dueño
const fetchTours = async () => {
  if (!auth.user) return;
  const { data, error } = await supabase
    .from("tours")
    .select("id, title, description, base_price, duration")
    .eq("user_id", auth.user.id)
    .order("created_at", { ascending: false });
  if (!error) tours.value = data;
};

// 🔹 Guardar o editar tour
const saveTour = async () => {
  if (!auth.user) {
    alert("⚠️ Debes iniciar sesión antes de crear tours.");
    return;
  }

  if (editing.value) {
    await supabase
      .from("tours")
      .update({ ...form.value })
      .eq("id", editingId.value)
      .eq("user_id", auth.user.id);
  } else {
    await supabase
      .from("tours")
      .insert([{ ...form.value, user_id: auth.user.id }]);
  }

  cancelEdit();
  fetchTours();
};

// 🔹 Editar
const editTour = (tour) => {
  editing.value = true;
  editingId.value = tour.id;
  form.value = { ...tour };
};

// 🔹 Eliminar
const deleteTour = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar este tour?")) return;
  await supabase
    .from("tours")
    .delete()
    .eq("id", id)
    .eq("user_id", auth.user.id);
  fetchTours();
};

// 🔹 Cancelar
const cancelEdit = () => {
  editing.value = false;
  editingId.value = null;
  form.value = { title: "", description: "", base_price: 0, duration: 60 };
};

onMounted(fetchTours);
</script>
