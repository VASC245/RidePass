<template>
  <RouterView />
</template>

<script setup>
import { onMounted } from "vue";
import { useAuthStore } from "@/stores/authStore";
import { useRouter } from "vue-router";

const authStore = useAuthStore();
const router = useRouter();

onMounted(async () => {
  await authStore.init();

  if (authStore.user) {
    if (authStore.user.role === "dueño") {
      router.push("/dashboard"); // ✅ corregido
    } else if (authStore.user.role === "agencia") {
      router.push("/tours-disponibles"); // ✅ corregido
    }
  } else {
    router.push("/login");
  }
});
</script>
