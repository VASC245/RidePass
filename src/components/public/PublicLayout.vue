<template>
  <div class="min-h-screen flex flex-col bg-white">

    <!-- ── Navbar ── -->
    <nav class="bg-white border-b border-gray-200 sticky top-0 z-40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-3">

        <RouterLink to="/" class="flex items-center shrink-0 no-underline" aria-label="Inicio">
          <BrandLogo :size="26" />
        </RouterLink>

        <!-- buscador (desktop) -->
        <form @submit.prevent="goSearch"
          class="hidden md:flex items-center flex-1 max-w-md ml-4 bg-gray-100 rounded-full h-10 px-4 gap-2 focus-within:ring-2 focus-within:ring-orange-500/60 transition-shadow">
          <PhMagnifyingGlass :size="16" class="text-gray-500 shrink-0" />
          <input v-model="q" type="search" placeholder="Buscar tours y atracciones"
            class="bg-transparent outline-none text-sm w-full placeholder:text-gray-500" />
        </form>

        <div class="flex-1 md:hidden"></div>

        <!-- links (desktop) -->
        <div class="hidden lg:flex items-center gap-0.5 ml-auto">
          <RouterLink to="/tours" class="nav-link" active-class="nav-link-active">Tours</RouterLink>
          <RouterLink to="/atracciones" class="nav-link" active-class="nav-link-active">Atracciones</RouterLink>
          <RouterLink to="/como-funciona" class="nav-link" active-class="nav-link-active">Cómo funciona</RouterLink>
          <RouterLink to="/contacto" class="nav-link" active-class="nav-link-active">Contacto</RouterLink>
        </div>

        <div class="hidden md:block w-px h-6 bg-gray-200 mx-1"></div>

        <RouterLink to="/cuenta/mis-tickets"
          class="hidden md:inline-flex items-center gap-1.5 text-sm font-semibold text-gray-700 hover:text-orange-700 px-2.5 py-2 rounded-lg transition-colors">
          <PhTicket :size="17" />
          Mis entradas
        </RouterLink>

        <RouterLink to="/panel/login"
          class="hidden md:inline-flex text-sm font-bold text-white bg-gray-900 hover:bg-gray-800 px-4 py-2 rounded-lg transition-colors">
          Ingresar
        </RouterLink>

        <!-- hamburguesa -->
        <button @click="menuOpen = !menuOpen"
          class="lg:hidden w-10 h-10 flex items-center justify-center rounded-lg text-gray-700 hover:bg-gray-100 transition-colors"
          aria-label="Abrir menú">
          <PhX v-if="menuOpen" :size="22" />
          <PhList v-else :size="22" />
        </button>
      </div>

      <!-- menú móvil -->
      <Transition name="drop">
        <div v-if="menuOpen" class="lg:hidden border-t border-gray-100 bg-white px-4 pb-5 pt-3">
          <form @submit.prevent="goSearch"
            class="flex items-center bg-gray-100 rounded-full h-11 px-4 gap-2 mb-3">
            <PhMagnifyingGlass :size="16" class="text-gray-500 shrink-0" />
            <input v-model="q" type="search" placeholder="Buscar tours y atracciones"
              class="bg-transparent outline-none text-sm w-full placeholder:text-gray-500" />
          </form>
          <div class="flex flex-col">
            <RouterLink v-for="l in mobileLinks" :key="l.to" :to="l.to" @click="menuOpen = false"
              class="py-3 text-[15px] font-semibold text-gray-800 border-b border-gray-100">
              {{ l.label }}
            </RouterLink>
            <RouterLink to="/panel/login" @click="menuOpen = false"
              class="mt-4 text-center text-sm font-bold text-white bg-gray-900 py-3 rounded-lg">
              Ingresar
            </RouterLink>
          </div>
        </div>
      </Transition>
    </nav>

    <main class="flex-1">
      <RouterView />
    </main>

    <!-- ── Footer ── -->
    <footer class="bg-gray-950 text-gray-400 pt-14 pb-8 px-4 sm:px-6">
      <div class="max-w-7xl mx-auto grid sm:grid-cols-2 lg:grid-cols-4 gap-10 mb-12">
        <div>
          <div class="mb-4">
            <BrandLogo :size="24" variant="white" />
          </div>
          <p class="text-sm leading-relaxed text-gray-500 max-w-xs">
            Entradas para tours en chiva y atracciones de Baños de Agua Santa. Compra en línea y recibe tu código QR al instante.
          </p>
        </div>
        <div>
          <h4 class="text-white font-bold mb-4 text-sm">Explora</h4>
          <ul class="space-y-2.5 text-sm">
            <li><RouterLink to="/tours" class="footer-link">Tours en chiva</RouterLink></li>
            <li><RouterLink to="/atracciones" class="footer-link">Atracciones</RouterLink></li>
            <li><RouterLink to="/como-funciona" class="footer-link">Cómo funciona</RouterLink></li>
            <li><RouterLink to="/cuenta/mis-tickets" class="footer-link">Mis entradas</RouterLink></li>
          </ul>
        </div>
        <div>
          <h4 class="text-white font-bold mb-4 text-sm">Vende con ChivaPass</h4>
          <ul class="space-y-2.5 text-sm">
            <li><RouterLink to="/panel/login" class="footer-link">Registra tu chiva</RouterLink></li>
            <li><RouterLink to="/panel/login" class="footer-link">Afilia tu negocio</RouterLink></li>
            <li><RouterLink to="/contacto" class="footer-link">Habla con nosotros</RouterLink></li>
          </ul>
        </div>
        <div>
          <h4 class="text-white font-bold mb-4 text-sm">Contacto</h4>
          <ul class="space-y-2.5 text-sm text-gray-500">
            <li class="flex items-start gap-2">
              <PhMapPin :size="16" class="mt-0.5 shrink-0" />
              Baños de Agua Santa, Tungurahua, Ecuador
            </li>
            <li>
              <RouterLink to="/contacto" class="footer-link">Formulario de contacto</RouterLink>
            </li>
          </ul>
        </div>
      </div>
      <div class="max-w-7xl mx-auto border-t border-gray-800 pt-6 flex flex-col sm:flex-row items-center justify-between gap-2 text-xs text-gray-600">
        <p>© 2026 ChivaPass. Baños de Agua Santa, Ecuador.</p>
        <p>Turismo local, venta directa.</p>
      </div>
    </footer>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { PhMagnifyingGlass, PhTicket, PhList, PhX, PhMapPin } from '@phosphor-icons/vue'
import BrandLogo from '@/components/ui/BrandLogo.vue'

const router   = useRouter()
const q        = ref('')
const menuOpen = ref(false)

const mobileLinks = [
  { to: '/tours',          label: 'Tours en chiva' },
  { to: '/atracciones',    label: 'Atracciones' },
  { to: '/como-funciona',  label: 'Cómo funciona' },
  { to: '/contacto',       label: 'Contacto' },
  { to: '/cuenta/mis-tickets', label: 'Mis entradas' },
]

const goSearch = () => {
  menuOpen.value = false
  router.push({ path: '/tours', query: q.value.trim() ? { q: q.value.trim() } : {} })
}
</script>

<style scoped>
.nav-link {
  font-size: 0.875rem;
  font-weight: 600;
  color: #3d4149;
  text-decoration: none;
  padding: 8px 12px;
  border-radius: 8px;
  transition: color .15s, background .15s;
}
.nav-link:hover { color: #111; background: #f4f4f5; }
.nav-link-active { color: #c2410c; }

.footer-link { color: #8a8f99; text-decoration: none; transition: color .15s; }
.footer-link:hover { color: #fff; }

.drop-enter-active, .drop-leave-active { transition: opacity .18s ease, transform .18s ease; }
.drop-enter-from, .drop-leave-to { opacity: 0; transform: translateY(-8px); }
</style>
