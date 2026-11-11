<template>
  <div class="inline-flex max-w-full overflow-x-auto rounded-lg border border-gray-200 bg-white p-1" role="radiogroup" :aria-label="label">
    <button
      v-for="opt in options" :key="opt.value"
      type="button" role="radio" :aria-checked="modelValue === opt.value"
      class="h-8 shrink-0 whitespace-nowrap rounded-md px-3 text-sm font-semibold transition-colors duration-150"
      :class="modelValue === opt.value ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'"
      @click="$emit('update:modelValue', opt.value)"
    >{{ opt.label }}</button>
  </div>
</template>

<script setup>
defineProps({
  modelValue: { type: [String, Number], required: true },
  options:    { type: Array, required: true }, // [{ label, value }]
  label:      { type: String, default: '' },
})
defineEmits(['update:modelValue'])
</script>
