<template>
  <div class="max-w-4xl mx-auto p-6 bg-white rounded-2xl shadow space-y-6">
    <h2 class="text-2xl font-bold">Lista de Tours</h2>

    <div v-if="tours.length === 0" class="text-gray-500">
      No hay tours registrados aún.
    </div>

    <ul class="grid gap-4 md:grid-cols-2">
      <li
        v-for="tour in tours"
        :key="tour.id"
        class="border border-gray-200 rounded-xl p-4 shadow-sm"
      >
        <h3 class="text-lg font-semibold mb-1">
          {{ tour.title }}
        </h3>
        <p class="text-sm text-gray-600 mb-1">
          {{ tour.description }}
        </p>
        <p class="text-sm font-medium text-green-600">
          Precio: ${{ tour.base_price.toFixed(2) }}
        </p>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'

const tours = ref([])

const cargarTours = async () => {
  const { data, error } = await supabase
    .from('tours')
    .select('id, title, description, base_price')
    .order('created_at', { ascending: false })

  if (error) {
    console.error('Error al cargar tours:', error)
  } else {
    tours.value = data
  }
}

onMounted(() => {
  cargarTours()
})
</script>
