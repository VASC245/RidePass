<template>
  <div class="flex h-screen bg-gray-50">
    <!-- Sidebar para escritorio -->
    <aside class="hidden md:flex md:flex-col w-64 bg-white border-r shadow-lg p-4">
      <!-- Branding -->
      <div class="flex items-center space-x-2 mb-8">
        <span
          class="text-2xl font-bold"
          :class="user?.role === 'dueño' ? 'text-green-700' : user?.role === 'conductor' ? 'text-purple-700' : 'text-blue-700'"
        >
          ChivaPass
        </span>
      </div>

      <!-- Menú -->
      <nav class="flex-1 space-y-2">
        <RouterLink
          v-for="item in menuItems"
          :key="item.path"
          :to="item.path"
          class="block px-4 py-2 rounded-lg font-medium transition"
          :class="[
            user?.role === 'dueño'
              ? 'hover:bg-green-100 text-gray-700'
              : user?.role === 'conductor'
              ? 'hover:bg-purple-100 text-gray-700'
              : 'hover:bg-blue-100 text-gray-700'
          ]"
          active-class="bg-gray-200 font-semibold"
        >
          {{ item.label }}
        </RouterLink>
      </nav>

      <!-- Footer -->
      <div class="border-t pt-4">
        <p class="text-sm text-gray-500 mb-2">👤 {{ user?.full_name }}</p>
        <button
          @click="logout"
          class="w-full py-2 rounded font-semibold transition"
          :class="user?.role === 'dueño'
            ? 'bg-green-600 hover:bg-green-700 text-white'
            : user?.role === 'conductor'
            ? 'bg-purple-600 hover:bg-purple-700 text-white'
            : 'bg-blue-600 hover:bg-blue-700 text-white'"
        >
          Cerrar sesión
        </button>
      </div>
    </aside>

    <!-- Sidebar móvil (drawer) -->
    <transition name="slide">
      <div v-if="mobileOpen" class="fixed inset-0 z-40 flex">
        <!-- Fondo oscuro -->
        <div
          class="fixed inset-0 bg-black bg-opacity-50"
          @click="mobileOpen = false"
        ></div>

        <!-- Drawer -->
        <aside class="relative w-64 bg-white shadow-lg p-4 flex flex-col z-50">
          <div class="flex items-center justify-between mb-6">
            <h2
              class="text-xl font-bold"
              :class="user?.role === 'dueño' ? 'text-green-700' : user?.role === 'conductor' ? 'text-purple-700' : 'text-blue-700'"
            >
              ChivaPass
            </h2>
            <button @click="mobileOpen = false" class="text-gray-500">✖</button>
          </div>

          <nav class="flex-1 space-y-2">
            <RouterLink
              v-for="item in menuItems"
              :key="item.path"
              :to="item.path"
              @click="mobileOpen = false"
              class="block px-4 py-2 rounded-lg font-medium transition"
              :class="[
                user?.role === 'dueño'
                  ? 'hover:bg-green-100 text-gray-700'
                  : user?.role === 'conductor'
                  ? 'hover:bg-purple-100 text-gray-700'
                  : 'hover:bg-blue-100 text-gray-700'
              ]"
              active-class="bg-gray-200 font-semibold"
            >
              {{ item.label }}
            </RouterLink>
          </nav>

          <div class="border-t pt-4">
            <p class="text-sm text-gray-500 mb-2">👤 {{ user?.full_name }}</p>
            <button
              @click="logout"
              class="w-full py-2 rounded font-semibold transition"
              :class="user?.role === 'dueño'
                ? 'bg-green-600 hover:bg-green-700 text-white'
                : user?.role === 'conductor'
                ? 'bg-purple-600 hover:bg-purple-700 text-white'
                : 'bg-blue-600 hover:bg-blue-700 text-white'"
            >
              Cerrar sesión
            </button>
          </div>
        </aside>
      </div>
    </transition>

    <!-- Contenido principal -->
    <div class="flex-1 flex flex-col">
      <!-- Header -->
      <header class="bg-white border-b px-4 py-3 flex items-center justify-between shadow-sm">
        <h1 class="text-lg font-bold text-gray-700">
          <template v-if="user?.role === 'dueño'">👑 Panel Dueño</template>
          <template v-else-if="user?.role === 'agencia'">🏢 Panel Agencia</template>
          <template v-else-if="user?.role === 'conductor'">🚌 Panel Conductor</template>
        </h1>
        <!-- Botón hamburguesa móvil -->
        <button
          @click="mobileOpen = true"
          class="md:hidden text-gray-600 focus:outline-none"
        >
          ☰
        </button>
      </header>

      <!-- Main -->
      <main class="flex-1 p-6 overflow-y-auto">
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
      { label: "Gestión de Tours", path: "/nuevo-tour" },
      { label: "Asignar Salidas", path: "/asignar" },
      { label: "Embarque", path: "/embarque" },
      { label: "Mis Ventas", path: "/mis-ventas" },
    ];
  } else if (user?.role === "agencia") {
    return [
      { label: "Tours Disponibles", path: "/tours-disponibles" },
      { label: "Vender Boletos", path: "/vender-boletos" },
    ];
  } else if (user?.role === "conductor") {
    return [
      { label: "Mis Tours", path: "/mis-tours" }, // 👈 Nuevo menú para conductores
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
/* Animación del drawer móvil */
.slide-enter-active,
.slide-leave-active {
  transition: transform 0.3s ease;
}
.slide-enter-from,
.slide-leave-to {
  transform: translateX(-100%);
}
</style>
