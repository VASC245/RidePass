<template>
  <div
    class="flex flex-wrap items-center justify-center gap-6 bg-gray-50 border border-gray-200 rounded-2xl p-4 shadow-sm text-sm font-medium text-gray-700"
  >
    <div class="flex items-center gap-2">
      <span class="w-5 h-5 rounded-md bg-green-400 border border-green-500 shadow-sm"></span>
      <span>Disponible</span>
    </div>

    <div class="flex items-center gap-2">
      <span class="w-5 h-5 rounded-md bg-yellow-400 border border-yellow-500 shadow-sm"></span>
      <span>Seleccionado</span>
    </div>

    <div class="flex items-center gap-2">
      <span class="w-5 h-5 rounded-md bg-red-500 border border-red-600 shadow-sm"></span>
      <span>Pagado / Reservado</span>
    </div>

    <div class="flex items-center gap-2">
      <span class="w-5 h-5 rounded-md bg-blue-500 border border-blue-600 shadow-sm"></span>
      <span>Abordado</span>
    </div>
  </div>
</template>
