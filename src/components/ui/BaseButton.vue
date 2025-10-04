<template>
  <button
    :class="[
      'inline-flex items-center justify-center rounded-xl px-5 py-2.5 font-semibold shadow-sm transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2',
      variant === 'primary' && 'bg-blue-600 text-white border border-transparent hover:bg-blue-700 active:scale-95 focus:ring-blue-500',
      variant === 'outline' && 'bg-white text-gray-800 border border-gray-300 hover:bg-gray-50 active:scale-95 focus:ring-gray-400',
      variant === 'danger' && 'bg-red-600 text-white border border-transparent hover:bg-red-700 active:scale-95 focus:ring-red-500',
      variant === 'success' && 'bg-green-600 text-white border border-transparent hover:bg-green-700 active:scale-95 focus:ring-green-500',
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
  variant: {
    type: String,
    default: 'primary' // 'primary' | 'outline' | 'danger' | 'success'
  },
  block: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false }
})
</script>
