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
    const role = authStore.user.role;
    if (role === "dueño") {
      router.push("/dashboard");
    } else if (role === "agencia") {
      router.push("/agencia/tours-disponibles");
    }
  } else {
    router.push("/login");
  }
});
</script>
