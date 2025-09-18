<template>
  <div class="p-6 max-w-4xl mx-auto">
    <h2 class="text-2xl font-bold mb-4">Lista de Conductores</h2>

    <div v-if="drivers.length === 0" class="text-gray-500">
      No hay conductores registrados.
    </div>

    <ul v-else class="space-y-4">
      <li
        v-for="driver in drivers"
        :key="driver.id"
        class="p-4 bg-white rounded-lg shadow border hover:bg-gray-50 transition"
      >
        <h3 class="text-lg font-semibold">Nombre: {{ driver.name }}</h3>
        <p class="text-sm text-gray-600">Cédula: {{ driver.cedula }}</p>
        <p class="text-sm text-gray-600">Teléfono: {{ driver.phone }}</p>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue';
import { supabase } from '@/lib/supabase';

const drivers = ref([]);

const fetchDrivers = async () => {
  const { data, error } = await supabase.from('drivers').select('*');
  if (error) {
    console.error('Error al obtener conductores:', error);
  } else {
    drivers.value = data;
  }
};

onMounted(fetchDrivers);
</script>
