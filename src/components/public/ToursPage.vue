<template>
  <div class="bg-white min-h-[70vh]">

    <!-- Cabecera -->
    <header class="border-b border-gray-100 bg-gray-50">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 pt-10 pb-8">
        <h1 class="text-3xl md:text-4xl font-extrabold text-gray-900 tracking-tight">Tours en chiva</h1>
        <p class="mt-2 text-gray-600">
          Salidas reales publicadas por los dueños de las chivas de Baños. Elige tu asiento y paga en línea.
        </p>

        <form @submit.prevent
          class="mt-6 flex items-center bg-white border border-gray-200 rounded-full h-12 pl-4 pr-4 gap-3 max-w-xl focus-within:ring-2 focus-within:ring-orange-500/60 transition-shadow">
          <PhMagnifyingGlass :size="18" class="text-gray-400 shrink-0" />
          <input v-model="query" type="search" placeholder="Buscar por nombre del tour o chiva"
            class="flex-1 min-w-0 outline-none text-sm text-gray-900 placeholder:text-gray-400 bg-transparent" />
          <button v-if="query" type="button" @click="query = ''"
            class="text-gray-400 hover:text-gray-600" aria-label="Limpiar búsqueda">
            <PhX :size="15" weight="bold" />
          </button>
        </form>
      </div>
    </header>

    <div class="max-w-5xl mx-auto px-4 sm:px-6 py-8">

      <!-- Filtros de fecha -->
      <div class="flex items-center gap-2 overflow-x-auto no-scrollbar pb-1 mb-6">
        <button v-for="f in filters" :key="f.value" @click="activeFilter = f.value"
          :class="activeFilter === f.value
            ? 'bg-gray-900 text-white'
            : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
          class="text-sm font-semibold px-4 py-2 rounded-full whitespace-nowrap transition-colors">
          {{ f.label }}
        </button>
        <span class="ml-auto hidden sm:block text-sm text-gray-500 whitespace-nowrap">
          {{ filteredTours.length }} {{ filteredTours.length === 1 ? 'salida' : 'salidas' }}
        </span>
      </div>

      <!-- Cargando -->
      <div v-if="toursStore.loading" class="space-y-4">
        <div v-for="i in 3" :key="i" class="flex gap-5 rounded-2xl border border-gray-200 p-4">
          <div class="w-40 sm:w-56 aspect-[16/10] rounded-xl bg-gray-100 animate-pulse shrink-0"></div>
          <div class="flex-1 py-1 space-y-2.5">
            <div class="h-4 bg-gray-100 rounded animate-pulse w-2/3"></div>
            <div class="h-3 bg-gray-100 rounded animate-pulse w-1/3"></div>
            <div class="h-3 bg-gray-100 rounded animate-pulse w-1/4"></div>
          </div>
        </div>
      </div>

      <!-- Vacío -->
      <div v-else-if="filteredTours.length === 0" class="rounded-2xl border border-dashed border-gray-300 py-20 text-center">
        <p class="font-bold text-gray-700">
          {{ query ? `Sin resultados para "${query}"` : 'No hay salidas en este rango de fechas' }}
        </p>
        <p class="text-sm text-gray-500 mt-1">Prueba con otro filtro o revisa todas las salidas.</p>
        <button @click="activeFilter = 'all'; query = ''"
          class="mt-4 text-sm font-bold text-orange-700 hover:text-orange-800 transition-colors">
          Ver todas las salidas
        </button>
      </div>

      <!-- Lista -->
      <div v-else class="space-y-4">
        <article v-for="tour in filteredTours" :key="tour.id"
          class="group flex flex-col sm:flex-row gap-4 sm:gap-5 rounded-2xl border border-gray-200 p-4 cursor-pointer hover:shadow-lg hover:shadow-gray-900/8 transition-all duration-200"
          @click="openTour(tour)">

          <div class="w-full sm:w-56 aspect-[16/10] rounded-xl overflow-hidden bg-gray-100 shrink-0">
            <img
              :src="tour.image_url || placeholderFor(tour.id)"
              :alt="tour.title" loading="lazy"
              class="w-full h-full object-cover group-hover:scale-[1.03] transition-transform duration-300" />
          </div>

          <div class="flex-1 min-w-0 flex flex-col">
            <p class="text-sm font-semibold text-orange-700">{{ dateLabel(tour.departure_at) }}</p>
            <h2 class="mt-1 text-lg font-bold text-gray-900 leading-snug">{{ tour.title }}</h2>

            <div class="mt-1.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-gray-600">
              <span class="inline-flex items-center gap-1.5">
                <PhVan :size="15" class="text-gray-400" />
                {{ tour.chiva_name || 'Chiva por confirmar' }}
              </span>
              <span v-if="tour.duration" class="inline-flex items-center gap-1.5">
                <PhClock :size="15" class="text-gray-400" />
                {{ tour.duration }} min
              </span>
            </div>

            <div class="mt-auto pt-3 flex items-center justify-between gap-4">
              <p class="text-[15px] text-gray-900">
                Desde <span class="font-extrabold">${{ Number(tour.base_price).toFixed(2) }}</span>
                <span class="text-gray-500 text-sm">por asiento</span>
              </p>
              <span
                class="inline-flex items-center gap-1.5 text-sm font-bold text-white bg-gray-900 group-hover:bg-orange-600 px-4 py-2 rounded-[10px] transition-colors">
                Elegir asientos
                <PhArrowRight :size="14" weight="bold" />
              </span>
            </div>
          </div>
        </article>
      </div>
    </div>

    <BookingHost ref="booking" @tours-changed="toursStore.fetchTours()" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { PhMagnifyingGlass, PhX, PhVan, PhClock, PhArrowRight } from '@phosphor-icons/vue'
import { useToursStore } from '@/stores/toursStore'
import { placeholderFor } from '@/lib/placeholderImage'
import BookingHost from '@/components/public/booking/BookingHost.vue'

const route      = useRoute()
const toursStore = useToursStore()
const booking    = ref(null)

const query        = ref(typeof route.query.q === 'string' ? route.query.q : '')
const activeFilter = ref('all')

watch(() => route.query.q, (q) => { query.value = typeof q === 'string' ? q : '' })

const filters = [
  { label: 'Todas las fechas', value: 'all'   },
  { label: 'Hoy',              value: 'today' },
  { label: 'Esta semana',      value: 'week'  },
  { label: 'Este mes',         value: 'month' },
]

const availableTours = computed(() =>
  toursStore.tours
    .filter(t => new Date(t.departure_at) > new Date() && ['pendiente', 'en_curso'].includes(t.status))
    .sort((a, b) => new Date(a.departure_at) - new Date(b.departure_at))
)

const filteredTours = computed(() => {
  const now   = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const week  = new Date(today); week.setDate(week.getDate() + 7)
  const month = new Date(today); month.setMonth(month.getMonth() + 1)
  const q     = query.value.trim().toLowerCase()

  return availableTours.value.filter(t => {
    const d = new Date(t.departure_at)
    if (activeFilter.value === 'today' && !(d >= today && d < new Date(today.getTime() + 86400000))) return false
    if (activeFilter.value === 'week'  && !(d >= today && d < week))  return false
    if (activeFilter.value === 'month' && !(d >= today && d < month)) return false
    if (q && !`${t.title} ${t.chiva_name ?? ''}`.toLowerCase().includes(q)) return false
    return true
  })
})

const dateLabel = (dep) => {
  const d = new Date(dep)
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const diff = Math.floor((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000)
  const hora = d.toLocaleTimeString('es-EC', { hour: '2-digit', minute: '2-digit' })
  if (diff === 0) return `Hoy, ${hora}`
  if (diff === 1) return `Mañana, ${hora}`
  return `${d.toLocaleDateString('es-EC', { weekday: 'long', day: 'numeric', month: 'long' })}, ${hora}`
}

const openTour = (tour) => booking.value?.openTour(tour)

onMounted(() => toursStore.fetchTours())
</script>

<style scoped>
.no-scrollbar { scrollbar-width: none; -webkit-overflow-scrolling: touch; }
.no-scrollbar::-webkit-scrollbar { display: none; }
</style>
