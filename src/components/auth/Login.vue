<template>
  <div class="flex items-center justify-center min-h-screen bg-gradient-to-br from-blue-50 to-green-50">
    <!-- Card principal -->
    <div
      class="bg-white p-10 rounded-2xl shadow-lg w-full max-w-md border border-gray-200"
    >
      <h2 class="text-3xl font-extrabold mb-6 text-center text-gray-800">
        🚍 Iniciar Sesión
      </h2>

      <form @submit.prevent="login" class="space-y-5">
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Correo electrónico
          </label>
          <input
            v-model="email"
            type="email"
            required
            placeholder="tu@correo.com"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
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
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-blue-500 focus:outline-none"
          />
        </div>

        <button
          type="submit"
          class="w-full bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          Ingresar
        </button>
      </form>

      <p class="text-sm text-gray-600 mt-6 text-center">
        ¿No tienes cuenta?
        <button
          @click="showModal = true"
          class="text-blue-600 font-semibold hover:underline transition"
        >
          Registrarse
        </button>
      </p>
    </div>

    <!-- Modal Clave Maestra -->
    <div
      v-if="showModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
    >
      <div
        class="bg-white p-8 rounded-2xl shadow-lg w-full max-w-sm border border-gray-200 space-y-4"
      >
        <h3 class="text-xl font-bold text-center text-gray-800">
          🔐 Clave Maestra Requerida
        </h3>
        <p class="text-sm text-gray-600 text-center">
          Ingresa la clave maestra para continuar al registro.
        </p>

        <input
          v-model="masterKeyInput"
          type="password"
          placeholder="••••••••"
          class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-green-500 focus:outline-none mt-2"
        />

        <div class="flex justify-between pt-4">
          <button
            @click="verifyKey"
            class="bg-green-600 hover:bg-green-700 text-white px-5 py-2.5 rounded-xl font-semibold shadow-sm transition active:scale-95"
          >
            Confirmar
          </button>
          <button
            @click="showModal = false"
            class="bg-gray-300 hover:bg-gray-400 text-gray-800 px-5 py-2.5 rounded-xl font-semibold shadow-sm transition active:scale-95"
          >
            Cancelar
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/authStore";

const email = ref("");
const password = ref("");
const showModal = ref(false);
const masterKeyInput = ref("");

const router = useRouter();
const authStore = useAuthStore();

const login = async () => {
  await authStore.login(email.value, password.value);
  router.push("/");
};

const verifyKey = () => {
  if (masterKeyInput.value === "CHIVASPASS2025") {
    showModal.value = false;
    router.push("/register");
  } else {
    alert("❌ Clave incorrecta");
  }
};
</script>
