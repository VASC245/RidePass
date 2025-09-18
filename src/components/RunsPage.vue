<template>
  <div class="max-w-6xl mx-auto py-6 px-4">
    <h2 class="text-2xl font-bold mb-6 text-center">Asignar Chiva a Tour</h2>

    <form @submit.prevent="asignarChiva" class="bg-white p-6 rounded-2xl shadow-md space-y-4">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block font-semibold mb-1">Tour</label>
          <select v-model="tour_id" class="w-full px-4 py-2 border border-gray-300 rounded-lg">
            <option v-for="tour in tours" :key="tour.id" :value="tour.id">{{ tour.name }}</option>
          </select>
        </div>

        <div>
          <label class="block font-semibold mb-1">Chiva</label>
          <select v-model="chiva_id" class="w-full px-4 py-2 border border-gray-300 rounded-lg">
            <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">{{ chiva.name }}</option>
          </select>
        </div>
      </div>

      <button type="submit" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700">
        Asignar
      </button>
    </form>

    <div v-if="runs.length > 0" class="mt-10">
      <h3 class="text-lg font-semibold mb-3">Chivas Asignadas</h3>
      <table class="w-full text-left border border-gray-200 rounded-xl overflow-hidden">
        <thead class="bg-gray-100 text-sm uppercase">
          <tr>
            <th class="px-4 py-2">Tour</th>
            <th class="px-4 py-2">Chiva</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="run in runs" :key="run.id" class="hover:bg-gray-50">
            <td class="px-4 py-2">{{ run.tours?.name }}</td>
            <td class="px-4 py-2">{{ run.chivas?.name }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'

const tours = ref([])
const chivas = ref([])
const runs = ref([])

const tour_id = ref(null)
const chiva_id = ref(null)

const fetchTours = async () => {
  const { data } = await supabase.from('tours').select('*')
  tours.value = data || []
}

const fetchChivas = async () => {
  const { data } = await supabase.from('chivas').select('*')
  chivas.value = data || []
}

const fetchRuns = async () => {
  const { data } = await supabase
    .from('tour_runs')
    .select('id, tour_id, chiva_id, tours(name), chivas(name)')
  runs.value = data || []
}

const asignarChiva = async () => {
  if (!tour_id.value || !chiva_id.value) return

  await supabase.from('tour_runs').insert([
    { tour_id: tour_id.value, chiva_id: chiva_id.value }
  ])

  tour_id.value = null
  chiva_id.value = null
  fetchRuns()
}

onMounted(() => {
  fetchTours()
  fetchChivas()
  fetchRuns()
})
</script>
