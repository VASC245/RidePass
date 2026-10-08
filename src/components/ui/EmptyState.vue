<template>
  <div class="flex flex-col items-center px-6 py-10 text-center">
    <span class="mb-4 inline-flex size-12 items-center justify-center rounded-full bg-brand-50 text-brand-700">
      <component :is="icon" :size="24" />
    </span>
    <p class="text-base font-semibold text-gray-900">{{ title }}</p>
    <p v-if="description" class="mt-1 max-w-[42ch] text-sm leading-relaxed text-gray-600 text-pretty">{{ description }}</p>
    <div v-if="$slots.default" class="mt-5">
      <slot />
    </div>
  </div>
</template>

<script setup>
import { PhRoadHorizon } from '@phosphor-icons/vue'

defineProps({
  title:       { type: String, required: true },
  description: { type: String, default: '' },
  icon:        { type: [Object, Function], default: () => PhRoadHorizon },
})
</script>
