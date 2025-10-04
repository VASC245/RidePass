// src/router/index.js
import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "@/stores/authStore";

// Layout
import SidebarLayout from "@/components/ui/SidebarLayout.vue";

// Páginas de auth
import Login from "@/components/auth/Login.vue";
import Register from "@/components/auth/Register.vue";

// Páginas de dueño
import Dashboard from "@/components/owner/Dashboard.vue";
import ChivasList from "@/components/owner/ChivasList.vue";
import DriverForm from "@/components/owner/DriverForm.vue";
import TourForm from "@/components/owner/TourForm.vue";
import AssignChivaToTour from "@/components/owner/AssignChivaToTour.vue";
import ScanBoarding from "@/components/owner/ScanBoarding.vue";
import SellPageOwner from "@/components/ventas/SellPageOwner.vue";
import ToursList  from "@/components/ToursList.vue";

// Páginas de agencia
import SellPage from "@/components/ventas/SellPage.vue";
import AvailableTours from "@/components/ventas/AvailableTours.vue";

// Página de conductor
import ConductorTours from "@/components/conductorTours.vue";

const routes = [
  {
    path: "/login",
    name: "Login",
    component: Login,
  },
  {
    path: "/register",
    name: "Register",
    component: Register,
  },
  {
    path: "/",
    component: SidebarLayout,
    children: [
      // 👑 Dueño
      { path: "/dashboard", name: "Dashboard", component: Dashboard },
      { path: "/chivas", name: "Chivas", component: ChivasList },
      { path: "/conductores", name: "Conductores", component: DriverForm },
      { path: "/nuevo-tour", name: "TourForm", component: TourForm },
      { path: "/asignar", name: "AsignarChivaToTour", component: AssignChivaToTour },
      { path: "/embarque", name: "Embarque", component: ScanBoarding },
      { path: "/mis-ventas", name: "MisVentas", component: SellPageOwner },
      {path: "/tours", name:"Tours", component: ToursList},

      // 🏢 Agencia
      { path: "/vender-boletos", name: "SellPage", component: SellPage },
      { path: "/tours-disponibles", name: "AvailableTours", component: AvailableTours },

      // 🚌 Conductor
      { path: "/mis-tours", name: "ConductorTours", component: ConductorTours },
      { path: "/escanear", name: "ConductorScan", component: ScanBoarding }, // 🔹 nuevo
    ],
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

// 🔒 Navigation Guard
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore();

  if (!authStore.user) {
    await authStore.init();
  }

  const publicPages = ["/login", "/register"];
  if (!authStore.user && !publicPages.includes(to.path)) {
    return next("/login");
  }

  next();
});

export default router;
