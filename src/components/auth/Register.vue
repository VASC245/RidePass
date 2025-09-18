<template>
  <div class="flex items-center justify-center min-h-screen bg-gray-100">
    <div class="bg-white p-8 rounded-lg shadow-md w-full max-w-md">
      <h2 class="text-2xl font-bold mb-6 text-center">Registrar usuario</h2>

      <form @submit.prevent="register">
        <div class="mb-4">
          <label class="block text-sm font-medium mb-1">Nombre completo</label>
          <input
            v-model="fullName"
            type="text"
            required
            class="w-full border rounded px-3 py-2"
          />
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium mb-1">Correo</label>
          <input
            v-model="email"
            type="email"
            required
            class="w-full border rounded px-3 py-2"
          />
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium mb-1">Contraseña</label>
          <input
            v-model="password"
            type="password"
            required
            class="w-full border rounded px-3 py-2"
          />
        </div>

        <div class="mb-6">
          <label class="block text-sm font-medium mb-1">Tipo de usuario</label>
          <select
            v-model="role"
            required
            class="w-full border rounded px-3 py-2"
          >
            <option disabled value="">Selecciona un rol</option>
            <option value="dueño">Dueño</option>
            <option value="agencia">Agencia</option>
            <!-- ✅ Nuevo rol conductor -->
            <option value="conductor">Conductor</option>
          </select>
        </div>

        <button
          type="submit"
          class="w-full bg-green-600 hover:bg-green-700 text-white py-2 rounded"
        >
          Registrar
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/authStore";

const fullName = ref("");
const email = ref("");
const password = ref("");
const role = ref("");

const router = useRouter();
const authStore = useAuthStore();

const register = async () => {
  await authStore.register(fullName.value, email.value, password.value, role.value);
  router.push("/login");
};
</script>
