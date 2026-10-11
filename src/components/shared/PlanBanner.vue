<template>
  <div v-if="notice"
    class="mb-6 flex flex-col print:hidden items-start justify-between gap-4 rounded-[var(--radius-card)] border p-4 sm:flex-row sm:items-center sm:p-5"
    :class="notice.tone === 'warn' ? 'bg-warn-50 border-warn-200' : 'bg-brand-50 border-brand-200'"
    role="status"
  >
    <div class="flex items-start gap-3">
      <component :is="notice.tone === 'warn' ? PhWarningCircle : PhInfo" :size="22" class="mt-0.5 shrink-0"
        :class="notice.tone === 'warn' ? 'text-warn-700' : 'text-brand-700'" />
      <div>
        <p class="font-semibold text-gray-900">{{ notice.title }}</p>
        <p class="mt-0.5 text-sm text-gray-700">{{ notice.text }}</p>
      </div>
    </div>
    <RouterLink to="/panel/planes"
      class="inline-flex h-10 shrink-0 items-center rounded-lg px-4 text-sm font-semibold text-white transition-colors"
      :class="notice.tone === 'warn' ? 'bg-gray-900 hover:bg-gray-800' : 'bg-brand-600 hover:bg-brand-700'"
    >
      {{ notice.cta }}
    </RouterLink>
  </div>
</template>

<script setup>
import { computed, watch } from 'vue'
import { useRoute } from 'vue-router'
import { PhWarningCircle, PhInfo } from '@phosphor-icons/vue'
import { useAuthStore } from '@/stores/authStore'
import { usePlan } from '@/composables/usePlan'
import { PLANS_BY_ROLE, UNIT_LABEL, formatDate } from '@/lib/plans'

const auth = useAuthStore()
const route = useRoute()
const { plan, load, trialDaysLeft, paidDaysLeft, usagePct } = usePlan()

const isSeller = computed(() => !!PLANS_BY_ROLE[auth.user?.role])

watch(() => auth.user?.id, (id) => { if (isSeller.value) load(id) }, { immediate: true })

const OFFER = { 'dueño': 'Tus tours', negocio: 'Tu negocio' }

const notice = computed(() => {
  const p = plan.value
  if (!p || !isSeller.value || route.path === '/panel/planes') return null
  const unit = UNIT_LABEL[p.role] ?? 'tickets'

  if (p.status === 'vencido') {
    return {
      tone: 'warn', cta: 'Activar plan',
      title: 'Tu plan no está activo',
      text: `${OFFER[p.role] ?? 'Tu oferta'} no aparece en la página pública y no puedes vender hasta que actives un plan.`,
    }
  }
  if (p.reason === 'PLAN_UNITS') {
    return {
      tone: 'warn', cta: 'Ampliar plan',
      title: `Tu plan cubre ${p.units} ${p.units === 1 ? 'chiva' : 'chivas'} y tienes ${p.chivas}`,
      text: 'Las ventas están detenidas hasta que amplíes el plan o retires las chivas que sobran.',
    }
  }
  if (p.reason === 'PLAN_LIMIT') {
    return {
      tone: 'warn', cta: 'Ver planes',
      title: `Llegaste a ${p.monthly_limit} ${unit} este mes`,
      text: 'Tu plan no admite más ventas hasta el próximo mes. Con el plan sin límite sigues vendiendo hoy.',
    }
  }
  if (p.monthly_limit && usagePct.value >= 0.8) {
    return {
      tone: 'info', cta: 'Ver planes',
      title: `Llevas ${p.used_this_month} de ${p.monthly_limit} ${unit} este mes`,
      text: 'Cuando llegues al límite, las ventas se detienen hasta el mes siguiente.',
    }
  }
  if (p.status === 'prueba' && trialDaysLeft.value <= 7) {
    return {
      tone: 'info', cta: 'Elegir plan',
      title: trialDaysLeft.value <= 1 ? 'Tu prueba gratis termina hoy' : `Tu prueba gratis termina en ${trialDaysLeft.value} días`,
      text: `Activa tu plan antes del ${formatDate(p.trial_ends_at)} para seguir vendiendo sin cortes.`,
    }
  }
  if (p.status === 'activo' && p.expires_at && paidDaysLeft.value <= 5) {
    return {
      tone: 'info', cta: 'Renovar plan',
      title: `Tu plan vence el ${formatDate(p.expires_at)}`,
      text: 'Renuévalo antes de esa fecha para que tus ventas no se detengan.',
    }
  }
  return null
})
</script>
