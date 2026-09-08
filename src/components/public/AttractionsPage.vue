<template>
  <div class="bg-white min-h-[70vh]">

    <!-- Cabecera -->
    <header class="border-b border-gray-100 bg-gray-50">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 pt-10 pb-8">
        <h1 class="text-3xl md:text-4xl font-extrabold text-gray-900 tracking-tight">Atracciones en Baños</h1>
        <p class="mt-2 text-gray-600 max-w-2xl">
          Cascadas, termas, deportes extremos y restaurantes afiliados. Compra tu entrada aquí y preséntala con tu código QR.
        </p>
      </div>
    </header>

    <div class="max-w-6xl mx-auto px-4 sm:px-6 py-8">

      <!-- Filtros de categoría -->
      <div class="flex items-center gap-2 overflow-x-auto no-scrollbar pb-1 mb-6">
        <button v-for="cat in categories" :key="cat.value" @click="activeCat = cat.value"
          :class="activeCat === cat.value
            ? 'bg-gray-900 text-white'
            : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
          class="text-sm font-semibold px-4 py-2 rounded-full whitespace-nowrap transition-colors">
          {{ cat.label }}
        </button>
        <span class="ml-auto hidden sm:block text-sm text-gray-500 whitespace-nowrap">
          {{ filteredBusinesses.length }} {{ filteredBusinesses.length === 1 ? 'lugar' : 'lugares' }}
        </span>
      </div>

      <!-- Cargando -->
      <div v-if="loading" class="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <div v-for="i in 6" :key="i" class="rounded-2xl border border-gray-200 overflow-hidden">
          <div class="aspect-[16/9] bg-gray-100 animate-pulse"></div>
          <div class="p-4 space-y-2">
            <div class="h-3 bg-gray-100 rounded animate-pulse w-1/4"></div>
            <div class="h-4 bg-gray-100 rounded animate-pulse w-2/3"></div>
            <div class="h-3 bg-gray-100 rounded animate-pulse w-1/2"></div>
          </div>
        </div>
      </div>

      <!-- Vacío -->
      <div v-else-if="filteredBusinesses.length === 0" class="rounded-2xl border border-dashed border-gray-300 py-20 text-center">
        <p class="font-bold text-gray-700">No hay atracciones en esta categoría</p>
        <p class="text-sm text-gray-500 mt-1">Estamos sumando más negocios de Baños cada semana.</p>
        <button @click="activeCat = 'all'"
          class="mt-4 text-sm font-bold text-orange-700 hover:text-orange-800 transition-colors">
          Ver todas las atracciones
        </button>
      </div>

      <!-- Grilla -->
      <div v-else class="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <AttractionCard v-for="biz in filteredBusinesses" :key="biz.id" :biz="biz" @open="openBiz" />
      </div>
    </div>

    <BookingHost ref="booking" @biz-changed="fetchBusinesses" />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import { useBusinesses } from '@/composables/useBusinesses'
import AttractionCard from '@/components/public/cards/AttractionCard.vue'
import BookingHost from '@/components/public/booking/BookingHost.vue'

const route = useRoute()
const { catalog, loading, fetchBusinesses } = useBusinesses()

const booking = ref(null)

const categories = [
  { label: 'Todas',            value: 'all'         },
  { label: 'Cascadas',         value: 'cascada'     },
  { label: 'Deportes extremos', value: 'deporte'    },
  { label: 'Termas',           value: 'termas'      },
  { label: 'Restaurantes',     value: 'restaurante' },
  { label: 'Otros',            value: 'otro'        },
]

const validCat  = (v) => categories.some(c => c.value === v)
const activeCat = ref(validCat(route.query.cat) ? route.query.cat : 'all')

watch(() => route.query.cat, (v) => { activeCat.value = validCat(v) ? v : 'all' })

const filteredBusinesses = computed(() =>
  activeCat.value === 'all'
    ? catalog.value
    : catalog.value.filter(b => b.category === activeCat.value)
)

const openBiz = (biz) => booking.value?.openBiz(biz)

onMounted(fetchBusinesses)
</script>

<style scoped>
.no-scrollbar { scrollbar-width: none; -webkit-overflow-scrolling: touch; }
.no-scrollbar::-webkit-scrollbar { display: none; }
</style>
