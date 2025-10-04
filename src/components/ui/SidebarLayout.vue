<template>
  <div class="flex h-screen bg-gray-100 font-inter">
    <!-- Sidebar escritorio -->
    <aside
      class="hidden md:flex md:flex-col w-64 bg-white border-r shadow-xl p-6 rounded-tr-3xl rounded-br-3xl transition-all duration-300"
    >
      <!-- Branding -->
      <div class="flex items-center space-x-2 mb-10">
        <div
          class="w-10 h-10 flex items-center justify-center rounded-xl shadow-md"
          :class="user?.role === 'dueño'
            ? 'bg-green-600 text-white'
            : user?.role === 'conductor'
            ? 'bg-orange-600 text-white'
            : 'bg-blue-600 text-white'"
        >
          🚍
        </div>
        <span class="text-2xl font-extrabold tracking-tight text-gray-800">
          ChivaPass
        </span>
      </div>

      <!-- Menú -->
      <nav class="flex-1 space-y-2">
        <RouterLink
          v-for="item in menuItems"
          :key="item.path"
          :to="item.path"
          class="flex items-center space-x-3 px-4 py-3 rounded-xl font-medium transition-all duration-200"
          :class="[
            user?.role === 'dueño'
              ? 'hover:bg-green-50 text-gray-700'
              : user?.role === 'conductor'
              ? 'hover:bg-orange-50 text-gray-700'
              : 'hover:bg-blue-50 text-gray-700'
          ]"
          active-class="bg-gray-200 text-gray-900 font-semibold shadow-sm"
        >
          <span class="text-lg">➡️</span>
          <span>{{ item.label }}</span>
        </RouterLink>
      </nav>

      <!-- Footer -->
      <div class="border-t mt-6 pt-4">
        <p class="text-sm text-gray-500 mb-2 font-medium">
          👤 {{ user?.full_name }}
        </p>
        <button
          @click="logout"
          class="w-full py-2 rounded-xl font-semibold transition-all shadow-sm"
          :class="user?.role === 'dueño'
            ? 'bg-green-600 hover:bg-green-700 text-white'
            : user?.role === 'conductor'
            ? 'bg-orange-600 hover:bg-orange-700 text-white'
            : 'bg-blue-600 hover:bg-blue-700 text-white'"
        >
          Cerrar sesión
        </button>
      </div>
    </aside>

    <!-- Sidebar móvil (responsive) -->
    <transition name="slide">
      <aside
        v-if="mobileOpen"
        class="fixed inset-0 bg-black bg-opacity-40 flex md:hidden z-50"
        @click.self="mobileOpen = false"
      >
        <div
          class="w-64 h-full bg-white p-6 shadow-2xl rounded-tr-3xl rounded-br-3xl flex flex-col"
        >
          <div class="flex items-center justify-between mb-8">
            <div class="flex items-center gap-2">
              <div
                class="w-10 h-10 flex items-center justify-center rounded-xl shadow-md"
                :class="user?.role === 'dueño'
                  ? 'bg-green-600 text-white'
                  : user?.role === 'conductor'
                  ? 'bg-orange-600 text-white'
                  : 'bg-blue-600 text-white'"
              >
                🚍
              </div>
              <span class="text-xl font-bold text-gray-800">ChivaPass</span>
            </div>
            <button
              @click="mobileOpen = false"
              class="text-gray-600 text-2xl hover:text-red-500"
            >
              ✖
            </button>
          </div>

          <nav class="flex-1 space-y-2 overflow-y-auto">
            <RouterLink
              v-for="item in menuItems"
              :key="item.path"
              :to="item.path"
              @click="mobileOpen = false"
              class="block px-4 py-3 rounded-lg font-medium text-gray-700 hover:bg-gray-100 transition"
              active-class="bg-gray-200 text-gray-900 font-semibold shadow-sm"
            >
              {{ item.label }}
            </RouterLink>
          </nav>

          <div class="border-t mt-6 pt-4">
            <button
              @click="logout"
              class="w-full py-2 rounded-lg font-semibold text-white transition-all"
              :class="user?.role === 'dueño'
                ? 'bg-green-600 hover:bg-green-700'
                : user?.role === 'conductor'
                ? 'bg-orange-600 hover:bg-orange-700'
                : 'bg-blue-600 hover:bg-blue-700'"
            >
              Cerrar sesión
            </button>
          </div>
        </div>
      </aside>
    </transition>

    <!-- Contenido principal -->
    <div class="flex-1 flex flex-col">
      <!-- Header -->
      <header
        class="bg-white border-b px-6 py-4 flex items-center justify-between shadow-sm"
      >
        <h1 class="text-xl font-bold text-gray-800 tracking-tight">
          {{ user?.role === 'dueño'
            ? '👑 Panel Dueño'
            : user?.role === 'conductor'
            ? '🚌 Panel Conductor'
            : '🏢 Panel Agencia' }}
        </h1>
        <!-- Botón menú móvil -->
        <button
          @click="mobileOpen = true"
          class="md:hidden text-gray-600 focus:outline-none text-3xl"
        >
          ☰
        </button>
      </header>

      <!-- Main -->
      <main class="flex-1 p-8 overflow-y-auto bg-gray-50">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/authStore";

const router = useRouter();
const authStore = useAuthStore();
const user = authStore.user;
const mobileOpen = ref(false);

const menuItems = computed(() => {
  if (user?.role === "dueño") {
    return [
      { label: "Dashboard", path: "/dashboard" },
      { label: "Mis Chivas", path: "/chivas" },
      { label: "Conductores", path: "/conductores" },
      { label: "Tours", path: "/tours" },
      { label: "Gestión de Tours", path: "/nuevo-tour" },
      { label: "Asignar Salidas", path: "/asignar" },
      { label: "Embarque (Escanear)", path: "/embarque" },
      { label: "Mis Ventas", path: "/mis-ventas" },
    ];
  } else if (user?.role === "agencia") {
    return [
      { label: "Tours Disponibles", path: "/tours-disponibles" },
      { label: "Vender Boletos", path: "/vender-boletos" },
    ];
  } else if (user?.role === "conductor") {
    return [
      { label: "Mis Tours", path: "/mis-tours" },
      { label: "Escanear QR", path: "/escanear" },
    ];
  }
  return [];
});

const logout = async () => {
  await authStore.logout();
  router.push("/login");
};
</script>

<style scoped>
/* Animación del slide del sidebar móvil */
.slide-enter-active,
.slide-leave-active {
  transition: all 0.3s ease;
}
.slide-enter-from {
  transform: translateX(-100%);
  opacity: 0;
}
.slide-leave-to {
  transform: translateX(-100%);
  opacity: 0;
}
</style>
