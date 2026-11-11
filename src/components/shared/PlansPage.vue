<template>
  <div>
    <PageHeader title="Tu plan" :description="headerText" />

    <BaseCard v-if="!isSeller">
      <p class="text-sm text-gray-700">Tu cuenta no necesita plan. Los planes son para dueños de chivas, establecimientos y promotores.</p>
    </BaseCard>

    <div v-else class="space-y-8">
      <!-- Estado actual -->
      <BaseCard v-if="loading && !plan">
        <p class="text-sm text-gray-600">Cargando tu plan…</p>
      </BaseCard>

      <BaseCard v-else-if="plan" :variant="plan.status === 'vencido' || plan.reason ? 'danger' : 'default'">
        <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_20rem] lg:items-center">
          <div>
            <StatusBadge :tone="status.tone">{{ status.badge }}</StatusBadge>
            <h2 class="mt-3 text-xl font-bold tracking-[-0.01em] text-gray-900">{{ status.title }}</h2>
            <p class="mt-1 max-w-[62ch] text-sm leading-relaxed text-gray-700">{{ status.text }}</p>
          </div>

          <div v-if="showUsage" class="rounded-lg border border-gray-200 bg-white p-4">
            <p class="text-sm font-medium text-gray-600">Este mes</p>
            <p class="mt-1 text-2xl font-bold text-gray-900 tabular-nums">
              {{ plan.used_this_month }}<span v-if="plan.monthly_limit" class="text-base font-semibold text-gray-600"> de {{ plan.monthly_limit.toLocaleString('es-EC') }}</span>
              <span class="text-sm font-medium text-gray-600"> {{ unit }}</span>
            </p>
            <div v-if="plan.monthly_limit" class="mt-3 h-2 overflow-hidden rounded-full bg-gray-100"
              role="progressbar" :aria-valuenow="plan.used_this_month" aria-valuemin="0" :aria-valuemax="plan.monthly_limit"
              :aria-label="`${plan.used_this_month} de ${plan.monthly_limit} ${unit} usados este mes`">
              <div class="h-full rounded-full transition-[width] duration-200 ease-out"
                :class="usagePct >= 0.8 ? 'bg-warn-600' : 'bg-brand-600'"
                :style="{ width: `${Math.max(usagePct * 100, plan.used_this_month ? 2 : 0)}%` }" />
            </div>
            <p v-if="plan.monthly_limit" class="mt-2 text-xs text-gray-600">El contador vuelve a cero el primer día de cada mes.</p>
          </div>
        </div>
      </BaseCard>

      <!-- Planes del rol -->
      <ul class="overflow-hidden rounded-[var(--radius-card)] border border-gray-200 bg-white divide-y divide-gray-200" aria-label="Planes disponibles">
        <li v-for="p in rolePlans" :key="p.id"
          class="grid gap-4 p-5 sm:p-6 lg:grid-cols-[15rem_minmax(0,1fr)_12rem] lg:items-center lg:gap-8"
          :class="p.id === currentPlanId && 'bg-brand-50'">
          <div>
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="text-lg font-semibold text-gray-900">{{ p.name }}</h2>
              <StatusBadge v-if="p.id === currentPlanId" tone="brand">Tu plan</StatusBadge>
            </div>
            <p class="mt-1 flex items-baseline gap-1">
              <span class="text-3xl font-bold tracking-[-0.02em] text-gray-900 tabular-nums">${{ p.monthly }}</span>
              <span class="text-sm text-gray-600">{{ p.free ? 'gratis' : p.perUnit ? 'por chiva al mes' : 'al mes' }}</span>
            </p>
            <p v-if="p.yearly" class="mt-0.5 text-sm text-gray-600 tabular-nums">o ${{ p.yearly }} por chiva al año</p>
          </div>

          <div>
            <ul class="grid gap-x-6 gap-y-2 text-sm text-gray-700 sm:grid-cols-2">
              <li v-for="f in p.features" :key="f" class="flex items-start gap-2">
                <PhCheck :size="16" weight="bold" class="mt-0.5 shrink-0 text-ok-700" />
                {{ f }}
              </li>
            </ul>
            <p v-if="p.perUnit" class="mt-4 text-sm text-gray-700">
              Con {{ units === 1 ? 'tu chiva' : `tus ${units} chivas` }}:
              <strong class="font-semibold text-gray-900 tabular-nums">${{ p.monthly * units }} al mes</strong>
              o <strong class="font-semibold text-gray-900 tabular-nums">${{ p.yearly * units }} al año</strong>
              <span class="text-gray-600">(ahorras ${{ (p.monthly * 12 - p.yearly) * units }})</span>.
            </p>
          </div>

          <div class="flex flex-col gap-2 lg:items-stretch">
            <template v-if="p.free">
              <p v-if="p.id === currentPlanId" class="inline-flex h-10 items-center gap-1.5 text-sm font-semibold text-brand-800 lg:justify-end">
                <PhCheckCircle :size="18" weight="fill" /> Incluido
              </p>
              <p v-else class="text-sm text-gray-600 lg:text-right">Sin costo</p>
            </template>
            <template v-else-if="p.perUnit">
              <BaseButton variant="primary" @click="choose(p, 'anual')">Pagar un año</BaseButton>
              <BaseButton variant="secondary" @click="choose(p, 'mensual')">Pagar un mes</BaseButton>
            </template>
            <BaseButton v-else :variant="p.id === currentPlanId ? 'secondary' : 'primary'" @click="choose(p, 'mensual')">
              {{ p.id === currentPlanId ? 'Renovar' : `Activar ${p.name}` }}
            </BaseButton>
          </div>
        </li>
      </ul>

      <!-- Instrucciones de pago -->
      <BaseCard v-if="pending" ref="payCard" variant="highlight" role="region" aria-labelledby="pago-plan">
        <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
          <div>
            <h2 id="pago-plan" class="text-lg font-semibold text-gray-900">
              Activar {{ pending.plan.name }} {{ pending.billing === 'anual' ? 'por un año' : 'por un mes' }}
            </h2>
            <p v-if="hasBank" class="mt-1 max-w-[60ch] text-sm leading-relaxed text-gray-700">
              Haz la transferencia con estos datos y envíanos el comprobante<template v-if="bank.whatsapp"> por WhatsApp al
              <strong class="font-semibold text-gray-900 tabular-nums">{{ bank.whatsapp }}</strong></template><template v-else>
              desde la <RouterLink to="/contacto?motivo=pago" class="font-semibold text-brand-700 underline underline-offset-2">página de contacto</RouterLink></template>.
              Activamos tu plan en menos de 24 horas.
            </p>
            <p v-else class="mt-1 max-w-[60ch] text-sm leading-relaxed text-gray-700">
              Escríbenos desde la <RouterLink to="/contacto?motivo=pago" class="font-semibold text-brand-700 underline underline-offset-2">página de contacto</RouterLink>
              con el plan que elegiste y te enviamos los datos para la transferencia. Activamos tu plan en menos de 24 horas desde tu pago.
            </p>
            <p v-if="plan?.status === 'activo' && plan?.expires_at" class="mt-3 text-sm text-gray-600">
              Si renuevas antes del {{ formatDate(plan.expires_at) }}, el periodo nuevo empieza cuando termine el actual.
            </p>
            <BaseButton variant="ghost" size="sm" class="mt-4 -ml-3" @click="pending = null">Cancelar</BaseButton>
          </div>
          <dl class="rounded-lg border border-brand-200 bg-white p-4 text-sm">
            <div v-for="row in payRows" :key="row.label" class="flex justify-between gap-4 py-1.5">
              <dt class="text-gray-600">{{ row.label }}</dt>
              <dd class="text-right font-semibold text-gray-900 tabular-nums break-all">{{ row.value }}</dd>
            </div>
          </dl>
        </div>
      </BaseCard>

      <p v-if="role !== 'agencia'" class="max-w-[70ch] text-sm leading-relaxed text-gray-600">
        En las ventas por la web, el turista paga un cargo por servicio aparte y tú recibes tu precio íntegro.
        Las ventas en efectivo y las de promotores no pagan cargo.
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'
import { useAuthStore } from '@/stores/authStore'
import { PhCheck, PhCheckCircle } from '@phosphor-icons/vue'
import PageHeader from '@/components/ui/PageHeader.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'
import { usePlan } from '@/composables/usePlan'
import { PLANS, PLANS_BY_ROLE, UNIT_LABEL, formatDate } from '@/lib/plans'
import { PLATFORM_BANK, hasPlatformBank, platformBankRows } from '@/lib/billing'

const auth = useAuthStore()
const { plan, loading, load, trialDaysLeft, usagePct } = usePlan()

const role = computed(() => auth.user?.role)
const isSeller = computed(() => !!PLANS_BY_ROLE[role.value])
const rolePlans = computed(() => (PLANS_BY_ROLE[role.value] ?? []).map((id) => PLANS[id]))
const unit = computed(() => UNIT_LABEL[role.value] ?? 'tickets')
const units = computed(() => Math.max(plan.value?.chivas ?? 1, 1))

// Siempre fresco al entrar: puede que administración acabe de activarlo
watch(() => auth.user?.id, (id) => { if (isSeller.value) load(id, { force: true }) }, { immediate: true })

const currentPlanId = computed(() => {
  if (!plan.value) return null
  if (plan.value.status === 'gratis') return 'promotor_gratis'
  return plan.value.status === 'activo' ? plan.value.plan : null
})

const showUsage = computed(() => plan.value && (role.value === 'negocio' || role.value === 'agencia'))

const headerText = computed(() => ({
  'dueño': 'Un precio fijo por cada chiva. Sin comisiones sobre tus ventas.',
  negocio: 'Un precio fijo al mes según cuántas entradas vendes. Sin comisiones sobre tus ventas.',
  agencia: 'Vende gratis hasta un tope al mes, o sin límite con el plan mensual.',
}[role.value] ?? ''))

const status = computed(() => {
  const p = plan.value
  if (p.reason === 'PLAN_UNITS') return {
    tone: 'warning', badge: 'Ventas detenidas',
    title: `Tu plan cubre ${p.units} ${p.units === 1 ? 'chiva' : 'chivas'} y tienes ${p.chivas}`,
    text: 'Amplía el plan a todas tus chivas para volver a vender. Mientras tanto tus tours siguen visibles, pero nadie puede comprar.',
  }
  if (p.reason === 'PLAN_LIMIT') return {
    tone: 'warning', badge: 'Límite alcanzado',
    title: `Llegaste a ${p.monthly_limit} ${unit.value} este mes`,
    text: 'Las ventas se reanudan el primer día del próximo mes, o hoy mismo si activas el plan sin límite.',
  }
  switch (p.status) {
    case 'prueba': return {
      tone: 'brand', badge: 'Prueba gratis',
      title: trialDaysLeft.value <= 1 ? 'Tu prueba gratis termina hoy' : `Te quedan ${trialDaysLeft.value} días de prueba`,
      text: `Hasta el ${formatDate(p.trial_ends_at)} vendes sin costo. Después necesitas un plan para seguir apareciendo en la web y vendiendo.`,
    }
    case 'activo': return {
      tone: 'success', badge: 'Activo',
      title: `Plan ${PLANS[p.plan]?.name ?? p.plan}`,
      text: [
        p.expires_at ? `Vigente hasta el ${formatDate(p.expires_at)}` : 'Vigente',
        p.billing === 'anual' ? 'pago anual' : 'pago mensual',
        p.plan === 'chiva' ? `cubre ${p.units} ${p.units === 1 ? 'chiva' : 'chivas'}` : null,
      ].filter(Boolean).join(' · ') + '.',
    }
    case 'gratis': return {
      tone: 'neutral', badge: 'Gratis',
      title: 'Plan Promotor',
      text: `Vendes hasta ${p.monthly_limit} ${unit.value} al mes sin costo. Si necesitas más, el plan sin límite cuesta $${PLANS.promotor.monthly} al mes.`,
    }
    case 'vencido': return {
      tone: 'warning', badge: 'Sin plan',
      title: 'Tu plan no está activo',
      text: role.value === 'dueño'
        ? 'Tus tours no aparecen en la página pública y no puedes vender, ni siquiera en efectivo. Activa tu plan para volver.'
        : 'Tu negocio no aparece en la página pública y no puedes vender entradas. Activa tu plan para volver.',
    }
    default: return { tone: 'neutral', badge: 'Sin plan', title: 'Sin plan', text: '' }
  }
})

const bank = PLATFORM_BANK
const hasBank = hasPlatformBank

const pending = ref(null)
const payCard = ref(null)

const amount = computed(() => {
  if (!pending.value) return 0
  const { plan: p, billing } = pending.value
  const base = billing === 'anual' ? p.yearly : p.monthly
  return base * (p.perUnit ? units.value : 1)
})

const payRows = computed(() => {
  if (!pending.value) return []
  const { plan: p, billing } = pending.value
  return [
    ...platformBankRows(),
    { label: 'Plan',     value: p.perUnit ? `${p.name} × ${units.value}` : p.name },
    { label: 'Periodo',  value: billing === 'anual' ? '1 año' : '1 mes' },
    { label: 'Monto',    value: `$${amount.value.toFixed(2)}` },
    { label: 'Concepto', value: `chivaspass ${p.name} - ${auth.user?.email ?? ''}` },
  ].filter(Boolean)
})

const choose = async (p, billing) => {
  pending.value = { plan: p, billing }
  await nextTick()
  payCard.value?.$el?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
}
</script>
