<template>
  <div class="flex items-center justify-center min-h-screen bg-gray-100">
    <div class="bg-white p-8 rounded-lg shadow-md w-full max-w-md">
      <h2 class="text-2xl font-bold mb-6 text-center">Iniciar sesión</h2>

      <form @submit.prevent="login">
        <div class="mb-4">
          <label class="block text-sm font-medium mb-1">Correo</label>
          <input
            v-model="email"
            type="email"
            required
            class="w-full border rounded px-3 py-2"
          />
        </div>
        <div class="mb-6">
          <label class="block text-sm font-medium mb-1">Contraseña</label>
          <input
            v-model="password"
            type="password"
            required
            class="w-full border rounded px-3 py-2"
          />
        </div>
        <button
          type="submit"
          class="w-full bg-blue-600 hover:bg-blue-700 text-white py-2 rounded"
        >
          Ingresar
        </button>
      </form>

      <p class="text-sm text-gray-600 mt-4 text-center">
        ¿No tienes cuenta?
        <button
          @click="showModal = true"
          class="text-blue-600 hover:underline"
        >
          Registrarse
        </button>
      </p>
    </div>

    <!-- Modal Clave Maestra -->
    <div
      v-if="showModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
    >
      <div class="bg-white p-6 rounded-lg shadow-lg w-full max-w-sm">
        <h3 class="text-lg font-bold mb-4">Clave maestra requerida</h3>
        <input
          v-model="masterKeyInput"
          type="password"
          placeholder="Ingresa clave maestra"
          class="w-full border rounded px-3 py-2 mb-4"
        />
        <div class="flex justify-between">
          <button
            @click="verifyKey"
            class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded"
          >
            Confirmar
          </button>
          <button
            @click="showModal = false"
            class="bg-gray-300 px-4 py-2 rounded"
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
    router.push("/register"); // ✅ redirige a la página de registro
  } else {
    alert("❌ Clave incorrecta");
  }
};
</script>
