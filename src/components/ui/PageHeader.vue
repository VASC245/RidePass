<template>
  <header class="mb-6 flex flex-col gap-4 sm:mb-8 sm:flex-row sm:items-end sm:justify-between">
    <div class="min-w-0">
      <h1 class="text-2xl font-bold tracking-[-0.015em] text-gray-900 text-balance sm:text-[1.75rem]">{{ title }}</h1>
      <p v-if="description || $slots.description" class="mt-1.5 max-w-[65ch] text-[0.95rem] leading-relaxed text-gray-600 text-pretty">
        <slot name="description">{{ description }}</slot>
      </p>
    </div>
    <div v-if="$slots.actions" class="flex shrink-0 flex-wrap items-center gap-2">
      <slot name="actions" />
    </div>
  </header>
</template>

<script setup>
defineProps({
  title:       { type: String, required: true },
  description: { type: String, default: '' },
})
</script>
