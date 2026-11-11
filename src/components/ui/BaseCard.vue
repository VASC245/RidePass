<template>
  <section
    :class="[
      'rounded-[var(--radius-card)] border',
      padded && 'p-5 sm:p-6',
      variant === 'default' && 'bg-white border-gray-200',
      variant === 'highlight' && 'bg-brand-50 border-brand-200',
      variant === 'danger' && 'bg-bad-50 border-bad-200',
      variant === 'muted' && 'bg-gray-50 border-gray-200',
    ]"
  >
    <header v-if="$slots.title || $slots.actions" class="mb-4 flex items-center justify-between gap-3">
      <h2 v-if="$slots.title" class="text-base font-semibold text-gray-900">
        <slot name="title" />
      </h2>
      <div v-if="$slots.actions" class="flex items-center gap-2">
        <slot name="actions" />
      </div>
    </header>

    <slot />
  </section>
</template>

<script setup>
defineProps({
  // 'default' | 'highlight' | 'danger' | 'muted'
  variant: { type: String, default: 'default' },
  padded:  { type: Boolean, default: true },
})
</script>
