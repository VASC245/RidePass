<template>
  <div class="flex items-center justify-center min-h-screen bg-gradient-to-br from-green-50 to-blue-50">
    <!-- Card principal -->
    <div
      class="bg-white p-10 rounded-2xl shadow-lg w-full max-w-md border border-gray-200"
    >
      <div class="flex justify-center mb-6">
        <BrandLogo :size="34" />
      </div>
      <h2 class="text-xl font-bold text-center text-gray-800 mb-6">
        Crear cuenta de vendedor
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
            <option value="dueño">Dueño de chivas</option>
            <option value="agencia">Agencia</option>
            <option value="conductor">Conductor</option>
            <option value="negocio">Negocio / Atracción</option>
          </select>
        </div>

        <div v-if="role === 'dueño'">
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Código de invitación
          </label>
          <input
            v-model.trim="ownerCode"
            type="text"
            required
            autocomplete="off"
            placeholder="Código entregado por ChivaPass"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none"
          />
          <p class="text-xs text-gray-500 mt-1">
            Las cuentas de dueño se activan con un código. Sin él, la cuenta se crea como agencia.
          </p>
        </div>

        <div v-if="error" class="bg-red-50 border border-red-200 text-red-600 text-sm rounded-xl px-4 py-3 font-medium">
          {{ error }}
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
          to="/panel/login"
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
import BrandLogo from "@/components/ui/BrandLogo.vue";

const fullName = ref("");
const email = ref("");
const password = ref("");
const role = ref("");
const ownerCode = ref("");

const router = useRouter();
const authStore = useAuthStore();

const error = ref("");

const register = async () => {
  error.value = "";
  if (!fullName.value || !email.value || !password.value || !role.value) {
    error.value = "Completa todos los campos.";
    return;
  }
  if (password.value.length < 6) {
    error.value = "La contraseña debe tener al menos 6 caracteres.";
    return;
  }
  if (role.value === "dueño" && !ownerCode.value) {
    error.value = "Ingresa el código de invitación para crear una cuenta de dueño.";
    return;
  }
  try {
    await authStore.register(fullName.value, email.value, password.value, role.value, ownerCode.value);
    router.push("/panel/login");
  } catch (e) {
    error.value = e.message ?? "Error al registrar. Intenta de nuevo.";
  }
};
</script>
