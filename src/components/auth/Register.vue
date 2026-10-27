<template>
  <div class="flex items-center justify-center min-h-screen bg-gradient-to-br from-brand-50 to-gray-50">
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
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
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
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
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
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
          />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Tipo de usuario
          </label>
          <select
            v-model="role"
            required
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-brand-500 focus:outline-none bg-white"
          >
            <option disabled value="">Selecciona un rol</option>
            <option value="dueño">Dueño de chivas</option>
            <option value="agencia">Agencia</option>
            <option value="conductor">Conductor</option>
            <option value="negocio">Negocio / Atracción</option>
          </select>
        </div>

        <div v-if="needsCode">
          <label class="block text-sm font-semibold text-gray-700 mb-2">
            Código de invitación
          </label>
          <input
            v-model.trim="inviteCode"
            type="text"
            required
            autocomplete="off"
            placeholder="Código entregado por chivaspass"
            class="w-full px-4 py-2.5 border border-gray-300 rounded-xl shadow-sm focus:ring-2 focus:ring-brand-500 focus:outline-none"
          />
          <p class="text-xs text-gray-500 mt-1">
            Las cuentas de vendedor y de agencia se activan con un código.
            Pídelo desde la <RouterLink to="/contacto?motivo=registro" class="font-semibold underline">página de contacto</RouterLink>.
          </p>
        </div>

        <div v-if="error" class="bg-red-50 border border-red-200 text-red-600 text-sm rounded-xl px-4 py-3 font-medium">
          {{ error }}
        </div>

        <div v-if="pendingConfirm" class="bg-brand-50 border border-brand-200 text-brand-800 text-sm rounded-xl px-4 py-3">
          Te enviamos un correo a <strong>{{ email }}</strong>. Abre el enlace para confirmar tu cuenta y luego inicia sesión.
        </div>

        <button
          type="submit"
          :disabled="loading || pendingConfirm"
          class="w-full bg-brand-600 hover:bg-brand-700 text-white py-3 rounded-xl font-semibold shadow-sm transition active:scale-95 disabled:opacity-60"
        >
          {{ loading ? "Creando cuenta..." : "Registrar" }}
        </button>
      </form>

      <p class="text-sm text-gray-600 mt-6 text-center">
        ¿Ya tienes una cuenta?
        <RouterLink
          to="/panel/login"
          class="text-brand-700 font-semibold hover:underline transition"
        >
          Iniciar sesión
        </RouterLink>
      </p>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/authStore";
import { supabase } from "@/lib/supabase";
import BrandLogo from "@/components/ui/BrandLogo.vue";

const fullName = ref("");
const email = ref("");
const password = ref("");
const role = ref("");
const inviteCode = ref("");
const loading = ref(false);
const pendingConfirm = ref(false);

const router = useRouter();
const authStore = useAuthStore();

const error = ref("");

// Dueño, agencia y negocio entran con un código de invitación de su rol
// (lo valida el trigger handle_new_user; sin código la cuenta queda como cliente).
const needsCode = computed(() => ["dueño", "agencia", "negocio"].includes(role.value));

const register = async () => {
  error.value = "";
  if (!fullName.value || !email.value || !password.value || !role.value) {
    error.value = "Completa todos los campos.";
    return;
  }
  if (password.value.length < 8) {
    error.value = "La contraseña debe tener al menos 8 caracteres.";
    return;
  }
  if (needsCode.value && !inviteCode.value) {
    error.value = "Ingresa tu código de invitación.";
    return;
  }
  loading.value = true;
  try {
    if (needsCode.value) {
      const { data: valid, error: codeErr } = await supabase.rpc("invite_code_valid", {
        p_code: inviteCode.value,
        p_role: role.value,
      });
      if (codeErr) throw new Error("No pudimos validar el código. Intenta de nuevo.");
      if (!valid) {
        error.value = "El código no es válido para este tipo de cuenta o ya fue usado.";
        return;
      }
    }
    const data = await authStore.register(fullName.value, email.value, password.value, role.value, inviteCode.value);
    // Con confirmación de correo activa no hay sesión hasta abrir el enlace
    if (data?.session) router.push("/panel/login");
    else pendingConfirm.value = true;
  } catch (e) {
    error.value = e.message ?? "Error al registrar. Intenta de nuevo.";
  } finally {
    loading.value = false;
  }
};
</script>
