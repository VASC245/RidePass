<template>
  <button
    :class="[
      'inline-flex items-center justify-center rounded-xl px-4 py-2 border shadow-sm transition focus:outline-none',
      variant === 'primary' && 'bg-blue-600 text-white border-transparent hover:bg-blue-700',
      variant === 'outline' && 'bg-white text-gray-800 border-gray-300 hover:bg-gray-50',
      block && 'w-full',
      disabled && 'opacity-50 pointer-events-none'
    ]"
    :disabled="disabled"
    v-bind="$attrs"
  >
    <slot />
  </button>
</template>

<script setup>
const props = defineProps({
  variant: { type: String, default: 'primary' }, // 'primary' | 'outline'
  block: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false }
})
</script>
