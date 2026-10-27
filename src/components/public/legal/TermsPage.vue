<template>
  <div class="bg-white">

    <header class="border-b border-gray-100 bg-gray-50">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 pt-12 pb-10">
        <h1 class="text-3xl md:text-4xl font-extrabold text-gray-900 tracking-tight">Términos y condiciones</h1>
        <p class="mt-3 max-w-prose text-gray-600 leading-relaxed">
          Las reglas para comprar y usar tickets en chivaspass. Al confirmar una compra aceptas estos términos, así que léelos antes de pagar.
        </p>
        <p class="mt-4 text-sm text-gray-600">Actualizados el {{ LEGAL.updated }}</p>
      </div>
    </header>

    <div class="max-w-5xl mx-auto px-4 sm:px-6 py-12 lg:grid lg:grid-cols-[13rem_minmax(0,1fr)] lg:gap-14">

      <nav aria-label="Secciones de los términos" class="mb-12 lg:mb-0">
        <div class="lg:sticky lg:top-24">
          <p class="text-sm font-semibold text-gray-900">En esta página</p>
          <ol class="mt-3 border-l border-gray-200 text-sm">
            <li v-for="s in sections" :key="s.id">
              <RouterLink :to="{ hash: `#${s.id}` }"
                class="-ml-px block border-l border-transparent py-1.5 pl-3 text-gray-600 hover:border-brand-600 hover:text-gray-900 transition-colors">
                {{ s.title }}
              </RouterLink>
            </li>
          </ol>
        </div>
      </nav>

      <article class="max-w-prose text-[0.95rem] text-gray-700
        [&_section]:scroll-mt-24 [&_section+section]:mt-12
        [&_h2]:text-xl [&_h2]:font-bold [&_h2]:tracking-tight [&_h2]:text-gray-900
        [&_h3]:mt-6 [&_h3]:font-semibold [&_h3]:text-gray-900
        [&_p]:mt-3 [&_p]:leading-7
        [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:space-y-2 [&_ul]:pl-5 [&_li]:leading-7 [&_li]:marker:text-gray-400
        [&_a]:font-medium [&_a]:text-brand-700 [&_a]:underline [&_a]:underline-offset-2 [&_a:hover]:text-brand-800
        [&_strong]:font-semibold [&_strong]:text-gray-900">

        <section id="que-es">
          <h2>Qué es chivaspass</h2>
          <p>
            chivaspass es una plataforma web donde los dueños de chivas, las agencias y los negocios turísticos de Baños de Agua Santa venden tickets para sus tours, eventos y atracciones. La opera {{ LEGAL.owner }}<template v-if="LEGAL.ruc">, RUC {{ LEGAL.ruc }}</template>, en {{ LEGAL.city }}.
          </p>
          <p>
            Somos un <strong>intermediario tecnológico</strong>: publicamos la oferta, registramos tu reserva y emitimos tu ticket. El tour, la entrada o la actividad la presta el <strong>vendedor</strong> que la publica, es decir, el dueño de la chiva o del negocio. Su nombre aparece en la ficha antes de comprar y en tu ticket.
          </p>
          <p>
            chivaspass no recibe ni guarda el dinero de tus compras. Lo pagas directamente al vendedor.
          </p>
        </section>

        <section id="cuentas">
          <h2>Tu cuenta</h2>
          <ul>
            <li>Puedes comprar como invitado o con una cuenta. Con la cuenta tienes todas tus entradas en "Mis entradas".</li>
            <li>Para comprar o crear una cuenta debes tener al menos 18 años. Un adulto puede comprar tickets para menores que viajen con él.</li>
            <li>Usa datos reales. Tu correo y tu teléfono son por donde te llega el ticket y por donde te avisamos si la salida cambia.</li>
            <li>Tu contraseña es personal. Si crees que alguien entró a tu cuenta, escríbenos a <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a> y la bloqueamos.</li>
            <li>Si vendes en chivaspass, además de estos términos aplican las condiciones del plan que contrataste.</li>
          </ul>
        </section>

        <section id="compra">
          <h2>Compra y precio</h2>
          <ul>
            <li>El precio de cada tour o entrada lo fija el vendedor, en dólares de los Estados Unidos, e incluye lo que dice la ficha.</li>
            <li>En las compras por la web se suma un <strong>cargo por servicio</strong> de chivaspass: el 8 % del precio de la compra más $0,30, redondeado a los 5 centavos. Cubre la reserva en línea, el ticket QR y los avisos.</li>
            <li>Antes de pagar ves el desglose completo: precio, cargo por servicio y total. No hay cobros extra después.</li>
            <li>Las ventas en el mostrador de una agencia o pagadas en efectivo al vendedor no llevan cargo por servicio.</li>
            <li>La compra queda registrada cuando ves la confirmación en pantalla y te llega el correo con tu ticket.</li>
          </ul>
        </section>

        <section id="pago">
          <h2>Pago y verificación</h2>
          <p>
            Por ahora el pago es por <strong>transferencia o depósito</strong> a la cuenta bancaria del vendedor, que te mostramos al reservar. Transfieres el total, subes la foto del comprobante y escribes el número de referencia.
          </p>
          <p>
            El vendedor revisa que el dinero haya llegado a su cuenta y marca el pago como verificado. Si el comprobante no coincide (monto distinto, referencia que no existe, transferencia a otra cuenta), puede rechazarlo y la reserva se anula.
          </p>
          <p>
            Cuando el pago con tarjeta esté disponible, lo procesará una pasarela de pagos autorizada. chivaspass no ve ni guarda los datos de tu tarjeta.
          </p>
        </section>

        <section id="liberacion">
          <h2>Reservas sin verificar</h2>
          <p>
            Mientras el vendedor no verifica tu pago, tus asientos o entradas quedan apartados, pero no para siempre. Si el pago sigue sin verificar <strong>24 horas después de reservar</strong>, o cuando faltan <strong>60 minutos para la salida</strong> (lo que ocurra primero), la reserva se libera y esos lugares vuelven a la venta.
          </p>
          <p>
            Si ya transferiste y tu reserva se liberó porque el vendedor no alcanzó a verificarla, tienes derecho a que te devuelva todo lo que pagaste o a que te dé otra reserva, como prefieras. Escríbele a él o a nosotros con tu número de reserva.
          </p>
        </section>

        <section id="ticket">
          <h2>Tu ticket QR y el embarque</h2>
          <ul>
            <li>Tu ticket es un código QR único por reserva. Te llega por correo y está en "Mis entradas" si tienes cuenta. No necesitas imprimirlo.</li>
            <li>El conductor o el personal del negocio escanea el QR al embarcar o en la puerta. Cada código sirve una sola vez.</li>
            <li>Llega al punto de salida antes de la hora que indica tu ticket. Si no llegas a tiempo, la chiva puede salir sin ti y eso cuenta como servicio no usado.</li>
            <li>No compartas tu QR en redes sociales. Quien lo presente primero ocupa el lugar.</li>
            <li>El vendedor puede pedirte tu cédula o pasaporte para confirmar que la reserva es tuya.</li>
          </ul>
        </section>

        <section id="vendedor">
          <h2>Lo que le toca al vendedor</h2>
          <p>
            El vendedor es el responsable del servicio turístico: cumplir el horario y el recorrido publicados, tener el vehículo o las instalaciones en buen estado, contar con los permisos y seguros que exige la ley, la seguridad de los pasajeros y la factura de tu compra.
          </p>
          <p>
            Si algo falla durante el tour o la actividad, el reclamo es ante el vendedor. Nosotros te ayudamos a contactarlo y le trasladamos tu caso.
          </p>
        </section>

        <section id="reembolsos">
          <h2>Cancelaciones y reembolsos</h2>
          <p>
            Como transfieres el dinero a la cuenta del vendedor, el reembolso lo hace el vendedor, por transferencia a la cuenta que le indiques.
          </p>

          <h3>Si el vendedor cancela o la salida no se realiza</h3>
          <p>
            Si el vendedor cancela, la salida no se hace (por clima, por el volcán, por una falla del vehículo o por cualquier otra causa ajena a ti) o el evento se suspende, te devuelve el <strong>total: el precio y el cargo por servicio</strong>. Si te ofrece otra fecha, aceptarla es decisión tuya.
          </p>

          <h3>Si cancelas tú</h3>
          <p>
            Aplica la política de cancelación del vendedor. Si no publicó una más favorable, puedes cancelar y recibir la devolución del precio <strong>hasta 24 horas antes</strong> de la salida o del evento. Pasado ese plazo, o si no llegas a la hora, el vendedor no está obligado a devolverte el dinero.
          </p>

          <h3>El cargo por servicio</h3>
          <p>
            El cargo por servicio no se reembolsa cuando el servicio se prestó, aunque el vendedor te devuelva una parte del precio por un reclamo. Cuando la venta se anula antes de la salida, por cancelación a tiempo o por cancelación del vendedor, se devuelve junto con el precio.
          </p>

          <h3>Cómo pedirlo y en qué plazos</h3>
          <ul>
            <li>Escribe al vendedor con los datos que aparecen en tu ticket, o a <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a>, con tu número de reserva y el motivo.</li>
            <li>chivaspass te responde en máximo 3 días hábiles y, si hace falta, le pasa tu pedido al vendedor.</li>
            <li>El vendedor debe responderte en máximo 5 días hábiles. Si el reembolso procede, debe hacerlo en máximo 15 días desde que lo acepta.</li>
          </ul>

          <h3>Tu derecho a reclamar</h3>
          <p>
            Nada de esto limita los derechos que te da la Ley Orgánica de Defensa del Consumidor. Si no quedas conforme con la respuesta del vendedor o la nuestra, puedes presentar tu reclamo ante la Defensoría del Pueblo o ante las autoridades de consumo competentes.
          </p>
        </section>

        <section id="conducta">
          <h2>Uso correcto</h2>
          <p>No está permitido:</p>
          <ul>
            <li>Subir comprobantes falsos, editados o de otra compra. La reserva se anula y el caso se puede denunciar.</li>
            <li>Comprar con datos de otra persona sin su permiso.</li>
            <li>Apartar asientos sin intención de pagar, o usar programas automáticos para reservar.</li>
            <li>Revender tickets a un precio mayor al pagado.</li>
            <li>Copiar el contenido o las fotos del sitio para otro fin, o intentar entrar a partes del sistema que no te corresponden.</li>
          </ul>
          <p>
            Si alguien incumple estas reglas podemos cancelar sus reservas pendientes y suspender su cuenta.
          </p>
        </section>

        <section id="responsabilidad">
          <h2>Límites de nuestra responsabilidad</h2>
          <p>
            chivaspass responde porque la plataforma funcione: que tu reserva quede registrada, que tu ticket se emita y que el cargo por servicio sea el que viste antes de pagar.
          </p>
          <p>
            No respondemos por la prestación del tour o la actividad, que es del vendedor, ni por demoras de los bancos en acreditar transferencias, ni por cortes de internet o de luz que no dependen de nosotros.
          </p>
          <p>
            Esta sección no excluye la responsabilidad que la ley no permite excluir.
          </p>
        </section>

        <section id="cambios">
          <h2>Cambios a estos términos</h2>
          <p>
            Podemos actualizar estos términos. La fecha de arriba indica la última versión. Los cambios no afectan las compras que ya hiciste: cada compra se rige por los términos vigentes el día en que pagaste. Si el cambio es importante y tienes cuenta, te avisamos por correo.
          </p>
        </section>

        <section id="ley">
          <h2>Ley aplicable</h2>
          <p>
            Estos términos se rigen por las leyes de Ecuador, en particular la Ley Orgánica de Defensa del Consumidor, la Ley de Comercio Electrónico, Firmas Electrónicas y Mensajes de Datos y la Ley Orgánica de Protección de Datos Personales. Antes de ir a un juez, intentemos resolverlo directamente. Si no se puede, son competentes los jueces de Ecuador.
          </p>
          <p>
            Cómo tratamos tus datos está en la <RouterLink to="/privacidad">política de privacidad</RouterLink>.
          </p>
        </section>

        <section id="contacto">
          <h2>Contacto</h2>
          <ul>
            <li>Titular: {{ LEGAL.owner }}</li>
            <li v-if="LEGAL.ruc">RUC: {{ LEGAL.ruc }}</li>
            <li>Domicilio: {{ LEGAL.city }}</li>
            <li>Correo: <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a></li>
            <li>También puedes escribirnos desde el <RouterLink to="/contacto">formulario de contacto</RouterLink>.</li>
          </ul>
        </section>

      </article>
    </div>
  </div>
</template>

<script setup>
import { LEGAL } from '@/lib/legal'

const sections = [
  { id: 'que-es',          title: 'Qué es chivaspass' },
  { id: 'cuentas',         title: 'Tu cuenta' },
  { id: 'compra',          title: 'Compra y precio' },
  { id: 'pago',            title: 'Pago y verificación' },
  { id: 'liberacion',      title: 'Reservas sin verificar' },
  { id: 'ticket',          title: 'Tu ticket QR y el embarque' },
  { id: 'vendedor',        title: 'Lo que le toca al vendedor' },
  { id: 'reembolsos',      title: 'Cancelaciones y reembolsos' },
  { id: 'conducta',        title: 'Uso correcto' },
  { id: 'responsabilidad', title: 'Límites de nuestra responsabilidad' },
  { id: 'cambios',         title: 'Cambios a estos términos' },
  { id: 'ley',             title: 'Ley aplicable' },
  { id: 'contacto',        title: 'Contacto' },
]
</script>
