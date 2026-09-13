<template>
  <div class="bg-white">

    <!-- Cabecera -->
    <header class="border-b border-gray-100 bg-gray-50">
      <div class="max-w-3xl mx-auto px-4 sm:px-6 pt-12 pb-10 text-center">
        <h1 class="text-3xl md:text-4xl font-extrabold text-gray-900 tracking-tight">Cómo funciona chivaspass</h1>
        <p class="mt-3 text-gray-600 leading-relaxed">
          Una sola plataforma para comprar entradas de tours en chiva y atracciones de Baños, y para que los negocios locales las vendan sin intermediarios.
        </p>
      </div>
    </header>

    <!-- ── Para viajeros ── -->
    <section class="max-w-6xl mx-auto px-4 sm:px-6 py-16">
      <div class="grid lg:grid-cols-[1fr_1.5fr] gap-10 lg:gap-20 items-start">
        <div class="lg:sticky lg:top-24">
          <h2 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">Si vienes de visita</h2>
          <p class="mt-3 text-gray-600 leading-relaxed">
            Todo el proceso es en línea y tarda menos de dos minutos. No necesitas imprimir nada.
          </p>
          <RouterLink to="/tours"
            class="mt-6 inline-flex items-center gap-2 bg-orange-600 hover:bg-orange-700 text-white font-bold px-5 py-3 rounded-[10px] transition-colors">
            Explorar tours
            <PhArrowRight :size="15" weight="bold" />
          </RouterLink>
        </div>

        <ol class="relative space-y-10 before:absolute before:left-[17px] before:top-2 before:bottom-2 before:w-px before:bg-gray-200">
          <li v-for="(s, i) in travelerSteps" :key="s.title" class="relative flex gap-5">
            <span class="relative z-10 w-9 h-9 rounded-full bg-gray-900 text-white text-sm font-bold flex items-center justify-center shrink-0">
              {{ i + 1 }}
            </span>
            <div class="pt-1">
              <h3 class="font-bold text-gray-900 text-lg">{{ s.title }}</h3>
              <p class="mt-1 text-gray-600 leading-relaxed text-[15px]">{{ s.desc }}</p>
            </div>
          </li>
        </ol>
      </div>
    </section>

    <!-- ── Tu entrada QR ── -->
    <section class="bg-gray-50 border-y border-gray-100">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 py-16 grid md:grid-cols-2 gap-10 items-center">
        <div class="rounded-2xl overflow-hidden aspect-[4/3] bg-gray-200">
          <!-- Foto placeholder; reemplazar con foto real de un pasajero mostrando su QR -->
          <img src="/img/como-viajera.jpg" alt="Viajera explorando en Baños"
            loading="lazy" class="w-full h-full object-cover" />
        </div>
        <div>
          <h2 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">Tu entrada es un código QR</h2>
          <p class="mt-3 text-gray-600 leading-relaxed">
            Al confirmar tu pago recibes la entrada en tu correo y puedes reenviarla a tu WhatsApp. El día del tour, el conductor la escanea desde su teléfono y listo: no hay boletos de papel ni filas de canje.
          </p>
          <ul class="mt-5 space-y-3 text-[15px] text-gray-700">
            <li class="flex items-start gap-3">
              <PhQrCode :size="20" class="text-orange-600 shrink-0 mt-0.5" />
              Un QR único por reserva, con tus asientos incluidos
            </li>
            <li class="flex items-start gap-3">
              <PhDeviceMobile :size="20" class="text-orange-600 shrink-0 mt-0.5" />
              Disponible siempre en tu correo y en "Mis entradas"
            </li>
            <li class="flex items-start gap-3">
              <PhSealCheck :size="20" class="text-orange-600 shrink-0 mt-0.5" />
              El vendedor verifica tu comprobante antes de la salida
            </li>
          </ul>
        </div>
      </div>
    </section>

    <!-- ── Para dueños de chiva ── -->
    <section id="vender" class="max-w-6xl mx-auto px-4 sm:px-6 py-16 scroll-mt-24">
      <div class="grid md:grid-cols-2 gap-10 items-center">
        <div class="md:order-2 rounded-2xl overflow-hidden aspect-[4/3] bg-gray-200">
          <!-- Foto placeholder; reemplazar con foto real de una chiva de Baños -->
          <img src="/img/como-montanas.jpg" alt="Montañas alrededor de Baños"
            loading="lazy" class="w-full h-full object-cover" />
        </div>
        <div class="md:order-1">
          <h2 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight">Si eres dueño de una chiva</h2>
          <p class="mt-3 text-gray-600 leading-relaxed">
            Publica tus salidas con horario y precio, y deja que los turistas reserven asiento directamente. Tú verificas cada transferencia desde tu panel y controlas el embarque con el escáner QR.
          </p>
          <ul class="mt-5 space-y-3 text-[15px] text-gray-700">
            <li class="flex items-start gap-3">
              <PhCalendarCheck :size="20" class="text-orange-600 shrink-0 mt-0.5" />
              Mapa de asientos en tiempo real para cada salida
            </li>
            <li class="flex items-start gap-3">
              <PhChatCircleText :size="20" class="text-orange-600 shrink-0 mt-0.5" />
              Aviso por WhatsApp con cada reserva nueva
            </li>
            <li class="flex items-start gap-3">
              <PhScan :size="20" class="text-orange-600 shrink-0 mt-0.5" />
              Escáner de embarque desde cualquier teléfono
            </li>
          </ul>
          <RouterLink to="/panel/register"
            class="mt-6 inline-flex items-center gap-2 bg-gray-900 hover:bg-gray-800 text-white font-bold px-5 py-3 rounded-[10px] transition-colors">
            Registrar mi chiva
            <PhArrowRight :size="15" weight="bold" />
          </RouterLink>
        </div>
      </div>
    </section>

    <!-- ── Para negocios ── -->
    <section class="bg-gray-950">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 py-16">
        <div class="max-w-2xl">
          <h2 class="text-2xl md:text-3xl font-extrabold text-white tracking-tight">Si tienes un negocio turístico</h2>
          <p class="mt-3 text-gray-400 leading-relaxed">
            Cascadas, termas, canopy, restaurantes: crea eventos con cupos y precio, y vende entradas a los visitantes que ya están explorando ChivaPass.
          </p>
        </div>

        <div class="mt-10 grid sm:grid-cols-3 gap-8">
          <div class="border-t border-gray-800 pt-5">
            <PhStorefront :size="24" class="text-orange-500" />
            <h3 class="mt-3 font-bold text-white">Tu propio perfil</h3>
            <p class="mt-1 text-sm text-gray-400 leading-relaxed">Con fotos, descripción, ubicación y tus eventos activos.</p>
          </div>
          <div class="border-t border-gray-800 pt-5">
            <PhTicket :size="24" class="text-orange-500" />
            <h3 class="mt-3 font-bold text-white">Entradas con cupo</h3>
            <p class="mt-1 text-sm text-gray-400 leading-relaxed">Defines capacidad y precio por evento; el sistema cierra la venta al llenarse.</p>
          </div>
          <div class="border-t border-gray-800 pt-5">
            <PhScan :size="24" class="text-orange-500" />
            <h3 class="mt-3 font-bold text-white">Control en la puerta</h3>
            <p class="mt-1 text-sm text-gray-400 leading-relaxed">Escaneas el QR del cliente y validas su pago en segundos.</p>
          </div>
        </div>

        <RouterLink to="/panel/register"
          class="mt-10 inline-flex items-center gap-2 bg-orange-600 hover:bg-orange-700 text-white font-bold px-5 py-3 rounded-[10px] transition-colors">
          Afiliar mi negocio
          <PhArrowRight :size="15" weight="bold" />
        </RouterLink>
      </div>
    </section>

    <!-- ── Preguntas frecuentes ── -->
    <section class="max-w-3xl mx-auto px-4 sm:px-6 py-16">
      <h2 class="text-2xl md:text-3xl font-extrabold text-gray-900 tracking-tight mb-8">Preguntas frecuentes</h2>

      <div class="divide-y divide-gray-200 border-y border-gray-200">
        <details v-for="faq in faqs" :key="faq.q" class="group py-5">
          <summary class="flex items-center justify-between gap-4 cursor-pointer list-none">
            <span class="font-semibold text-gray-900">{{ faq.q }}</span>
            <PhCaretDown :size="18" class="text-gray-400 shrink-0 transition-transform group-open:rotate-180" />
          </summary>
          <p class="mt-3 text-[15px] text-gray-600 leading-relaxed">{{ faq.a }}</p>
        </details>
      </div>
    </section>

  </div>
</template>

<script setup>
import {
  PhArrowRight, PhQrCode, PhDeviceMobile, PhSealCheck, PhCalendarCheck,
  PhChatCircleText, PhScan, PhStorefront, PhTicket, PhCaretDown,
} from '@phosphor-icons/vue'

const travelerSteps = [
  {
    title: 'Explora la oferta real',
    desc: 'Los tours y eventos que ves están publicados por los propios dueños, con horarios, precios y cupos actualizados.',
  },
  {
    title: 'Elige tu asiento o tus entradas',
    desc: 'En los tours en chiva escoges tu lugar en el mapa de asientos. En las atracciones eliges el evento y cuántas entradas quieres.',
  },
  {
    title: 'Paga por transferencia',
    desc: 'Te mostramos la cuenta bancaria del vendedor. Transfieres, subes la foto del comprobante y el número de referencia.',
  },
  {
    title: 'Recibe tu QR al instante',
    desc: 'Tu entrada llega a tu correo y puedes reenviarla a tu WhatsApp. El vendedor verifica el pago antes de la salida.',
  },
]

const faqs = [
  {
    q: '¿Necesito imprimir mi entrada?',
    a: 'No. Tu entrada es un código QR digital: basta con mostrarla desde tu teléfono al conductor o en la puerta del negocio.',
  },
  {
    q: '¿Cómo pago mi reserva?',
    a: 'Por ahora con transferencia o depósito bancario a la cuenta del vendedor. Subes tu comprobante al reservar y el vendedor lo verifica. El pago con tarjeta está en camino.',
  },
  {
    q: '¿Qué pasa si el vendedor rechaza mi comprobante?',
    a: 'Tu reserva queda pendiente hasta que el vendedor verifica el pago. Si hay un problema con el comprobante, los asientos se liberan y puedes contactar al vendedor para resolverlo.',
  },
  {
    q: '¿Puedo comprar sin crear una cuenta?',
    a: 'Sí, puedes comprar como invitado. Con una cuenta gratuita, además, guardas todas tus entradas en un solo lugar y las recuperas cuando quieras.',
  },
  {
    q: '¿Cuánto cuesta vender en chivaspass?',
    a: 'El registro de chivas y negocios es directo desde el panel. Escríbenos desde la página de contacto y te explicamos los planes disponibles.',
  },
]
</script>
