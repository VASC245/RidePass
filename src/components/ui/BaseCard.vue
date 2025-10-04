<template>
  <div
    :class="[
      'bg-white rounded-2xl p-6 border transition-all duration-200 shadow-sm hover:shadow-lg',
      variant === 'default' && 'border-gray-200',
      variant === 'highlight' && 'border-blue-300 bg-blue-50',
      variant === 'danger' && 'border-red-300 bg-red-50'
    ]"
  >
    <!-- Header opcional -->
    <div v-if="$slots.title || $slots.actions" class="flex items-center justify-between mb-4">
      <div v-if="$slots.title" class="text-lg font-semibold text-gray-800">
        <slot name="title" />
      </div>
      <div v-if="$slots.actions">
        <slot name="actions" />
      </div>
    </div>

    <!-- Contenido principal -->
    <slot />
  </div>
</template>

<script setup>
const props = defineProps({
  variant: {
    type: String,
    default: "default" // 'default' | 'highlight' | 'danger'
  }
});
</script>
