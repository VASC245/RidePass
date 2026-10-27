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

// Sesión expirada o cerrada en otra pestaña: salir de las pantallas que
// requieren cuenta en vez de quedarse con listas vacías.
watch(
  () => authStore.user,
  (user, prev) => {
    if (user || !prev || !authStore.ready) return;
    const needsAuth = route.matched.some((r) => r.meta.requiresAuth || r.meta.roles);
    if (needsAuth) router.replace(route.path.startsWith("/cuenta") ? "/cuenta/login" : "/panel/login");
  },
);
</script>
