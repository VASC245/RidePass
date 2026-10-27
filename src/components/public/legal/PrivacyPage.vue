<template>
  <div class="bg-white">

    <header class="border-b border-gray-100 bg-gray-50">
      <div class="max-w-5xl mx-auto px-4 sm:px-6 pt-12 pb-10">
        <h1 class="text-3xl md:text-4xl font-extrabold text-gray-900 tracking-tight">Política de privacidad</h1>
        <p class="mt-3 max-w-prose text-gray-600 leading-relaxed">
          Qué datos tuyos guardamos, para qué los usamos, con quién los compartimos y cómo puedes pedir que los corrijamos o los borremos. Se rige por la Ley Orgánica de Protección de Datos Personales (LOPDP).
        </p>
        <p class="mt-4 text-sm text-gray-600">Actualizada el {{ LEGAL.updated }}</p>
      </div>
    </header>

    <div class="max-w-5xl mx-auto px-4 sm:px-6 py-12 lg:grid lg:grid-cols-[13rem_minmax(0,1fr)] lg:gap-14">

      <nav aria-label="Secciones de la política" class="mb-12 lg:mb-0">
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
        [&_p]:mt-3 [&_p]:leading-7
        [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:space-y-2 [&_ul]:pl-5 [&_li]:leading-7 [&_li]:marker:text-gray-400
        [&_a]:font-medium [&_a]:text-brand-700 [&_a]:underline [&_a]:underline-offset-2 [&_a:hover]:text-brand-800
        [&_strong]:font-semibold [&_strong]:text-gray-900">

        <section id="responsable">
          <h2>Quién es responsable</h2>
          <p>
            El responsable del tratamiento de tus datos en chivaspass es {{ LEGAL.owner }}<template v-if="LEGAL.ruc">, RUC {{ LEGAL.ruc }}</template>, con domicilio en {{ LEGAL.city }}. Para cualquier tema de privacidad escribe a <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a>.
          </p>
          <p>
            Cuando compras, el vendedor del tour o de la entrada (el dueño de la chiva o del negocio) recibe tus datos para prestarte el servicio. Desde ese momento también es responsable de usarlos solo para eso.
          </p>
        </section>

        <section id="datos">
          <h2>Qué datos recogemos</h2>
          <ul>
            <li><strong>Identificación y contacto:</strong> nombre, correo, teléfono, número de cédula o pasaporte y dirección. Los pedimos al comprar para identificarte al embarcar y para que el vendedor pueda emitir tu factura.</li>
            <li><strong>Tu compra:</strong> el tour o evento, la fecha, los asientos, los montos, el estado del pago y la hora en que se escaneó tu QR.</li>
            <li><strong>Comprobante de pago:</strong> la foto o el archivo de tu transferencia y su número de referencia. Puede mostrar tu nombre, tu banco y parte de tu número de cuenta.</li>
            <li><strong>Tarjeta:</strong> cuando el pago con tarjeta esté activo, los datos de la tarjeta los recibe y procesa directamente la pasarela de pagos. chivaspass no los ve ni los guarda; solo recibimos si el cobro fue aprobado.</li>
            <li><strong>Tu cuenta, si creas una:</strong> correo y contraseña. La contraseña se guarda cifrada y nadie de chivaspass puede leerla.</li>
            <li><strong>Datos técnicos:</strong> dirección IP y tipo de navegador, para frenar abusos y ataques.</li>
          </ul>
          <p>
            No pedimos datos sensibles (salud, religión, origen étnico ni similares) y no usamos cookies de publicidad ni de seguimiento.
          </p>
        </section>

        <section id="finalidades">
          <h2>Para qué los usamos</h2>
          <ul>
            <li>Registrar tu reserva, emitir tu ticket QR y enviártelo.</li>
            <li>Que el vendedor verifique tu pago y controle el embarque o la entrada.</li>
            <li>Avisarte por correo o SMS de la confirmación, la verificación del pago o cualquier cambio o cancelación de tu salida.</li>
            <li>Atender tus reclamos y pedidos de reembolso.</li>
            <li>Cumplir obligaciones legales y tributarias, y responder a autoridades cuando la ley lo exija.</li>
            <li>Proteger la plataforma contra fraudes y comprobantes falsos.</li>
          </ul>
          <p>
            No vendemos tus datos ni los usamos para publicidad. Si algún día queremos enviarte promociones, te pediremos permiso aparte.
          </p>
        </section>

        <section id="base-legal">
          <h2>Base legal</h2>
          <p>
            Tratamos tus datos con las bases que reconoce el artículo 7 de la LOPDP:
          </p>
          <ul>
            <li><strong>Ejecución del contrato:</strong> sin tus datos de contacto e identificación no podemos registrar la compra, emitir el ticket ni dejarte embarcar.</li>
            <li><strong>Consentimiento:</strong> lo das al aceptar esta política al comprar o al crear tu cuenta. Puedes retirarlo cuando quieras, sin afectar lo que ya se hizo antes.</li>
            <li><strong>Obligación legal:</strong> para conservar los datos de venta que exige la normativa tributaria.</li>
          </ul>
        </section>

        <section id="destinatarios">
          <h2>Con quién los compartimos</h2>
          <ul>
            <li><strong>El vendedor de tu compra</strong>, y solo los datos de esa compra. No ve tus otras compras ni las de otros vendedores.</li>
            <li><strong>Supabase:</strong> aloja la base de datos, las cuentas y los comprobantes.</li>
            <li><strong>Cloudflare:</strong> aloja y sirve el sitio web.</li>
            <li><strong>Brevo:</strong> envía los correos y los SMS.</li>
            <li><strong>La pasarela de pagos con tarjeta</strong>, cuando ese pago esté activo.</li>
            <li><strong>Autoridades</strong>, solo cuando una ley o una orden judicial lo exija.</li>
          </ul>
          <p>
            Estos proveedores actúan como encargados: usan tus datos solo para prestarnos su servicio y no pueden usarlos para fines propios.
          </p>
        </section>

        <section id="transferencias">
          <h2>Transferencias internacionales</h2>
          <p>
            Supabase, Cloudflare y Brevo guardan o procesan datos en servidores fuera de Ecuador, principalmente en Estados Unidos (y en la Unión Europea en el caso de Brevo). Elegimos proveedores con contratos de protección de datos y cifrado, como exige la LOPDP para estas transferencias. Al usar chivaspass aceptas que tus datos se procesen en esos países.
          </p>
        </section>

        <section id="conservacion">
          <h2>Cuánto tiempo los guardamos</h2>
          <ul>
            <li><strong>Comprobantes de pago:</strong> 90 días después de la fecha de la salida o del evento. Luego se borran.</li>
            <li><strong>Datos de la venta</strong> (nombre, cédula, montos y fechas): el tiempo que exige la normativa tributaria de Ecuador.</li>
            <li><strong>Tu cuenta:</strong> mientras la tengas activa. Si pides borrarla, eliminamos tus datos de cuenta en 15 días, salvo los datos de venta que la ley nos obliga a conservar.</li>
            <li><strong>Datos técnicos:</strong> pocos días, salvo que formen parte de la investigación de un fraude.</li>
          </ul>
        </section>

        <section id="derechos">
          <h2>Tus derechos y cómo ejercerlos</h2>
          <p>La LOPDP te da derecho a:</p>
          <ul>
            <li><strong>Acceso:</strong> saber qué datos tuyos tenemos y qué hacemos con ellos.</li>
            <li><strong>Rectificación:</strong> corregir datos equivocados o incompletos.</li>
            <li><strong>Eliminación:</strong> pedir que borremos tus datos cuando ya no sean necesarios.</li>
            <li><strong>Oposición:</strong> negarte a un uso concreto de tus datos.</li>
            <li><strong>Portabilidad:</strong> recibir tus datos en un archivo que puedas llevar a otro servicio.</li>
            <li><strong>Suspensión del tratamiento:</strong> pedir que dejemos de usar tus datos mientras se resuelve un reclamo.</li>
          </ul>
          <p>
            Para ejercerlos, escribe a <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a> desde el correo con el que compraste o creaste tu cuenta. Di qué derecho quieres ejercer y, si aplica, tu número de reserva. Solo te pediremos tu cédula si no podemos confirmar de otra forma que eres tú.
          </p>
          <p>
            Te respondemos en un plazo máximo de <strong>15 días</strong>. Es gratis. Si el pedido toca datos que tiene el vendedor, se lo trasladamos para que también lo cumpla.
          </p>
        </section>

        <section id="seguridad">
          <h2>Seguridad</h2>
          <ul>
            <li>Todo el sitio funciona con conexión cifrada (HTTPS).</li>
            <li>Los comprobantes se guardan en un almacenamiento privado. Solo el vendedor de esa compra puede abrirlos, con enlaces que caducan en una hora.</li>
            <li>Cada vendedor ve únicamente sus propias ventas; las reglas de acceso se aplican en la base de datos, no solo en la pantalla.</li>
            <li>Si ocurre una filtración que afecte tus datos, avisamos a la autoridad y a las personas afectadas en los plazos que fija la LOPDP.</li>
          </ul>
        </section>

        <section id="menores">
          <h2>Menores de edad</h2>
          <p>
            chivaspass no está dirigido a menores de 18 años. Un adulto puede comprar tickets para menores que viajen con él, y es quien nos da los datos. Si descubrimos que guardamos datos de un menor sin autorización de su representante, los borramos.
          </p>
        </section>

        <section id="cambios">
          <h2>Cambios a esta política</h2>
          <p>
            Si cambiamos esta política, actualizamos la fecha de arriba. Si el cambio afecta cómo usamos tus datos y tienes cuenta, te avisamos por correo antes de aplicarlo.
          </p>
        </section>

        <section id="autoridad">
          <h2>Dónde reclamar</h2>
          <p>
            Si crees que no respetamos tus derechos, primero escríbenos a <a :href="`mailto:${LEGAL.email}`">{{ LEGAL.email }}</a>. Si no te respondemos en 15 días o no estás conforme, puedes presentar un reclamo ante la Autoridad de Protección de Datos Personales de Ecuador (Superintendencia de Protección de Datos Personales).
          </p>
          <p>
            Las condiciones de compra están en los <RouterLink to="/terminos">términos y condiciones</RouterLink>.
          </p>
        </section>

      </article>
    </div>
  </div>
</template>

<script setup>
import { LEGAL } from '@/lib/legal'

const sections = [
  { id: 'responsable',    title: 'Quién es responsable' },
  { id: 'datos',          title: 'Qué datos recogemos' },
  { id: 'finalidades',    title: 'Para qué los usamos' },
  { id: 'base-legal',     title: 'Base legal' },
  { id: 'destinatarios',  title: 'Con quién los compartimos' },
  { id: 'transferencias', title: 'Transferencias internacionales' },
  { id: 'conservacion',   title: 'Cuánto tiempo los guardamos' },
  { id: 'derechos',       title: 'Tus derechos' },
  { id: 'seguridad',      title: 'Seguridad' },
  { id: 'menores',        title: 'Menores de edad' },
  { id: 'cambios',        title: 'Cambios a esta política' },
  { id: 'autoridad',      title: 'Dónde reclamar' },
]
</script>
