<template>
  <div class="max-w-4xl mx-auto py-10 space-y-6">
    <h2 class="text-2xl font-bold text-center">Chivas registradas</h2>

    <!-- Formulario de registro -->
    <div class="bg-white p-4 rounded-2xl shadow space-y-4">
      <div>
        <label class="block text-sm mb-1">Nombre</label>
        <input v-model="nombre" class="w-full p-2 border rounded" />
      </div>

      <div>
        <label class="block text-sm mb-1">Placa</label>
        <input v-model="placa" class="w-full p-2 border rounded" />
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm mb-1">Código</label>
          <input v-model="codigo" class="w-full p-2 border rounded" />
        </div>
        <div>
          <label class="block text-sm mb-1">Capacidad</label>
          <input
            v-model="capacidad"
            type="number"
            class="w-full p-2 border rounded"
          />
        </div>
      </div>

      <button
        @click="saveChiva"
        class="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
      >
        Guardar chiva
      </button>
    </div>

    <!-- Lista de chivas -->
    <div v-if="chivas.length" class="space-y-4">
      <div
        v-for="chiva in chivas"
        :key="chiva.id"
        class="bg-white p-4 rounded-xl shadow flex justify-between items-center"
      >
        <div>
          <p class="font-semibold">{{ chiva.name }} ({{ chiva.code }})</p>
          <p class="text-sm text-gray-600">Placa: {{ chiva.plate }}</p>
          <p class="text-sm text-gray-600">
            Capacidad: {{ chiva.capacity }} personas
          </p>
        </div>

        <div class="flex gap-2">
          <button
            @click="editChiva(chiva)"
            class="bg-yellow-500 hover:bg-yellow-600 text-white px-3 py-1 rounded"
          >
            Editar
          </button>
          <button
            @click="deleteChiva(chiva.id)"
            class="bg-red-600 hover:bg-red-700 text-white px-3 py-1 rounded"
          >
            Eliminar
          </button>
        </div>
      </div>
    </div>
    <p v-else class="text-gray-500 text-center">No tienes chivas registradas.</p>
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

// 🔹 Cargar solo chivas del dueño logueado
const fetchChivas = async () => {
  if (!auth.user) return;

  const { data, error } = await supabase
    .from("chivas")
    .select("id, name, plate, code, capacity, user_id")
    .eq("user_id", auth.user.id); // 👈 solo chivas del dueño

  if (!error) {
    chivas.value = data;
  } else {
    console.error("Error cargando chivas:", error);
  }
};

// 🔹 Guardar o actualizar chiva
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
        user_id: auth.user.id, // 👈 se guarda con el dueño
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

// 🔹 Editar chiva
const editChiva = (chiva) => {
  editingId.value = chiva.id;
  nombre.value = chiva.name;
  placa.value = chiva.plate;
  codigo.value = chiva.code;
  capacidad.value = chiva.capacity;
};

// 🔹 Eliminar chiva
const deleteChiva = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar esta chiva?")) return;
  await supabase.from("chivas").delete().eq("id", id).eq("user_id", auth.user.id);
  fetchChivas();
};

// 🔹 Resetear formulario
const resetForm = () => {
  editingId.value = null;
  nombre.value = "";
  placa.value = "";
  codigo.value = "";
  capacidad.value = 40;
};

onMounted(fetchChivas);
</script>
