<template>
  <div class="bg-white">

    <header class="border-b border-gray-100 bg-gray-50">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 pt-12 pb-10">
        <h1 class="text-3xl md:text-4xl font-extrabold text-gray-900 tracking-tight">Créditos de fotografías</h1>
        <p class="mt-3 max-w-prose text-gray-600 leading-relaxed">
          Varias fotos de las atracciones de Baños vienen de Wikimedia Commons y se usan bajo licencias Creative Commons. Aquí está el crédito a sus autores.
        </p>
        <p class="mt-4 text-sm text-gray-600">Actualizado el {{ LEGAL.updated }}</p>
      </div>
    </header>

    <div class="max-w-3xl mx-auto px-4 sm:px-6 py-12">

      <ul class="divide-y divide-gray-200 border-y border-gray-200">
        <li v-for="p in photos" :key="p.id" class="flex gap-4 py-5">
          <img :src="p.image" :alt="p.name" loading="lazy"
            class="h-20 w-28 shrink-0 rounded-lg bg-gray-100 object-cover" />
          <div class="min-w-0 text-[0.95rem]">
            <p class="font-semibold text-gray-900">{{ p.name }}</p>
            <div class="mt-1 space-y-0.5 text-sm text-gray-700">
              <p v-if="p.credit.author">
                <span class="text-gray-600">Autor:</span> {{ p.credit.author }}
              </p>
              <p v-if="p.credit.license">
                <span class="text-gray-600">Licencia:</span>
                <a v-if="p.credit.licenseUrl" :href="p.credit.licenseUrl" target="_blank" rel="noopener" class="credit-link">{{ p.credit.license }}</a>
                <template v-else>{{ p.credit.license }}</template>
              </p>
              <p v-if="p.credit.source">
                <a :href="p.credit.source" target="_blank" rel="noopener" class="credit-link">Ver la foto original</a>
              </p>
              <p v-if="!p.credit.author && !p.credit.license" class="text-gray-600">
                Foto de Wikimedia Commons. Autor y licencia según la página del archivo.
              </p>
            </div>
          </div>
        </li>
      </ul>

      <div class="mt-10 max-w-prose text-[0.95rem] leading-7 text-gray-700">
        <h2 class="text-xl font-bold tracking-tight text-gray-900">Sobre estas fotos</h2>
        <p class="mt-3">
          Las fotos se usan con las condiciones de su licencia Creative Commons, que permite reutilizarlas dando crédito al autor. En el sitio pueden verse recortadas para encajar en las tarjetas. Las licencias no implican que los autores respalden a chivaspass ni a los negocios que aparecen.
        </p>
        <p class="mt-3">
          Más información sobre el uso de estos archivos en
          <a href="https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia/es" target="_blank" rel="noopener" class="credit-link">Wikimedia Commons</a>.
        </p>
        <p class="mt-3">
          Si eres autor de una de estas fotos y falta tu crédito o prefieres que la quitemos, escríbenos a
          <a :href="`mailto:${LEGAL.email}`" class="credit-link">{{ LEGAL.email }}</a>.
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { banosDirectory } from '@/data/banosDirectory'
import { LEGAL } from '@/lib/legal'

// Fotos de Wikimedia Commons: las fichas del directorio con imagen en
// public/img/atracciones/. Para mostrar autor y licencia, añade a la ficha
// `imageCredit: { author, license, licenseUrl, source }` en banosDirectory.js.
const photos = banosDirectory
  .filter((d) => d.image?.startsWith('/img/atracciones/'))
  .map((d) => ({
    id: d.id,
    name: d.name,
    image: d.image,
    credit: {
      author: d.imageCredit?.author ?? d.imageAuthor ?? '',
      license: d.imageCredit?.license ?? d.imageLicense ?? '',
      licenseUrl: d.imageCredit?.licenseUrl ?? '',
      source: d.imageCredit?.source ?? d.imageSource ?? '',
    },
  }))
</script>

<style scoped>
.credit-link {
  font-weight: 500;
  color: var(--color-brand-700);
  text-decoration: underline;
  text-underline-offset: 2px;
}
.credit-link:hover { color: var(--color-brand-800); }
</style>
