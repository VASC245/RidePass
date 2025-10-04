<template>
  <div class="max-w-4xl mx-auto py-10 space-y-8">
    <!-- Título -->
    <h2 class="text-3xl font-extrabold text-center text-gray-800">
      🚌 Chivas registradas
    </h2>

    <!-- Formulario de registro -->
    <div class="bg-white p-8 rounded-2xl shadow-md border border-gray-200 space-y-6">
      <div>
        <label class="block text-sm font-semibold text-gray-700 mb-1">Nombre</label>
        <input
          v-model="nombre"
          class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
        />
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-700 mb-1">Placa</label>
        <input
          v-model="placa"
          class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
        />
      </div>

      <div class="grid grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-1">Código</label>
          <input
            v-model="codigo"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          />
        </div>
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-1">Capacidad</label>
          <input
            v-model="capacidad"
            type="number"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          />
        </div>
      </div>

      <!-- Botones -->
      <div class="flex gap-3">
        <button
          @click="saveChiva"
          class="flex-1 bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          {{ editingId ? "💾 Guardar cambios" : "✅ Guardar chiva" }}
        </button>
        <button
          v-if="editingId"
          @click="resetForm"
          class="bg-gray-400 hover:bg-gray-500 text-white px-6 py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          ❌ Cancelar
        </button>
      </div>
    </div>

    <!-- Lista de chivas -->
    <div v-if="chivas.length" class="space-y-4">
      <div
        v-for="chiva in chivas"
        :key="chiva.id"
        class="bg-white p-6 rounded-2xl shadow-sm border border-gray-200 flex justify-between items-center hover:shadow-md transition"
      >
        <div>
          <p class="font-bold text-gray-800">{{ chiva.name }} ({{ chiva.code }})</p>
          <p class="text-sm text-gray-600">🚗 Placa: {{ chiva.plate }}</p>
          <p class="text-sm text-gray-600">👥 Capacidad: {{ chiva.capacity }} personas</p>
        </div>

        <div class="flex gap-2">
          <button
            @click="editChiva(chiva)"
            class="bg-yellow-500 hover:bg-yellow-600 text-white px-4 py-2 rounded-lg text-sm font-medium shadow-sm transition active:scale-95"
          >
            ✏️ Editar
          </button>
          <button
            @click="deleteChiva(chiva.id)"
            class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium shadow-sm transition active:scale-95"
          >
            🗑️ Eliminar
          </button>
        </div>
      </div>
    </div>
    <p v-else class="text-gray-500 text-center italic">
      🚫 No tienes chivas registradas.
    </p>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();

const nombre = ref("");
const placa = ref("");
const codigo = ref("");
const capacidad = ref(40);
const chivas = ref([]);
const editingId = ref(null);

// 🔹 Cargar solo chivas del dueño
const fetchChivas = async () => {
  if (!auth.user) return;

  const { data, error } = await supabase
    .from("chivas")
    .select("id, name, plate, code, capacity, user_id")
    .eq("user_id", auth.user.id);

  if (!error) {
    chivas.value = data;
  } else {
    console.error("Error cargando chivas:", error);
  }
};

// 🔹 Guardar o actualizar
const saveChiva = async () => {
  if (!nombre.value || !placa.value || !codigo.value) {
    alert("Por favor completa todos los campos.");
    return;
  }
  if (!auth.user) {
    alert("⚠️ Debes iniciar sesión para guardar chivas.");
    return;
  }

  if (editingId.value) {
    const { error } = await supabase
      .from("chivas")
      .update({
        name: nombre.value,
        plate: placa.value,
        code: codigo.value,
        capacity: capacidad.value,
      })
      .eq("id", editingId.value)
      .eq("user_id", auth.user.id);

    if (error) {
      console.error("Error al actualizar chiva:", error);
      alert("No se pudo actualizar la chiva.");
    }
  } else {
    const { error } = await supabase.from("chivas").insert([
      {
        name: nombre.value,
        plate: placa.value,
        code: codigo.value,
        capacity: capacidad.value,
        user_id: auth.user.id,
      },
    ]);

    if (error) {
      console.error("Error al guardar chiva:", error);
      alert("No se pudo guardar la chiva.");
    }
  }

  resetForm();
  fetchChivas();
};

// 🔹 Editar
const editChiva = (chiva) => {
  editingId.value = chiva.id;
  nombre.value = chiva.name;
  placa.value = chiva.plate;
  codigo.value = chiva.code;
  capacidad.value = chiva.capacity;
};

// 🔹 Eliminar
const deleteChiva = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar esta chiva?")) return;
  await supabase.from("chivas").delete().eq("id", id).eq("user_id", auth.user.id);
  fetchChivas();
};

// 🔹 Resetear
const resetForm = () => {
  editingId.value = null;
  nombre.value = "";
  placa.value = "";
  codigo.value = "";
  capacidad.value = 40;
};

onMounted(fetchChivas);
</script>
