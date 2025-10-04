<template>
  <div class="flex items-center justify-center min-h-screen bg-gradient-to-br from-green-50 to-blue-50">
    <!-- Card principal -->
    <div
      class="bg-white p-10 rounded-2xl shadow-lg w-full max-w-md border border-gray-200"
    >
      <h2 class="text-3xl font-extrabold text-center text-gray-800 mb-6">
        📝 Registrar Usuario
      </h2>

      <form @submit.prevent="register" class="space-y-5">
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Nombre completo
          </label>
          <input
            v-model="fullName"
            type="text"
            required
            placeholder="Tu nombre completo"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Correo electrónico
          </label>
          <input
            v-model="email"
            type="email"
            required
            placeholder="tu@correo.com"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Contraseña
          </label>
          <input
            v-model="password"
            type="password"
            required
            placeholder="********"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Tipo de usuario
          </label>
          <select
            v-model="role"
            required
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none bg-white"
          >
            <option disabled value="">Selecciona un rol</option>
            <option value="dueño">👑 Dueño</option>
            <option value="agencia">🏢 Agencia</option>
            <option value="conductor">🚌 Conductor</option>
          </select>
        </div>

        <button
          type="submit"
          class="w-full bg-green-600 hover:bg-green-700 text-white py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          Registrar
        </button>
      </form>

      <p class="text-sm text-gray-600 mt-6 text-center">
        ¿Ya tienes una cuenta?
        <RouterLink
          to="/login"
          class="text-green-600 font-semibold hover:underline transition"
        >
          Iniciar sesión
        </RouterLink>
      </p>
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
  await authStore.register(
    fullName.value,
    email.value,
    password.value,
    role.value
  );
  router.push("/login");
};
</script>
