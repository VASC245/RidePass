<template>
  <div class="bg-white rounded-2xl shadow p-6 flex items-center gap-4 border border-gray-100">
    <div class="text-3xl">
      {{ icon }}
    </div>
    <div>
      <p class="text-gray-500 text-sm font-medium">{{ title }}</p>
      <p class="text-2xl font-bold text-gray-900">{{ value }}</p>
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: String,
  value: [String, Number],
  icon: String,
});
</script>
