<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50 p-4">
    <div class="w-full max-w-sm rounded-xl border border-gray-200 bg-white p-8">
      <div class="mb-6 flex justify-center"><BrandLogo :size="30" /></div>

      <!-- Sin sesión de recuperación: enlace vencido, ya usado o abierto en otro navegador -->
      <template v-if="!hasSession">
        <div class="flex size-11 items-center justify-center rounded-full bg-warn-50 text-warn-700">
          <PhLinkBreak :size="22" />
        </div>
        <h1 class="mt-4 text-xl font-bold tracking-[-0.015em] text-gray-900">El enlace ya no sirve</h1>
        <p class="mt-2 text-sm text-gray-700">
          Puede que haya vencido, que ya lo hayas usado o que lo abrieras en otro navegador. Pide uno nuevo.
        </p>
        <RouterLink to="/recuperar-contrasena" class="mt-6 inline-flex h-12 w-full items-center justify-center rounded-lg bg-brand-600 px-5 text-base font-semibold text-white transition-colors duration-150 ease-out hover:bg-brand-700">
          Pedir otro enlace
        </RouterLink>
      </template>

      <template v-else-if="done">
        <div class="flex size-11 items-center justify-center rounded-full bg-ok-50 text-ok-700">
          <PhCheck :size="22" />
        </div>
        <h1 class="mt-4 text-xl font-bold tracking-[-0.015em] text-gray-900">Contraseña actualizada</h1>
        <p class="mt-2 text-sm text-gray-700">
          Ya puedes usarla para entrar. Tu sesión quedó abierta en este dispositivo.
        </p>
        <RouterLink :to="homeFor(auth.user?.role)" class="mt-6 inline-flex h-12 w-full items-center justify-center rounded-lg bg-brand-600 px-5 text-base font-semibold text-white transition-colors duration-150 ease-out hover:bg-brand-700">
          {{ auth.user?.role === "cliente" ? "Ver mis entradas" : "Ir a mi panel" }}
        </RouterLink>
      </template>

      <template v-else>
        <h1 class="text-xl font-bold tracking-[-0.015em] text-gray-900">Crea tu nueva contraseña</h1>
        <p v-if="auth.user?.email" class="mt-1 text-sm text-gray-600">
          Para <span class="font-semibold text-gray-900">{{ auth.user.email }}</span>
        </p>

        <form class="mt-6 space-y-4" @submit.prevent="save">
          <div>
            <label for="new-password" class="field-label">Contraseña nueva</label>
            <input
              id="new-password"
              v-model="password"
              type="password"
              required
              minlength="6"
              autocomplete="new-password"
              placeholder="Mínimo 6 caracteres"
              class="field-control"
            />
          </div>
          <div>
            <label for="confirm-password" class="field-label">Repítela</label>
            <input
              id="confirm-password"
              v-model="confirm"
              type="password"
              required
              autocomplete="new-password"
              class="field-control"
              :aria-invalid="mismatch || undefined"
            />
            <p v-if="mismatch" class="field-hint text-bad-700">No coinciden.</p>
          </div>

          <p v-if="error" role="alert" class="rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">
            {{ error }}
          </p>

          <BaseButton type="submit" size="lg" block :loading="loading" :disabled="mismatch">
            {{ loading ? "Guardando..." : "Guardar contraseña" }}
          </BaseButton>
        </form>
      </template>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref } from "vue";
import { PhCheck, PhLinkBreak } from "@phosphor-icons/vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import { homeFor } from "@/router";
import BrandLogo from "@/components/ui/BrandLogo.vue";
import BaseButton from "@/components/ui/BaseButton.vue";

const auth = useAuthStore();

const password = ref("");
const confirm = ref("");
const loading = ref(false);
const error = ref("");
const done = ref(false);
// supabase-js ya procesó el enlace (detectSessionInUrl) antes de que la
// guardia del router dejara pasar: aquí solo se consulta si hay sesión.
const hasSession = ref(true);

const mismatch = computed(() => confirm.value.length > 0 && confirm.value !== password.value);

onMounted(async () => {
  const { data } = await supabase.auth.getSession();
  hasSession.value = !!data.session;
});

const save = async () => {
  if (mismatch.value) return;
  error.value = "";
  loading.value = true;
  try {
    await auth.updatePassword(password.value);
    done.value = true;
  } catch (e) {
    const msg = String(e?.message ?? "");
    if (/different from the old/i.test(msg)) {
      error.value = "Debe ser distinta a la contraseña anterior.";
    } else if (/at least|characters|weak/i.test(msg)) {
      error.value = "Es muy corta o fácil de adivinar. Usa al menos 6 caracteres, mejor con números.";
    } else if (/session|jwt|expired/i.test(msg)) {
      hasSession.value = false;
    } else {
      error.value = "No pudimos guardar la contraseña. Inténtalo otra vez.";
    }
  } finally {
    loading.value = false;
  }
};
</script>
