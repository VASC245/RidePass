<template>
  <RouterView />
</template>

<script setup>
import { watch } from "vue";
import { useAuthStore } from "@/stores/authStore";
import { useRouter, useRoute } from "vue-router";
import { homeFor } from "@/router";

const authStore = useAuthStore();
const router    = useRouter();
const route     = useRoute();

// Si el usuario ya tiene sesión y cae en una página de login/registro,
// se le manda a su inicio.
const AUTH_ROUTES = ["/panel/login", "/panel/register", "/cuenta/login", "/cuenta/registro"];

watch(
  () => [authStore.ready, authStore.user?.role, route.path],
  ([ready, role, path]) => {
    if (ready && role && AUTH_ROUTES.includes(path)) router.replace(homeFor(role));
  },
  { immediate: true },
);
</script>
