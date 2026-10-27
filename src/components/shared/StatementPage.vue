<template>
  <div>
    <PageHeader title="Estado de cuenta" description="Lo que liquidas con chivaspass cada mes por el cargo por servicio de tus ventas web.">
      <template #actions>
        <label class="sr-only" for="periodo">Mes</label>
        <select id="periodo" v-model="period" class="field-control h-10 w-auto min-w-44 print:hidden">
          <option v-for="m in monthOptions" :key="m" :value="m">{{ monthLabel(m) }}</option>
        </select>
        <BaseButton variant="secondary" class="print:hidden" @click="printPage">
          <PhPrinter :size="18" /> Imprimir
        </BaseButton>
      </template>
    </PageHeader>

    <BaseCard v-if="error" variant="danger">
      <p class="text-sm text-bad-700">{{ error }}</p>
    </BaseCard>

    <BaseCard v-else-if="!st">
      <p class="text-sm text-gray-600">Cargando tu estado de cuenta…</p>
    </BaseCard>

    <div v-else class="space-y-6">
      <!-- Saldo del mes -->
      <BaseCard :variant="st.status === 'vencido' ? 'danger' : 'default'">
        <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem] lg:items-start">
          <div>
            <div class="flex flex-wrap items-center gap-2">
              <p class="text-sm font-medium text-gray-600">{{ monthLabel(st.period) }}</p>
              <StatusBadge :tone="statusInfo.tone">{{ statusInfo.label }}</StatusBadge>
            </div>
            <p class="mt-3 text-sm font-medium text-gray-600">A pagar a chivaspass</p>
            <p class="mt-0.5 text-4xl font-bold tracking-[-0.02em] text-gray-900 tabular-nums">${{ money(Math.max(st.balance, 0)) }}</p>
            <p class="mt-2 max-w-[60ch] text-sm leading-relaxed text-gray-700">{{ statusInfo.text }}</p>
          </div>

          <dl class="rounded-lg border border-gray-200 bg-white p-4 text-sm">
            <div class="flex justify-between gap-4 py-1.5">
              <dt class="text-gray-600">Cargos cobrados en tus transferencias</dt>
              <dd class="font-semibold text-gray-900 tabular-nums">${{ money(st.fees_owed) }}</dd>
            </div>
            <div class="flex justify-between gap-4 py-1.5">
              <dt class="text-gray-600">Pagos registrados</dt>
              <dd class="font-semibold text-gray-900 tabular-nums">{{ st.paid > 0 ? '−' : '' }}${{ money(st.paid) }}</dd>
            </div>
            <div class="mt-1 flex justify-between gap-4 border-t border-gray-200 pt-2.5">
              <dt class="font-semibold text-gray-900">{{ st.balance < 0 ? 'Saldo a tu favor' : 'Saldo' }}</dt>
              <dd class="font-bold text-gray-900 tabular-nums">${{ money(Math.abs(st.balance)) }}</dd>
            </div>
            <p v-if="st.fees_card > 0" class="mt-3 border-t border-gray-100 pt-3 text-xs leading-relaxed text-gray-600">
              Los ${{ money(st.fees_card) }} de cargos en ventas con tarjeta ya los retuvo la pasarela: no los debes.
            </p>
          </dl>
        </div>
      </BaseCard>

      <!-- Cómo pagar -->
      <BaseCard v-if="showPay" variant="highlight" role="region" aria-labelledby="como-pagar" class="print:hidden">
        <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
          <div>
            <h2 id="como-pagar" class="text-lg font-semibold text-gray-900">Cómo pagar</h2>
            <p v-if="hasPlatformBank" class="mt-1 max-w-[60ch] text-sm leading-relaxed text-gray-700">
              Transfiere el saldo con estos datos y envíanos el comprobante<template v-if="PLATFORM_BANK.whatsapp"> por WhatsApp al
              <strong class="font-semibold text-gray-900 tabular-nums">{{ PLATFORM_BANK.whatsapp }}</strong></template><template v-else>
              desde la <RouterLink to="/contacto" class="font-semibold text-brand-700 underline underline-offset-2">página de contacto</RouterLink></template>.
              Lo verás aquí como pago registrado en menos de 24 horas.
            </p>
            <p v-else class="mt-1 max-w-[60ch] text-sm leading-relaxed text-gray-700">
              Escríbenos desde la <RouterLink to="/contacto" class="font-semibold text-brand-700 underline underline-offset-2">página de contacto</RouterLink>
              y te enviamos los datos para la transferencia. Tu pago aparecerá aquí en menos de 24 horas.
            </p>
          </div>
          <dl class="rounded-lg border border-brand-200 bg-white p-4 text-sm">
            <div v-for="row in payRows" :key="row.label" class="flex justify-between gap-4 py-1.5">
              <dt class="text-gray-600">{{ row.label }}</dt>
              <dd class="text-right font-semibold text-gray-900 tabular-nums break-all">{{ row.value }}</dd>
            </div>
          </dl>
        </div>
      </BaseCard>

      <!-- Ventas del mes por método -->
      <BaseCard :padded="false">
        <div class="overflow-x-auto">
          <table class="w-full min-w-[40rem] text-sm">
            <caption class="px-5 pt-5 pb-3 text-left sm:px-6">
              <span class="block text-base font-semibold text-gray-900">Tus ventas pagadas del mes</span>
              <span class="mt-0.5 block text-sm font-normal text-gray-600">Tú recibes siempre tu precio completo. El cargo por servicio lo paga el turista.</span>
            </caption>
            <thead class="border-y border-gray-200 bg-gray-50">
              <tr>
                <th scope="col" class="px-5 py-3 text-left font-medium text-gray-600 sm:px-6">Método</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">Ventas</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">{{ unitLabel }}</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">Tu precio</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">Cargo por servicio</th>
                <th scope="col" class="px-5 py-3 text-left font-medium text-gray-600 sm:px-6">Quién cobró el cargo</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-if="!st.methods.length">
                <td colspan="6" class="px-5 py-6 text-center text-gray-600 sm:px-6">No tuviste ventas pagadas este mes.</td>
              </tr>
              <tr v-for="m in st.methods" :key="m.metodo">
                <th scope="row" class="px-5 py-3 text-left font-medium text-gray-900 sm:px-6">{{ METHOD[m.metodo]?.label ?? m.metodo }}</th>
                <td class="px-4 py-3 text-right tabular-nums text-gray-700">{{ m.ventas }}</td>
                <td class="px-4 py-3 text-right tabular-nums text-gray-700">{{ m.cantidad }}</td>
                <td class="px-4 py-3 text-right tabular-nums font-semibold text-gray-900">${{ money(m.monto) }}</td>
                <td class="px-4 py-3 text-right tabular-nums text-gray-700">${{ money(m.cargo) }}</td>
                <td class="px-5 py-3 text-gray-700 sm:px-6">{{ METHOD[m.metodo]?.who ?? '' }}</td>
              </tr>
            </tbody>
            <tfoot v-if="st.methods.length > 1" class="border-t border-gray-200">
              <tr>
                <th scope="row" class="px-5 py-3 text-left font-semibold text-gray-900 sm:px-6">Total</th>
                <td class="px-4 py-3 text-right tabular-nums font-semibold text-gray-900">{{ totals.ventas }}</td>
                <td class="px-4 py-3 text-right tabular-nums font-semibold text-gray-900">{{ totals.cantidad }}</td>
                <td class="px-4 py-3 text-right tabular-nums font-bold text-gray-900">${{ money(totals.monto) }}</td>
                <td class="px-4 py-3 text-right tabular-nums font-semibold text-gray-900">${{ money(totals.cargo) }}</td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      </BaseCard>

      <!-- Detalle de cargos a liquidar -->
      <BaseCard v-if="st.lines.length" :padded="false">
        <div class="overflow-x-auto">
          <table class="w-full min-w-[36rem] text-sm">
            <caption class="px-5 pt-5 pb-3 text-left sm:px-6">
              <span class="block text-base font-semibold text-gray-900">Detalle de cargos a liquidar</span>
              <span class="mt-0.5 block text-sm font-normal text-gray-600">Ventas por transferencia en las que el turista te pagó el cargo junto con tu precio.</span>
            </caption>
            <thead class="border-y border-gray-200 bg-gray-50">
              <tr>
                <th scope="col" class="px-5 py-3 text-left font-medium text-gray-600 sm:px-6">Fecha</th>
                <th scope="col" class="px-4 py-3 text-left font-medium text-gray-600">Venta</th>
                <th scope="col" class="px-4 py-3 text-left font-medium text-gray-600">Cliente</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">Tu precio</th>
                <th scope="col" class="px-5 py-3 text-right font-medium text-gray-600 sm:px-6">Cargo</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="(l, i) in st.lines" :key="i">
                <td class="px-5 py-3 whitespace-nowrap tabular-nums text-gray-700 sm:px-6">{{ shortDate(l.fecha) }}</td>
                <td class="px-4 py-3 text-gray-900">
                  {{ l.concepto }}
                  <span class="text-gray-600">· {{ l.cantidad }} {{ l.kind === 'tour' ? (l.cantidad === 1 ? 'asiento' : 'asientos') : (l.cantidad === 1 ? 'entrada' : 'entradas') }}</span>
                </td>
                <td class="px-4 py-3 text-gray-700">{{ l.cliente || 'Sin nombre' }}</td>
                <td class="px-4 py-3 text-right tabular-nums text-gray-700">${{ money(l.monto) }}</td>
                <td class="px-5 py-3 text-right tabular-nums font-semibold text-gray-900 sm:px-6">${{ money(l.cargo) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </BaseCard>

      <!-- Pagos registrados -->
      <BaseCard v-if="st.payments.length">
        <template #title>Pagos registrados</template>
        <ul class="divide-y divide-gray-100 text-sm">
          <li v-for="(p, i) in st.payments" :key="i" class="flex items-center justify-between gap-4 py-2.5">
            <span class="text-gray-700">{{ shortDate(p.fecha) }}<span v-if="p.ref" class="text-gray-600"> · ref. {{ p.ref }}</span></span>
            <span class="font-semibold text-gray-900 tabular-nums">${{ money(p.monto) }}</span>
          </li>
        </ul>
      </BaseCard>

      <!-- Meses anteriores -->
      <BaseCard v-if="history.length > 1" :padded="false" class="print:hidden">
        <div class="overflow-x-auto">
          <table class="w-full min-w-[34rem] text-sm">
            <caption class="px-5 pt-5 pb-3 text-left text-base font-semibold text-gray-900 sm:px-6">Últimos meses</caption>
            <thead class="border-y border-gray-200 bg-gray-50">
              <tr>
                <th scope="col" class="px-5 py-3 text-left font-medium text-gray-600 sm:px-6">Mes</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">Cargos</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">Pagado</th>
                <th scope="col" class="px-4 py-3 text-right font-medium text-gray-600">Saldo</th>
                <th scope="col" class="px-5 py-3 text-left font-medium text-gray-600 sm:px-6">Estado</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="h in history" :key="h.period" :class="h.period === period && 'bg-brand-50'">
                <th scope="row" class="px-5 py-2 text-left font-normal sm:px-6">
                  <button type="button" class="inline-flex min-h-10 items-center font-medium text-brand-700 underline-offset-2 hover:underline"
                    :aria-current="h.period === period ? 'true' : undefined" @click="period = h.period">
                    {{ monthLabel(h.period) }}
                  </button>
                </th>
                <td class="px-4 py-2 text-right tabular-nums text-gray-700">${{ money(h.fees_owed) }}</td>
                <td class="px-4 py-2 text-right tabular-nums text-gray-700">${{ money(h.paid) }}</td>
                <td class="px-4 py-2 text-right tabular-nums font-semibold text-gray-900">${{ money(h.balance) }}</td>
                <td class="px-5 py-2 sm:px-6"><StatusBadge :tone="STATUS[h.status]?.tone ?? 'neutral'">{{ STATUS[h.status]?.label ?? h.status }}</StatusBadge></td>
              </tr>
            </tbody>
          </table>
        </div>
      </BaseCard>

      <BaseCard v-if="historyError" variant="danger" class="print:hidden">
        <p class="text-sm text-bad-700">
          {{ historyError }}
          <button type="button" class="font-semibold underline underline-offset-2" @click="loadHistory">Reintentar</button>
        </p>
      </BaseCard>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { PhPrinter } from '@phosphor-icons/vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'
import { money } from '@/lib/fees'
import { formatDate } from '@/lib/plans'
import { PLATFORM_BANK, hasPlatformBank, platformBankRows } from '@/lib/billing'
import PageHeader from '@/components/ui/PageHeader.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'

const auth = useAuthStore()

const STATUS = {
  en_curso:   { tone: 'info',    label: 'Mes en curso' },
  pendiente:  { tone: 'warning', label: 'Pendiente' },
  vencido:    { tone: 'danger',  label: 'Vencido' },
  pagado:     { tone: 'success', label: 'Pagado' },
  sin_cargos: { tone: 'neutral', label: 'Sin cargos' },
}

const METHOD = {
  efectivo:      { label: 'Efectivo',      who: 'No lleva cargo' },
  transferencia: { label: 'Transferencia', who: 'Tú: se liquida en este estado de cuenta' },
  tarjeta:       { label: 'Tarjeta',       who: 'La pasarela, al cobrar' },
}

const unitLabel = computed(() => auth.user?.role === 'negocio' ? 'Entradas' : 'Asientos')

// Primer día del mes en hora de Ecuador, como 'YYYY-MM-01'
const ecuadorToday = () => new Date().toLocaleDateString('en-CA', { timeZone: 'America/Guayaquil' })
const currentPeriod = () => ecuadorToday().slice(0, 8) + '01'

const period = ref(currentPeriod())
const st = ref(null)
const history = ref([])
const error = ref('')
const historyError = ref('')

const monthOptions = computed(() => {
  const set = new Set([currentPeriod(), ...history.value.map((h) => h.period)])
  return [...set].sort().reverse()
})

const monthLabel = (p) => {
  const s = new Date(`${p}T12:00:00`).toLocaleDateString('es-EC', { month: 'long', year: 'numeric' })
  return s.charAt(0).toUpperCase() + s.slice(1)
}

const shortDate = (iso) =>
  new Date(iso).toLocaleDateString('es-EC', { day: 'numeric', month: 'short', timeZone: 'America/Guayaquil' })

const lastDayOfMonth = (p) => {
  const d = new Date(`${p}T12:00:00`)
  return new Date(d.getFullYear(), d.getMonth() + 1, 0)
}

const statusInfo = computed(() => {
  const s = st.value
  const base = STATUS[s.status] ?? { tone: 'neutral', label: s.status }
  const due = formatDate(`${s.due_date}T12:00:00`)
  const text = {
    en_curso: s.fees_owed > 0
      ? `El mes sigue abierto: el saldo puede crecer con nuevas ventas por transferencia. Cierra el ${formatDate(lastDayOfMonth(s.period))} y se paga hasta el ${due}.`
      : `El mes sigue abierto. Cierra el ${formatDate(lastDayOfMonth(s.period))} y se paga hasta el ${due}.`,
    pendiente:  `Págalo hasta el ${due}.`,
    vencido:    `El plazo venció el ${due}. Págalo cuanto antes para mantener tu cuenta al día.`,
    pagado:     s.balance < 0 ? `Este mes está al día y tienes $${money(-s.balance)} a favor.` : 'Este mes está al día. Gracias.',
    sin_cargos: 'Este mes no tuviste ventas por transferencia con cargo por servicio. No debes nada.',
  }[s.status] ?? ''
  return { ...base, text }
})

const totals = computed(() => (st.value?.methods ?? []).reduce((t, m) => ({
  ventas:   t.ventas + Number(m.ventas),
  cantidad: t.cantidad + Number(m.cantidad),
  monto:    t.monto + Number(m.monto),
  cargo:    t.cargo + Number(m.cargo),
}), { ventas: 0, cantidad: 0, monto: 0, cargo: 0 }))

const showPay = computed(() => st.value && st.value.balance > 0 && st.value.status !== 'en_curso')

const payRows = computed(() => !st.value ? [] : [
  ...platformBankRows(),
  { label: 'Monto',    value: `$${money(st.value.balance)}` },
  { label: 'Concepto', value: `chivaspass cargos ${monthLabel(st.value.period)} - ${auth.user?.email ?? ''}` },
])

const loadStatement = async () => {
  error.value = ''
  st.value = null
  const { data, error: e } = await supabase.rpc('my_statement', { p_period: period.value })
  if (e) { error.value = 'No se pudo cargar el estado de cuenta. Intenta de nuevo en un momento.'; return }
  st.value = data
}

const loadHistory = async () => {
  historyError.value = ''
  const { data, error: e } = await supabase.rpc('my_statement_history')
  if (e) {
    console.error('my_statement_history:', e.message)
    historyError.value = 'No se pudo cargar el historial de meses anteriores.'
    return
  }
  history.value = data ?? []
}

const printPage = () => window.print()

watch(period, loadStatement)
onMounted(() => { loadStatement(); loadHistory() })
</script>
