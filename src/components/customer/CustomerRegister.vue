<template>
  <div class="flex items-center justify-center min-h-[80vh] p-4">
    <div class="bg-white rounded-2xl shadow-lg border border-gray-100 w-full max-w-sm p-8 space-y-5">
      <div class="text-center">
        <div class="flex justify-center mb-4"><BrandLogo :size="30" /></div>
        <h2 class="text-2xl font-extrabold text-gray-900">Crea tu cuenta</h2>
        <p class="text-sm text-gray-400 mt-1">Guarda y gestiona todas tus entradas</p>
      </div>

      <form @submit.prevent="register" class="space-y-4">
        <div>
          <label class="field-label">Nombre completo</label>
          <input v-model="fullName" type="text" required placeholder="Juan Pérez" class="field-input" />
        </div>
        <div>
          <label class="field-label">Correo electrónico</label>
          <input v-model="email" type="email" required placeholder="tu@correo.com" class="field-input" />
        </div>
        <div>
          <label class="field-label">Contraseña</label>
          <input v-model="password" type="password" required placeholder="Mín. 6 caracteres" class="field-input" />
        </div>

        <div v-if="error" class="bg-red-50 border border-red-200 text-red-600 text-sm rounded-xl px-4 py-3">{{ error }}</div>
        <div v-if="success" class="bg-green-50 border border-green-200 text-green-700 text-sm rounded-xl px-4 py-3 font-semibold">
          Cuenta creada. Ahora puedes iniciar sesión.
        </div>

        <button type="submit" :disabled="loading"
          class="w-full bg-orange-600 hover:bg-orange-700 disabled:opacity-50 text-white py-3 rounded-xl font-bold transition">
          {{ loading ? 'Creando cuenta...' : 'Crear cuenta' }}
        </button>
      </form>

      <p class="text-center text-sm text-gray-500">
        ¿Ya tienes cuenta?
        <RouterLink to="/cuenta/login" class="text-orange-600 font-semibold hover:underline">Iniciar sesión</RouterLink>
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/authStore'

const fullName = ref('')
const email    = ref('')
const password = ref('')
const error    = ref('')
const success  = ref(false)
const loading  = ref(false)
const router   = useRouter()
const auth     = useAuthStore()

const register = async () => {
  error.value   = ''
  success.value = false
  if (password.value.length < 6) { error.value = 'La contraseña debe tener al menos 6 caracteres.'; return }
  loading.value = true
  try {
    await auth.register(fullName.value, email.value, password.value, 'cliente')
    success.value = true
    setTimeout(() => router.push('/cuenta/login'), 1500)
  } catch (e) {
    error.value = e.message ?? 'Error al crear la cuenta.'
  }
  loading.value = false
}
</script>

<style scoped>
.field-input { width:100%; padding:0.625rem 1rem; border:1px solid #d1d5db; border-radius:0.75rem; font-size:0.875rem; outline:none; }
.field-input:focus { box-shadow:0 0 0 2px #ea580c; }
.field-label { display:block; font-size:0.75rem; font-weight:600; color:#374151; margin-bottom:0.25rem; }
</style>
