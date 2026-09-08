import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "@/stores/authStore";

// Layouts: se cargan de inmediato porque envuelven todo lo demás.
import PublicLayout   from "@/components/public/PublicLayout.vue";
import SidebarLayout  from "@/components/ui/SidebarLayout.vue";
import CustomerLayout from "@/components/customer/CustomerLayout.vue";

// El resto se carga bajo demanda: cada ruta es su propio chunk.
const lazy = (loader) => loader;

// Qué roles pueden entrar a cada sección del panel.
const OWNER    = ["dueño"];
const AGENCY   = ["agencia"];
const DRIVER   = ["conductor"];
const BUSINESS = ["negocio"];
const ANY_PANEL = ["dueño", "agencia", "conductor", "negocio"];

const routes = [
  // ═══════════════════════════════════════
  // PÚBLICO — sin login
  // ═══════════════════════════════════════
  {
    path: "/",
    component: PublicLayout,
    meta: { public: true },
    children: [
      { path: "",              name: "Landing",      component: lazy(() => import("@/components/public/LandingPage.vue")) },
      { path: "tours",         name: "PublicTours",  component: lazy(() => import("@/components/public/ToursPage.vue")) },
      { path: "atracciones",   name: "Atracciones",  component: lazy(() => import("@/components/public/AttractionsPage.vue")) },
      { path: "como-funciona", name: "ComoFunciona", component: lazy(() => import("@/components/public/HowItWorksPage.vue")) },
      { path: "contacto",      name: "Contacto",     component: lazy(() => import("@/components/public/ContactPage.vue")) },
      { path: "ticket/:id",    name: "PublicTicket", component: lazy(() => import("@/components/public/PublicTicket.vue")) },
    ],
  },

  // ═══════════════════════════════════════
  // AUTH PANEL
  // ═══════════════════════════════════════
  { path: "/panel/login",    name: "Login",    component: lazy(() => import("@/components/auth/Login.vue")),    meta: { public: true } },
  { path: "/panel/register", name: "Register", component: lazy(() => import("@/components/auth/Register.vue")), meta: { public: true } },

  // ═══════════════════════════════════════
  // PORTAL CLIENTE
  // ═══════════════════════════════════════
  {
    path: "/cuenta",
    component: CustomerLayout,
    children: [
      { path: "",            redirect: "/cuenta/mis-tickets" },
      { path: "login",       name: "CustomerLogin",    component: lazy(() => import("@/components/customer/CustomerLogin.vue")),    meta: { public: true } },
      { path: "registro",    name: "CustomerRegister", component: lazy(() => import("@/components/customer/CustomerRegister.vue")), meta: { public: true } },
      { path: "mis-tickets", name: "MyTickets",        component: lazy(() => import("@/components/customer/MyTickets.vue")),        meta: { requiresAuth: true, roles: ["cliente"] } },
    ],
  },

  // ═══════════════════════════════════════
  // PANEL DE GESTIÓN — requiere login
  // ═══════════════════════════════════════
  {
    path: "/panel",
    component: SidebarLayout,
    meta: { requiresAuth: true },
    children: [
      { path: "", redirect: "/panel/dashboard" },
      // Dueño
      { path: "dashboard",   name: "Dashboard",          component: lazy(() => import("@/components/owner/Dashboard.vue")),         meta: { roles: OWNER } },
      { path: "chivas",      name: "Chivas",             component: lazy(() => import("@/components/owner/ChivasList.vue")),        meta: { roles: OWNER } },
      { path: "conductores", name: "Conductores",        component: lazy(() => import("@/components/owner/DriverForm.vue")),        meta: { roles: OWNER } },
      { path: "tours",       name: "Tours",              component: lazy(() => import("@/components/ToursList.vue")),               meta: { roles: OWNER } },
      { path: "nuevo-tour",  name: "TourForm",           component: lazy(() => import("@/components/owner/TourForm.vue")),          meta: { roles: OWNER } },
      { path: "asignar",     name: "AsignarChivaToTour", component: lazy(() => import("@/components/owner/AssignChivaToTour.vue")), meta: { roles: OWNER } },
      { path: "pagos",       name: "OwnerPayments",      component: lazy(() => import("@/components/owner/OwnerPayments.vue")),     meta: { roles: OWNER } },
      { path: "embarque",    name: "Embarque",           component: lazy(() => import("@/components/owner/ScanBoarding.vue")),      meta: { roles: OWNER } },
      { path: "mis-ventas",  name: "MisVentas",          component: lazy(() => import("@/components/ventas/SellPageOwner.vue")),    meta: { roles: OWNER } },
      // Agencia
      { path: "vender-boletos",    name: "SellPage",       component: lazy(() => import("@/components/ventas/SellPage.vue")),       meta: { roles: AGENCY } },
      { path: "tours-disponibles", name: "AvailableTours", component: lazy(() => import("@/components/ventas/AvailableTours.vue")), meta: { roles: AGENCY } },
      // Conductor
      { path: "mis-tours", name: "ConductorTours", component: lazy(() => import("@/components/conductorTours.vue")),    meta: { roles: DRIVER } },
      { path: "escanear",  name: "ConductorScan",  component: lazy(() => import("@/components/owner/ScanBoarding.vue")), meta: { roles: DRIVER } },
      // Negocio
      { path: "negocio-dashboard", name: "NegocioDashboard", component: lazy(() => import("@/components/business/BusinessDashboard.vue")), meta: { roles: BUSINESS } },
      { path: "negocio-perfil",    name: "NegocioPerfil",    component: lazy(() => import("@/components/business/BusinessProfile.vue")),   meta: { roles: BUSINESS } },
      { path: "negocio-eventos",   name: "NegocioEventos",   component: lazy(() => import("@/components/business/BusinessEvents.vue")),    meta: { roles: BUSINESS } },
      { path: "negocio-tickets",   name: "NegocioTickets",   component: lazy(() => import("@/components/business/BusinessTickets.vue")),   meta: { roles: BUSINESS } },
      { path: "negocio-escanear",  name: "NegocioScan",      component: lazy(() => import("@/components/business/BusinessScan.vue")),      meta: { roles: BUSINESS } },
      // Configuración y planes — todos los roles del panel
      { path: "configuracion", name: "Configuracion", component: lazy(() => import("@/components/shared/SettingsPanel.vue")), meta: { roles: ANY_PANEL } },
      { path: "planes",        name: "Planes",        component: lazy(() => import("@/components/shared/PlansPage.vue")),     meta: { roles: ANY_PANEL } },
    ],
  },

  { path: "/:pathMatch(.*)*", redirect: "/" },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition;
    if (to.hash) return { el: to.hash, behavior: "smooth" };
    return { top: 0 };
  },
});

// Página de inicio de cada rol.
export const homeFor = (role) => ({
  "dueño":     "/panel/dashboard",
  "agencia":   "/panel/tours-disponibles",
  "conductor": "/panel/mis-tours",
  "negocio":   "/panel/negocio-dashboard",
  "cliente":   "/cuenta/mis-tickets",
}[role] ?? "/");

// ═══════════════════════════════════════
// GUARDIA
// ═══════════════════════════════════════
router.beforeEach(async (to) => {
  const authStore = useAuthStore();
  if (!authStore.ready) await authStore.init();

  // requiresAuth se evalúa ANTES que public: un hijo protegido dentro de un
  // layout público sigue protegido.
  const requiresAuth = to.matched.some((r) => r.meta.requiresAuth);
  const isPublic     = !requiresAuth && to.matched.some((r) => r.meta.public);

  if (isPublic) return true;

  if (requiresAuth && !authStore.user) {
    return to.path.startsWith("/cuenta") ? "/cuenta/login" : "/panel/login";
  }

  // Restricción por rol: la ruta más específica manda.
  const allowed = [...to.matched].reverse().find((r) => r.meta.roles)?.meta.roles;
  if (allowed && authStore.user && !allowed.includes(authStore.user.role)) {
    return homeFor(authStore.user.role);
  }

  return true;
});

export default router;
