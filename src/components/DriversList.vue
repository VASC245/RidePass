<template>
  <div class="p-8 max-w-5xl mx-auto space-y-8">
    <!-- Título -->
    <h2 class="text-3xl font-extrabold text-center text-gray-800">
      👨‍✈️ Lista de Conductores
    </h2>

    <!-- Sin conductores -->
    <div v-if="drivers.length === 0" class="text-gray-500 text-center italic">
      🚫 No hay conductores registrados.
    </div>

    <!-- Lista de conductores -->
    <ul v-else class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
      <li
        v-for="driver in drivers"
        :key="driver.id"
        class="p-6 bg-white rounded-2xl shadow-sm border border-gray-200 hover:shadow-md hover:border-blue-300 transition-all"
      >
        <h3 class="text-xl font-bold text-gray-800 mb-2">
          {{ driver.name }}
        </h3>
        <p class="text-sm text-gray-600">🆔 Cédula: <span class="font-medium">{{ driver.cedula }}</span></p>
        <p class="text-sm text-gray-600">📞 Teléfono: <span class="font-medium">{{ driver.phone }}</span></p>
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
