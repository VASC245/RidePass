<template>
  <div class="flex min-h-screen items-center justify-center bg-gray-50 p-4">
    <div class="w-full max-w-sm rounded-xl border border-gray-200 bg-white p-8">
      <div class="mb-6 flex justify-center"><BrandLogo :size="30" /></div>

      <template v-if="!sent">
        <h1 class="text-xl font-bold tracking-[-0.015em] text-gray-900">Recupera tu contraseña</h1>
        <p class="mt-1 text-sm text-gray-600">
          Escribe el correo con el que te registraste y te mandamos un enlace para crear una nueva.
        </p>

        <form class="mt-6 space-y-4" @submit.prevent="send">
          <div>
            <label for="reset-email" class="field-label">Correo electrónico</label>
            <input
              id="reset-email"
              v-model="email"
              type="email"
              required
              autocomplete="email"
              placeholder="tu@correo.com"
              class="field-control"
            />
          </div>

          <p v-if="error" role="alert" class="rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">
            {{ error }}
          </p>

          <BaseButton type="submit" size="lg" block :loading="loading">
            {{ loading ? "Enviando..." : "Enviar enlace" }}
          </BaseButton>
        </form>
      </template>

      <template v-else>
        <div class="flex size-11 items-center justify-center rounded-full bg-brand-50 text-brand-700">
          <PhEnvelopeSimple :size="22" />
        </div>
        <h1 class="mt-4 text-xl font-bold tracking-[-0.015em] text-gray-900">Revisa tu correo</h1>
        <p class="mt-2 text-sm text-gray-700">
          Si <span class="font-semibold text-gray-900">{{ email }}</span> tiene una cuenta en chivaspass,
          te llegará un enlace en unos minutos. Ábrelo desde este mismo dispositivo.
        </p>
        <p class="mt-3 text-sm text-gray-600">
          ¿No aparece? Revisa Spam y Promociones. El enlace vence en una hora.
        </p>
        <button type="button" class="mt-5 text-sm font-semibold text-brand-700 hover:underline" @click="sent = false">
          Usar otro correo
        </button>
      </template>

      <p class="mt-6 border-t border-gray-200 pt-5 text-center text-sm text-gray-600">
        <RouterLink :to="loginPath" class="font-semibold text-brand-700 hover:underline">Volver a iniciar sesión</RouterLink>
      </p>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { PhEnvelopeSimple } from "@phosphor-icons/vue";
import { useAuthStore } from "@/stores/authStore";
import BrandLogo from "@/components/ui/BrandLogo.vue";
import BaseButton from "@/components/ui/BaseButton.vue";

const route = useRoute();
const auth = useAuthStore();

const email = ref(typeof route.query.correo === "string" ? route.query.correo : "");
const loading = ref(false);
const error = ref("");
const sent = ref(false);

// Desde qué login llegó: el de clientes o el del panel.
const loginPath = computed(() => (route.query.desde === "panel" ? "/panel/login" : "/cuenta/login"));

const send = async () => {
  error.value = "";
  loading.value = true;
  try {
    await auth.requestPasswordReset(email.value);
    sent.value = true;
  } catch (e) {
    const msg = String(e?.message ?? "");
    if (/after \d+ seconds|rate limit|too many/i.test(msg)) {
      error.value = "Ya pediste un enlace hace poco. Espera un minuto e inténtalo de nuevo.";
    } else if (/invalid/i.test(msg)) {
      error.value = "Ese correo no parece válido. Revísalo.";
    } else {
      error.value = "No pudimos enviar el enlace. Revisa tu conexión e inténtalo otra vez.";
    }
  } finally {
    loading.value = false;
  }
};
</script>
