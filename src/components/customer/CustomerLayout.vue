<template>
  <div class="min-h-screen bg-gray-50 flex flex-col">
    <nav class="bg-white border-b shadow-sm sticky top-0 z-40">
      <div class="max-w-4xl mx-auto px-6 py-4 flex items-center justify-between">
        <RouterLink to="/" class="flex items-center gap-3">
          <div class="w-9 h-9 bg-indigo-600 rounded-xl flex items-center justify-center text-white text-lg shadow">🎟️</div>
          <span class="text-lg font-extrabold text-gray-900 tracking-tight">ChivaPass</span>
        </RouterLink>

        <div class="flex items-center gap-3">
          <span v-if="user" class="text-sm text-gray-500 hidden sm:block">{{ user.full_name }}</span>
          <RouterLink v-if="!user" to="/cuenta/login"
            class="text-sm font-semibold text-indigo-600 hover:underline">Iniciar sesión</RouterLink>
          <button v-else @click="logout"
            class="text-sm font-semibold text-gray-500 hover:text-red-500 transition border border-gray-200 rounded-lg px-3 py-1.5">
            Salir
          </button>
        </div>
      </div>
    </nav>

    <main class="flex-1">
      <RouterView />
    </main>

    <footer class="bg-gray-900 text-gray-400 text-center py-6 text-xs">
      ChivaPass · Baños de Agua Santa · Ecuador
    </footer>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useAuthStore } from '@/stores/authStore'
import { useRouter } from 'vue-router'

const authStore = useAuthStore()
const router    = useRouter()
const user      = computed(() => authStore.user)

const logout = async () => {
  await authStore.logout()
  router.push('/cuenta/login')
}
</script>
