<template>
  <button
    :type="type"
    :class="[
      'inline-flex items-center justify-center gap-2 rounded-lg font-semibold whitespace-nowrap select-none',
      'transition-[background-color,border-color,color,transform] duration-150 ease-out active:scale-[0.98]',
      'disabled:cursor-not-allowed disabled:opacity-50 disabled:active:scale-100',
      sizes[size],
      variants[variant] ?? variants.primary,
      (block || full) && 'w-full',
    ]"
    :disabled="disabled || loading"
    :aria-busy="loading || undefined"
    v-bind="$attrs"
  >
    <span v-if="loading" class="size-4 animate-spin rounded-full border-2 border-current border-r-transparent" aria-hidden="true" />
    <slot />
  </button>
</template>

<script setup>
defineOptions({ inheritAttrs: false })

defineProps({
  // 'primary' | 'secondary' | 'outline' | 'ghost' | 'dark' | 'danger' | 'success'
  variant:  { type: String, default: 'primary' },
  size:     { type: String, default: 'md' }, // 'sm' | 'md' | 'lg'
  type:     { type: String, default: 'button' },
  block:    { type: Boolean, default: false },
  full:     { type: Boolean, default: false }, // alias de block (lo usa el checkout)
  disabled: { type: Boolean, default: false },
  loading:  { type: Boolean, default: false },
})

const sizes = {
  sm: 'h-9 px-3 text-sm',
  md: 'h-10 px-4 text-sm',
  lg: 'h-12 px-5 text-base',
}

const variants = {
  primary:   'bg-brand-600 text-white hover:bg-brand-700',
  dark:      'bg-gray-900 text-white hover:bg-gray-800',
  secondary: 'bg-white text-gray-800 border border-gray-300 hover:bg-gray-50 hover:border-gray-400',
  outline:   'bg-white text-gray-800 border border-gray-300 hover:bg-gray-50 hover:border-gray-400',
  ghost:     'text-gray-700 hover:bg-gray-100',
  danger:    'bg-bad-700 text-white hover:bg-bad-600',
  success:   'bg-ok-700 text-white hover:bg-ok-600',
}
</script>
