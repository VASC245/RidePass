<template>
  <div class="bg-white">

    <!-- ══════════════════════════════════════════
         HERO con buscador
    ══════════════════════════════════════════ -->
    <section class="relative overflow-hidden bg-gray-950">
      <!-- Foto placeholder; reemplazar con foto real de Baños -->
      <img
        src="/img/hero-cascada.jpg"
        alt="Cascada en Baños de Agua Santa"
        class="absolute inset-0 w-full h-full object-cover opacity-60"
      />
      <div class="absolute inset-0 bg-gradient-to-r from-gray-950/90 via-gray-950/60 to-gray-950/20"></div>

      <div class="relative max-w-7xl mx-auto px-4 sm:px-6 py-20 md:py-28 lg:py-32">
        <div class="max-w-xl">
          <h1 class="text-4xl md:text-5xl lg:text-6xl font-extrabold text-white tracking-tight leading-[1.05]">
            Vive Baños.<br />Reserva en minutos.
          </h1>
          <p class="mt-4 text-base md:text-lg text-gray-200 max-w-md">
            Tours en chiva, cascadas, termas y deportes extremos con entrada QR al instante.
          </p>

          <form @submit.prevent="goSearch"
            class="mt-7 flex items-center bg-white rounded-full h-14 pl-5 pr-2 gap-3 shadow-xl shadow-black/20 max-w-lg focus-within:ring-2 focus-within:ring-orange-500">
            <PhMagnifyingGlass :size="20" class="text-gray-400 shrink-0" />
            <input v-model="searchQuery" type="search"
              placeholder="¿Qué quieres hacer en Baños?"
              class="flex-1 min-w-0 outline-none text-[15px] text-gray-900 placeholder:text-gray-400 bg-transparent" />
            <button type="submit"
              class="h-10 px-5 rounded-full bg-orange-600 hover:bg-orange-700 text-white text-sm font-bold transition-colors shrink-0">
              Buscar
            </button>
          </form>
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         CATEGORÍAS
    ══════════════════════════════════════════ -->
    <section class="max-w-7xl mx-auto px-4 sm:px-6 pt-10 pb-2">
      <div class="flex gap-3 sm:gap-6 overflow-x-auto pb-3 no-scrollbar sm:justify-center">
        <RouterLink v-for="c in categories" :key="c.label" :to="c.to"
          class="group flex flex-col items-center gap-2 shrink-0 w-24 no-underline">
          <span class="w-16 h-16 rounded-full bg-gray-50 border border-gray-200 flex items-center justify-center text-gray-600 group-hover:border-orange-500 group-hover:text-orange-600 group-hover:bg-orange-50 transition-colors">
            <component :is="c.icon" :size="26" />
          </span>
          <span class="text-xs font-semibold text-gray-700 text-center leading-tight">{{ c.label }}</span>
        </RouterLink>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         PRÓXIMAS SALIDAS
    ══════════════════════════════════════════ -->
    <section class="max-w-7xl mx-auto px-4 sm:px-6 py-12">
      <div class="flex items-end justify-between gap-4 mb-6">
        <h2 class="text-2xl md:text-[28px] font-extrabold text-gray-900 tracking-tight">Próximas salidas en chiva</h2>
        <RouterLink to="/tours" class="see-all">Ver todo</RouterLink>
      </div>

      <div v-if="toursStore.loading" class="grid sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div v-for="i in 4" :key="i" class="rounded-2xl border border-gray-200 overflow-hidden">
          <div class="aspect-[16/9] bg-gray-100 animate-pulse"></div>
          <div class="p-4 space-y-2">
            <div class="h-4 bg-gray-100 rounded animate-pulse w-3/4"></div>
            <div class="h-3 bg-gray-100 rounded animate-pulse w-1/2"></div>
            <div class="h-3 bg-gray-100 rounded animate-pulse w-1/3"></div>
          </div>
        </div>
      </div>

      <div v-else-if="upcomingTours.length === 0" class="rounded-2xl border border-dashed border-gray-300 py-16 text-center">
        <p class="font-bold text-gray-700">No hay salidas programadas por ahora</p>
        <p class="text-sm text-gray-500 mt-1">Vuelve pronto, los dueños publican tours cada semana.</p>
      </div>

      <div v-else class="grid sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <TourCard v-for="tour in upcomingTours" :key="tour.id" :tour="tour" @open="openTour" />
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         ATRACCIONES
    ══════════════════════════════════════════ -->
    <section class="bg-gray-50 border-y border-gray-100">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 py-12">
        <div class="flex items-end justify-between gap-4 mb-6">
          <h2 class="text-2xl md:text-[28px] font-extrabold text-gray-900 tracking-tight">Atracciones en Baños</h2>
          <RouterLink to="/atracciones" class="see-all">Ver todo</RouterLink>
        </div>

        <div v-if="bizLoading" class="grid sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <div v-for="i in 4" :key="i" class="rounded-2xl border border-gray-200 bg-white overflow-hidden">
            <div class="aspect-[16/9] bg-gray-100 animate-pulse"></div>
            <div class="p-4 space-y-2">
              <div class="h-4 bg-gray-100 rounded animate-pulse w-3/4"></div>
              <div class="h-3 bg-gray-100 rounded animate-pulse w-1/2"></div>
            </div>
          </div>
        </div>

        <div v-else-if="featuredBusinesses.length === 0" class="rounded-2xl border border-dashed border-gray-300 py-16 text-center bg-white">
          <p class="font-bold text-gray-700">Aún no hay atracciones afiliadas</p>
          <p class="text-sm text-gray-500 mt-1">Estamos sumando negocios de Baños a la plataforma.</p>
        </div>

        <div v-else class="grid sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <AttractionCard v-for="biz in featuredBusinesses" :key="biz.id" :biz="biz" @open="openBiz" />
        </div>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         CÓMO FUNCIONA (resumen)
    ══════════════════════════════════════════ -->
    <section class="max-w-7xl mx-auto px-4 sm:px-6 py-16">
      <div class="grid lg:grid-cols-[1fr_1.4fr] gap-10 lg:gap-16 items-start">
        <div>
          <h2 class="text-2xl md:text-[28px] font-extrabold text-gray-900 tracking-tight">Comprar toma menos de dos minutos</h2>
          <p class="mt-3 text-gray-600 leading-relaxed">
            Sin filas ni intermediarios: eliges, pagas y tu entrada llega con código QR a tu correo y WhatsApp.
          </p>
          <RouterLink to="/como-funciona"
            class="mt-5 inline-flex items-center gap-1.5 text-sm font-bold text-orange-700 hover:text-orange-800 transition-colors">
            Ver la guía completa
            <PhArrowRight :size="15" weight="bold" />
          </RouterLink>
        </div>

        <ol class="space-y-6">
          <li v-for="(s, i) in steps" :key="s.title" class="flex gap-4">
            <span class="w-9 h-9 rounded-full bg-gray-900 text-white text-sm font-bold flex items-center justify-center shrink-0 mt-0.5">
              {{ i + 1 }}
            </span>
            <div>
              <h3 class="font-bold text-gray-900">{{ s.title }}</h3>
              <p class="text-sm text-gray-600 mt-0.5 leading-relaxed">{{ s.desc }}</p>
            </div>
          </li>
        </ol>
      </div>
    </section>

    <!-- ══════════════════════════════════════════
         BANDA PARA VENDEDORES
    ══════════════════════════════════════════ -->
    <section class="bg-gray-950">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 py-14 md:py-16 flex flex-col md:flex-row md:items-center gap-6 md:gap-10">
        <div class="flex-1">
          <h2 class="text-2xl md:text-3xl font-extrabold text-white tracking-tight">
            ¿Tienes una chiva o un negocio turístico en Baños?
          </h2>
          <p class="mt-2 text-gray-400 max-w-xl">
            Publica tus tours o eventos, recibe reservas con comprobante y controla el embarque con escáner QR.
          </p>
        </div>
        <RouterLink to="/como-funciona#vender"
          class="inline-flex items-center justify-center gap-2 bg-orange-600 hover:bg-orange-700 text-white font-bold px-6 py-3.5 rounded-[10px] transition-colors shrink-0">
          Vende tus entradas aquí
          <PhArrowRight :size="16" weight="bold" />
        </RouterLink>
      </div>
    </section>

    <!-- Modales de reserva -->
    <BookingHost ref="booking" @tours-changed="toursStore.fetchTours()" @biz-changed="fetchBusinesses" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import {
  PhMagnifyingGlass, PhArrowRight, PhVan, PhWaves, PhPersonSimpleHike, PhThermometerHot, PhForkKnife,
} from '@phosphor-icons/vue'
import { useToursStore } from '@/stores/toursStore'
import { useBusinesses } from '@/composables/useBusinesses'
import TourCard from '@/components/public/cards/TourCard.vue'
import AttractionCard from '@/components/public/cards/AttractionCard.vue'
import BookingHost from '@/components/public/booking/BookingHost.vue'

const router     = useRouter()
const toursStore = useToursStore()
const { catalog, loading: bizLoading, fetchBusinesses } = useBusinesses()

const booking     = ref(null)
const searchQuery = ref('')

const categories = [
  { label: 'Tours en chiva',    icon: PhVan,              to: '/tours' },
  { label: 'Cascadas',          icon: PhWaves,            to: '/atracciones?cat=cascada' },
  { label: 'Deportes extremos', icon: PhPersonSimpleHike, to: '/atracciones?cat=deporte' },
  { label: 'Termas',            icon: PhThermometerHot,   to: '/atracciones?cat=termas' },
  { label: 'Gastronomía',       icon: PhForkKnife,        to: '/atracciones?cat=restaurante' },
]

const steps = [
  { title: 'Elige tu plan',            desc: 'Explora las salidas en chiva y las atracciones afiliadas, con precios y horarios reales.' },
  { title: 'Reserva tu lugar',         desc: 'En los tours escoges tu asiento en el mapa de la chiva; en las atracciones, la cantidad de entradas.' },
  { title: 'Paga y recibe tu QR',      desc: 'Sube tu comprobante de transferencia y tu entrada con código QR llega al instante.' },
]

const upcomingTours = computed(() =>
  toursStore.tours
    .filter(t => new Date(t.departure_at) > new Date() && ['pendiente', 'en_curso'].includes(t.status))
    .sort((a, b) => new Date(a.departure_at) - new Date(b.departure_at))
    .slice(0, 8)
)

const featuredBusinesses = computed(() => catalog.value.slice(0, 8))

const openTour = (tour) => booking.value?.openTour(tour)
const openBiz  = (biz)  => booking.value?.openBiz(biz)

const goSearch = () => {
  router.push({ path: '/tours', query: searchQuery.value.trim() ? { q: searchQuery.value.trim() } : {} })
}

onMounted(() => {
  toursStore.fetchTours()
  fetchBusinesses()
})
</script>

<style scoped>
.see-all {
  font-size: 0.875rem;
  font-weight: 700;
  color: #c2410c;
  text-decoration: none;
  white-space: nowrap;
  padding-bottom: 2px;
  transition: color .15s;
}
.see-all:hover { color: #9a3412; }

.no-scrollbar { scrollbar-width: none; -webkit-overflow-scrolling: touch; }
.no-scrollbar::-webkit-scrollbar { display: none; }
</style>
