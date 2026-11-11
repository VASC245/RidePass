<template>
  <div>
    <PageHeader title="Planes" :description="`Estás en el plan ${planLabel(currentPlan)}. Sin contratos: cambias o cancelas cuando quieras.`" />

    <div class="space-y-8">
      <!-- Escalera de planes -->
      <ul class="overflow-hidden rounded-[var(--radius-card)] border border-gray-200 bg-white divide-y divide-gray-200" aria-label="Planes disponibles">
        <li v-for="plan in plans" :key="plan.id"
          class="grid gap-4 p-5 sm:p-6 lg:grid-cols-[14rem_minmax(0,1fr)_11rem] lg:items-center lg:gap-8"
          :class="plan.id === currentPlan && 'bg-brand-50'">
          <div>
            <div class="flex flex-wrap items-center gap-2">
              <h2 class="text-lg font-semibold text-gray-900">{{ plan.name }}</h2>
              <StatusBadge v-if="plan.id === currentPlan" tone="brand">Tu plan</StatusBadge>
              <StatusBadge v-else-if="plan.popular" tone="neutral">Recomendado</StatusBadge>
            </div>
            <p class="mt-1 flex items-baseline gap-1">
              <span class="text-3xl font-bold tracking-[-0.02em] text-gray-900 tabular-nums">${{ plan.price }}</span>
              <span class="text-sm text-gray-600">{{ plan.price > 0 ? 'al mes' : 'gratis' }}</span>
            </p>
          </div>

          <ul class="grid gap-x-6 gap-y-2 text-sm text-gray-700 sm:grid-cols-2">
            <li v-for="f in plan.features" :key="f" class="flex items-start gap-2">
              <PhCheck :size="16" weight="bold" class="mt-0.5 shrink-0 text-ok-700" />
              {{ f }}
            </li>
          </ul>

          <div class="lg:text-right">
            <p v-if="plan.id === currentPlan" class="inline-flex h-10 items-center gap-1.5 text-sm font-semibold text-brand-800">
              <PhCheckCircle :size="18" weight="fill" /> Plan activo
            </p>
            <BaseButton v-else-if="plan.price > 0"
              :variant="plan.popular && planRank(plan.id) > planRank(currentPlan) ? 'primary' : 'secondary'"
              class="w-full sm:w-auto lg:w-full" @click="selectPlan(plan)">
              Activar {{ plan.name }}
            </BaseButton>
            <p v-else class="text-sm text-gray-600">Escríbenos para bajar al plan Free.</p>
          </div>
        </li>
      </ul>

      <!-- Pago pendiente -->
      <BaseCard v-if="pendingPlan" variant="highlight" role="region" aria-labelledby="pago-plan">
        <div class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
          <div>
            <h2 id="pago-plan" class="text-lg font-semibold text-gray-900">Activar plan {{ planLabel(pendingPlan.id) }}</h2>
            <p class="mt-1 max-w-[60ch] text-sm leading-relaxed text-gray-700">
              Haz la transferencia con estos datos y envíanos el comprobante por WhatsApp al
              <strong class="font-semibold text-gray-900 tabular-nums">{{ bankInfo.whatsapp }}</strong>.
              Activamos tu plan en menos de 24 horas.
            </p>
            <BaseButton variant="ghost" size="sm" class="mt-4 -ml-3" @click="pendingPlan = null">Cancelar</BaseButton>
          </div>
          <dl class="rounded-lg border border-brand-200 bg-white p-4 text-sm">
            <div v-for="row in transferRows" :key="row.label" class="flex justify-between gap-4 py-1.5">
              <dt class="text-gray-600">{{ row.label }}</dt>
              <dd class="text-right font-semibold text-gray-900 tabular-nums break-all">{{ row.value }}</dd>
            </div>
          </dl>
        </div>
      </BaseCard>

      <!-- Comparativa -->
      <BaseCard :padded="false">
        <div class="overflow-x-auto">
          <table class="w-full min-w-[32rem] text-sm">
            <caption class="px-5 pt-5 pb-3 text-left text-base font-semibold text-gray-900 sm:px-6">Comparación de planes</caption>
            <thead class="border-y border-gray-200 bg-gray-50">
              <tr>
                <th scope="col" class="px-5 py-3 text-left font-medium text-gray-600 sm:px-6">Característica</th>
                <th v-for="p in plans" :key="p.id" scope="col" class="px-4 py-3 text-center font-semibold"
                  :class="p.id === currentPlan ? 'text-brand-800' : 'text-gray-900'">{{ p.name }}</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr v-for="row in comparison" :key="row.label">
                <th scope="row" class="px-5 py-3 text-left font-normal text-gray-700 sm:px-6">{{ row.label }}</th>
                <td v-for="p in plans" :key="p.id" class="px-4 py-3 text-center tabular-nums"
                  :class="p.id === currentPlan ? 'bg-brand-50 font-semibold text-gray-900' : 'text-gray-700'">{{ row[p.id] }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </BaseCard>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useAuthStore } from '@/stores/authStore'
import { PhCheck, PhCheckCircle } from '@phosphor-icons/vue'
import PageHeader from '@/components/ui/PageHeader.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import StatusBadge from '@/components/ui/StatusBadge.vue'

const auth = useAuthStore()
const currentPlan = computed(() => auth.user?.plan ?? 'free')
const user        = computed(() => auth.user)
const pendingPlan = ref(null)

const bankInfo = {
  bank:     import.meta.env.VITE_BANK_NAME    || 'Banco Pichincha',
  account:  import.meta.env.VITE_BANK_ACCOUNT || '2200XXXXXXXX',
  owner:    import.meta.env.VITE_BANK_OWNER   || 'Nombre del titular',
  whatsapp: '+593 99 999 9999',
}

const plans = [
  {
    id: 'free', name: 'Free', price: 0, popular: false,
    features: ['1 negocio / perfil', '3 eventos activos', '50 tickets por mes', 'QR por WhatsApp', 'Panel básico'],
  },
  {
    id: 'basico', name: 'Básico', price: 15, popular: true,
    features: ['1 negocio / perfil', 'Eventos ilimitados', '300 tickets por mes', 'Notificaciones WhatsApp', 'Panel completo', 'Soporte por WhatsApp'],
  },
  {
    id: 'pro', name: 'Pro', price: 29, popular: false,
    features: ['Negocios ilimitados', 'Eventos ilimitados', 'Tickets ilimitados', 'Todo de Básico', 'Analytics avanzado', 'Soporte prioritario'],
  },
]

const comparison = [
  { label: 'Tickets/mes',      free: '50',       basico: '300',        pro: 'Ilimitado'  },
  { label: 'Eventos activos',  free: '3',         basico: 'Ilimitado', pro: 'Ilimitado'  },
  { label: 'Negocios/chivas',  free: '1',         basico: '1',          pro: 'Ilimitado'  },
  { label: 'WhatsApp al dueño',free: 'Sí',         basico: 'Sí',          pro: 'Sí'          },
  { label: 'Portal del cliente',free: 'Sí',        basico: 'Sí',          pro: 'Sí'          },
  { label: 'Notif. automáticas',free: 'No',        basico: 'Sí',          pro: 'Sí'          },
  { label: 'Analytics',        free: 'Básico',    basico: 'Estándar',   pro: 'Avanzado'   },
  { label: 'Soporte',          free: 'Email',     basico: 'WhatsApp',   pro: 'Prioritario'},
]

const planRank = (id) => ({ free: 0, basico: 1, pro: 2 }[id] ?? 0)

const transferRows = computed(() => pendingPlan.value ? [
  { label: 'Banco',    value: bankInfo.bank },
  { label: 'Cuenta',   value: bankInfo.account },
  { label: 'Titular',  value: bankInfo.owner },
  { label: 'Monto',    value: `$${pendingPlan.value.price} al mes` },
  { label: 'Concepto', value: `chivaspass ${pendingPlan.value.name} - ${user.value?.email ?? ''}` },
] : [])

const planLabel = (id) => ({ free: 'Free', basico: 'Básico', pro: 'Pro' }[id] ?? id)
const selectPlan = (plan) => { if (plan.price > 0) pendingPlan.value = plan }
</script>
