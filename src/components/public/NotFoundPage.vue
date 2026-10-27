<template>
  <div class="mx-auto max-w-xl px-4 py-20">
    <EmptyState
      title="No encontramos esta página"
      description="Puede que el enlace esté mal escrito o que la página ya no exista."
    >
      <div class="flex flex-wrap justify-center gap-3">
        <RouterLink to="/tours" class="rounded-xl bg-brand-600 px-5 py-2.5 text-sm font-semibold text-white hover:bg-brand-700">
          Ver tours
        </RouterLink>
        <RouterLink to="/" class="rounded-xl border border-gray-300 px-5 py-2.5 text-sm font-semibold text-gray-700 hover:border-gray-400">
          Ir al inicio
        </RouterLink>
      </div>
    </EmptyState>
  </div>
</template>

<script setup>
import EmptyState from '@/components/ui/EmptyState.vue'
</script>
