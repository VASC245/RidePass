<template>
  <div class="min-h-dvh bg-gray-50 md:flex">
    <!-- Barra lateral de escritorio -->
    <aside class="hidden md:flex md:flex-col md:w-64 md:shrink-0 md:sticky md:top-0 md:h-dvh bg-side text-side-text">
      <div class="px-5 pt-6 pb-7">
        <RouterLink :to="homePath" class="inline-flex rounded-md">
          <BrandLogo :size="26" variant="onDark" />
        </RouterLink>
      </div>

      <nav class="flex-1 overflow-y-auto px-3 pb-4" aria-label="Menú del panel">
        <div v-for="group in menuGroups" :key="group.title || 'main'" class="mb-5 last:mb-0">
          <p v-if="group.title" class="px-3 mb-1.5 text-xs font-medium text-side-mute">{{ group.title }}</p>
          <ul class="space-y-0.5">
            <li v-for="item in group.items" :key="item.path">
              <RouterLink :to="item.path" class="nav-item" active-class="nav-item--active">
                <component :is="item.icon" :size="19" class="nav-icon shrink-0" />
                <span class="truncate">{{ item.label }}</span>
                <span class="nav-dot" aria-hidden="true" />
              </RouterLink>
            </li>
          </ul>
        </div>
      </nav>

      <div class="border-t border-white/10 p-3">
        <div class="flex items-center gap-3 px-2 py-2">
          <span class="avatar">{{ initials }}</span>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-semibold text-white">{{ user?.full_name || 'Mi cuenta' }}</p>
            <p class="text-xs text-side-mute">{{ roleLabel }}</p>
          </div>
          <button type="button" class="side-icon-btn" title="Cerrar sesión" aria-label="Cerrar sesión" @click="logout">
            <PhSignOut :size="19" />
          </button>
        </div>
      </div>
    </aside>

    <!-- Barra superior móvil -->
    <header class="md:hidden sticky top-0 z-30 flex h-14 items-center justify-between bg-side px-4 text-side-text">
      <RouterLink :to="homePath" class="inline-flex rounded-md">
        <BrandLogo :size="22" variant="onDark" />
      </RouterLink>
      <button type="button" class="side-icon-btn -mr-2" aria-label="Abrir menú" :aria-expanded="mobileOpen" @click="mobileOpen = true">
        <PhList :size="24" />
      </button>
    </header>

    <!-- Menú móvil -->
    <Transition name="drawer">
      <div v-if="mobileOpen" class="fixed inset-0 z-50 md:hidden" role="dialog" aria-modal="true" aria-label="Menú del panel">
        <div class="drawer-backdrop absolute inset-0 bg-black/45" @click="mobileOpen = false" />
        <div class="drawer-panel relative flex h-full w-[min(18rem,85vw)] flex-col bg-side text-side-text">
          <div class="flex h-14 items-center justify-between px-4">
            <BrandLogo :size="22" variant="onDark" />
            <button type="button" class="side-icon-btn -mr-2" aria-label="Cerrar menú" @click="mobileOpen = false">
              <PhX :size="22" />
            </button>
          </div>

          <nav class="flex-1 overflow-y-auto px-3 py-3" aria-label="Menú del panel">
            <div v-for="group in menuGroups" :key="group.title || 'main'" class="mb-5 last:mb-0">
              <p v-if="group.title" class="px-3 mb-1.5 text-xs font-medium text-side-mute">{{ group.title }}</p>
              <ul class="space-y-0.5">
                <li v-for="item in group.items" :key="item.path">
                  <RouterLink :to="item.path" class="nav-item nav-item--touch" active-class="nav-item--active" @click="mobileOpen = false">
                    <component :is="item.icon" :size="20" class="nav-icon shrink-0" />
                    <span class="truncate">{{ item.label }}</span>
                    <span class="nav-dot" aria-hidden="true" />
                  </RouterLink>
                </li>
              </ul>
            </div>
          </nav>

          <div class="border-t border-white/10 p-3">
            <div class="flex items-center gap-3 px-2 py-2">
              <span class="avatar">{{ initials }}</span>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-semibold text-white">{{ user?.full_name || 'Mi cuenta' }}</p>
                <p class="text-xs text-side-mute">{{ roleLabel }}</p>
              </div>
            </div>
            <button type="button" class="mt-1 flex h-11 w-full items-center justify-center gap-2 rounded-lg bg-side-hover text-sm font-semibold text-white transition-colors hover:bg-side-active" @click="logout">
              <PhSignOut :size="18" /> Cerrar sesión
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Contenido -->
    <main class="min-w-0 flex-1">
      <div class="mx-auto w-full max-w-6xl px-4 py-6 sm:px-6 lg:px-10 lg:py-9">
        <RouterView />
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, watch, onBeforeUnmount } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "@/stores/authStore";
import BrandLogo from "@/components/ui/BrandLogo.vue";
import {
  PhList, PhX, PhSignOut, PhSquaresFour, PhMapTrifold, PhPlusCircle, PhCalendarBlank,
  PhBus, PhSteeringWheel, PhChartLineUp, PhReceipt, PhQrCode, PhGearSix, PhStack,
  PhTicket, PhStorefront, PhCalendarCheck,
} from "@phosphor-icons/vue";

const router = useRouter();
const authStore = useAuthStore();
// computed: se actualiza al iniciar/cerrar sesión sin recargar la página
const user = computed(() => authStore.user);
const mobileOpen = ref(false);

const ROLE_LABELS = { "dueño": "Dueño de chiva", agencia: "Agencia", conductor: "Conductor", negocio: "Negocio" };
const roleLabel = computed(() => ROLE_LABELS[user.value?.role] ?? "Panel");

const initials = computed(() => {
  const parts = (user.value?.full_name || "").trim().split(/\s+/).filter(Boolean);
  return ((parts[0]?.[0] ?? "") + (parts[1]?.[0] ?? "")).toUpperCase() || "CP";
});

const ACCOUNT = {
  title: "Cuenta",
  items: [
    { label: "Configuración", path: "/panel/configuracion", icon: PhGearSix },
    { label: "Planes",        path: "/panel/planes",        icon: PhStack },
  ],
};

const menuGroups = computed(() => {
  switch (user.value?.role) {
    case "dueño":
      return [
        { title: "", items: [
          { label: "Resumen", path: "/panel/dashboard", icon: PhSquaresFour },
        ] },
        { title: "Operación", items: [
          { label: "Tours",            path: "/panel/tours",       icon: PhMapTrifold },
          { label: "Crear o editar tour", path: "/panel/nuevo-tour", icon: PhPlusCircle },
          { label: "Salidas",          path: "/panel/asignar",     icon: PhCalendarBlank },
          { label: "Chivas",           path: "/panel/chivas",      icon: PhBus },
          { label: "Conductores",      path: "/panel/conductores", icon: PhSteeringWheel },
        ] },
        { title: "Ventas", items: [
          { label: "Ventas",       path: "/panel/mis-ventas", icon: PhChartLineUp },
          { label: "Comprobantes", path: "/panel/pagos",      icon: PhReceipt },
          { label: "Embarque",     path: "/panel/embarque",   icon: PhQrCode },
        ] },
        ACCOUNT,
      ];
    case "agencia":
      return [
        { title: "", items: [
          { label: "Vender boletos",    path: "/panel/vender-boletos",    icon: PhTicket },
          { label: "Tours disponibles", path: "/panel/tours-disponibles", icon: PhMapTrifold },
        ] },
        ACCOUNT,
      ];
    case "conductor":
      return [
        { title: "", items: [
          { label: "Mis salidas", path: "/panel/mis-tours", icon: PhCalendarCheck },
          { label: "Escanear QR", path: "/panel/escanear",  icon: PhQrCode },
        ] },
      ];
    case "negocio":
      return [
        { title: "", items: [
          { label: "Resumen", path: "/panel/negocio-dashboard", icon: PhSquaresFour },
        ] },
        { title: "Mi negocio", items: [
          { label: "Perfil",      path: "/panel/negocio-perfil",   icon: PhStorefront },
          { label: "Eventos",     path: "/panel/negocio-eventos",  icon: PhCalendarBlank },
          { label: "Tickets",     path: "/panel/negocio-tickets",  icon: PhTicket },
          { label: "Escanear QR", path: "/panel/negocio-escanear", icon: PhQrCode },
        ] },
        ACCOUNT,
      ];
    default:
      return [];
  }
});

const homePath = computed(() => menuGroups.value[0]?.items[0]?.path ?? "/panel");

// Escape cierra el menú móvil y bloquea el scroll del fondo mientras está abierto
const onKey = (e) => { if (e.key === "Escape") mobileOpen.value = false; };
watch(mobileOpen, (open) => {
  document.body.style.overflow = open ? "hidden" : "";
  if (open) window.addEventListener("keydown", onKey);
  else window.removeEventListener("keydown", onKey);
});
onBeforeUnmount(() => {
  document.body.style.overflow = "";
  window.removeEventListener("keydown", onKey);
});

const logout = async () => {
  await authStore.logout();
  router.push("/panel/login");
};
</script>

<style scoped>
.nav-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  height: 2.5rem;
  padding: 0 0.75rem;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 500;
  color: var(--color-side-text);
  transition: background-color 150ms var(--ease-out-quart), color 150ms var(--ease-out-quart);
}
.nav-item--touch { height: 2.75rem; }
.nav-item:hover { background: var(--color-side-hover); color: #fff; }
.nav-icon { color: var(--color-side-mute); transition: color 150ms var(--ease-out-quart); }
.nav-item:hover .nav-icon { color: var(--color-side-text); }

/* Activo: el punto naranja es el remate de la curva del logo */
.nav-dot {
  margin-left: auto;
  width: 6px; height: 6px;
  border-radius: 999px;
  background: var(--color-brand-400);
  opacity: 0;
  transform: scale(0.4);
  transition: opacity 200ms var(--ease-out-quart), transform 200ms var(--ease-out-quart);
}
.nav-item--active { background: var(--color-side-active); color: #fff; font-weight: 600; }
.nav-item--active .nav-icon { color: var(--color-brand-400); }
.nav-item--active .nav-dot { opacity: 1; transform: scale(1); }

.avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem; height: 2.25rem;
  flex-shrink: 0;
  border-radius: 999px;
  background: var(--color-brand-600);
  color: #fff;
  font-size: 0.8rem;
  font-weight: 700;
}

.side-icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.5rem; height: 2.5rem;
  border-radius: 8px;
  color: var(--color-side-mute);
  transition: background-color 150ms var(--ease-out-quart), color 150ms var(--ease-out-quart);
}
.side-icon-btn:hover { background: var(--color-side-hover); color: #fff; }

.drawer-enter-active, .drawer-leave-active { transition: opacity 220ms var(--ease-out-quart); }
.drawer-enter-active .drawer-panel, .drawer-leave-active .drawer-panel { transition: transform 260ms var(--ease-out-quart); }
.drawer-enter-from, .drawer-leave-to { opacity: 0; }
.drawer-enter-from .drawer-panel, .drawer-leave-to .drawer-panel { transform: translateX(-100%); }
</style>
