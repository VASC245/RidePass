<template>
  <div class="flex items-center justify-center min-h-[80vh] p-4">
    <div class="bg-white rounded-2xl shadow-lg border border-gray-100 w-full max-w-sm p-8 space-y-5">
      <div class="text-center">
        <div class="flex justify-center mb-4"><BrandLogo :size="30" /></div>
        <h2 class="text-2xl font-extrabold text-gray-900">Mis Tickets</h2>
        <p class="text-sm text-gray-400 mt-1">Inicia sesión para ver tus entradas</p>
      </div>

      <form @submit.prevent="login" class="space-y-4">
        <div>
          <label class="field-label">Correo electrónico</label>
          <input v-model="email" type="email" required placeholder="tu@correo.com" class="field-input" />
        </div>
        <div>
          <label class="field-label">Contraseña</label>
          <input v-model="password" type="password" required placeholder="••••••••" class="field-input" />
        </div>

        <div v-if="error" class="bg-red-50 border border-red-200 text-red-600 text-sm rounded-xl px-4 py-3">{{ error }}</div>

        <button type="submit" :disabled="loading"
          class="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white py-3 rounded-xl font-bold transition">
          {{ loading ? 'Entrando...' : 'Ver mis entradas →' }}
        </button>
      </form>

      <p class="text-center text-sm text-gray-500">
        ¿Primera vez?
        <RouterLink to="/cuenta/registro" class="text-indigo-600 font-semibold hover:underline">Crea tu cuenta</RouterLink>
      </p>
      <p class="text-center text-xs text-gray-400">
        <RouterLink to="/" class="hover:underline">← Volver al inicio</RouterLink>
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/authStore'

const email    = ref('')
const password = ref('')
const error    = ref('')
const loading  = ref(false)
const router   = useRouter()
const auth     = useAuthStore()

const login = async () => {
  loading.value = true
  error.value   = ''
  try {
    await auth.login(email.value, password.value)
    if (auth.user?.role === 'cliente') {
      router.push('/cuenta/mis-tickets')
    } else {
      // Si es otro rol, redirige a su panel
      const dest = { dueño: '/panel/dashboard', agencia: '/panel/tours-disponibles', conductor: '/panel/mis-tours', negocio: '/panel/negocio-dashboard' }
      router.push(dest[auth.user?.role] ?? '/panel/dashboard')
    }
  } catch {
    error.value = 'Correo o contraseña incorrectos'
  }
  loading.value = false
}
</script>

<style scoped>
.field-input { width:100%; padding:0.625rem 1rem; border:1px solid #d1d5db; border-radius:0.75rem; font-size:0.875rem; outline:none; }
.field-input:focus { box-shadow:0 0 0 2px #6366f1; }
.field-label { display:block; font-size:0.75rem; font-weight:600; color:#374151; margin-bottom:0.25rem; }
</style>
