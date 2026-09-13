<template>
  <div class="max-w-4xl mx-auto space-y-8">
    <div class="text-center">
      <h2 class="text-3xl font-extrabold text-gray-900">Elige tu plan</h2>
      <p class="text-gray-400 mt-2">Sin contratos. Cancela cuando quieras.</p>
    </div>

    <!-- Badge plan actual -->
    <div class="flex justify-center">
      <span class="bg-orange-100 text-orange-700 font-bold text-sm px-4 py-2 rounded-full">
        Plan actual: {{ planLabel(currentPlan) }}
      </span>
    </div>

    <!-- Cards -->
    <div class="grid sm:grid-cols-3 gap-6">
      <div v-for="plan in plans" :key="plan.id"
        class="bg-white rounded-2xl border-2 shadow-sm p-6 flex flex-col relative"
        :class="plan.id === 'basico' ? 'border-orange-400 shadow-orange-100' : 'border-gray-100'">

        <!-- Popular badge -->
        <div v-if="plan.popular"
          class="absolute -top-3 left-1/2 -translate-x-1/2 bg-orange-600 text-white text-xs font-bold px-4 py-1 rounded-full">
          Más popular
        </div>

        <div class="mb-4">
          <p class="text-lg font-extrabold text-gray-900">{{ plan.name }}</p>
          <div class="mt-2 flex items-end gap-1">
            <span class="text-4xl font-extrabold text-gray-900">${{ plan.price }}</span>
            <span v-if="plan.price > 0" class="text-gray-400 text-sm mb-1">/mes</span>
            <span v-else class="text-gray-400 text-sm mb-1">gratis</span>
          </div>
        </div>

        <ul class="space-y-2.5 flex-1 mb-6">
          <li v-for="f in plan.features" :key="f" class="flex items-start gap-2 text-sm text-gray-600">
            <PhCheck :size="16" weight="bold" class="text-green-600 mt-0.5 shrink-0" />
            {{ f }}
          </li>
        </ul>

        <button
          v-if="plan.id !== currentPlan"
          @click="selectPlan(plan)"
          class="w-full py-2.5 rounded-xl font-bold text-sm transition"
          :class="plan.id === 'basico'
            ? 'bg-orange-600 hover:bg-orange-700 text-white'
            : 'border border-gray-300 hover:border-orange-400 text-gray-700'"
        >
          {{ plan.price === 0 ? 'Volver al Free' : `Activar ${plan.name}` }}
        </button>
        <div v-else
          class="w-full py-2.5 rounded-xl font-bold text-sm text-center bg-green-50 text-green-700 border border-green-200">Plan actual</div>
      </div>
    </div>

    <!-- Pago pendiente -->
    <div v-if="pendingPlan" class="bg-blue-50 border border-blue-200 rounded-2xl p-6 text-center space-y-3">
      <p class="font-bold text-blue-800 text-lg">Activar Plan {{ planLabel(pendingPlan.id) }}</p>
      <p class="text-blue-600 text-sm">Realiza la transferencia y envíanos el comprobante para activar tu plan.</p>
      <div class="bg-white rounded-xl p-4 text-sm text-left space-y-1 max-w-sm mx-auto border border-blue-100">
        <p>Banco: <strong>{{ bankInfo.bank }}</strong></p>
        <p>Cuenta: <strong>{{ bankInfo.account }}</strong></p>
        <p>Titular: <strong>{{ bankInfo.owner }}</strong></p>
        <p>Monto: <strong class="text-orange-700">${{ pendingPlan.price }}/mes</strong></p>
        <p>Concepto: <strong>ChivaPass {{ pendingPlan.name }} - {{ user?.email }}</strong></p>
      </div>
      <p class="text-xs text-blue-500">Una vez verificado activaremos tu plan en menos de 24h. <br>WhatsApp: <strong>{{ bankInfo.whatsapp }}</strong></p>
      <button @click="pendingPlan = null" class="text-sm text-gray-400 hover:underline">Cancelar</button>
    </div>

    <!-- Comparativa -->
    <div class="bg-white rounded-2xl border shadow-sm overflow-hidden">
      <table class="w-full text-sm">
        <thead class="bg-gray-50 border-b">
          <tr>
            <th class="text-left px-5 py-3 font-semibold text-gray-600">Característica</th>
            <th class="text-center px-4 py-3 font-semibold text-gray-600">Free</th>
            <th class="text-center px-4 py-3 font-semibold text-orange-600">Básico</th>
            <th class="text-center px-4 py-3 font-semibold text-gray-900">Pro</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-50">
          <tr v-for="row in comparison" :key="row.label">
            <td class="px-5 py-3 text-gray-700">{{ row.label }}</td>
            <td class="px-4 py-3 text-center">{{ row.free }}</td>
            <td class="px-4 py-3 text-center font-semibold text-orange-700">{{ row.basico }}</td>
            <td class="px-4 py-3 text-center font-semibold text-gray-900">{{ row.pro }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { useAuthStore } from '@/stores/authStore'
import { PhCheck } from '@phosphor-icons/vue'

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
  { label: 'Notif. automáticas',free: '–',        basico: 'Sí',          pro: 'Sí'          },
  { label: 'Analytics',        free: 'Básico',    basico: 'Estándar',   pro: 'Avanzado'   },
  { label: 'Soporte',          free: 'Email',     basico: 'WhatsApp',   pro: 'Prioritario'},
]

const planLabel = (id) => ({ free: 'Free', basico: 'Básico', pro: 'Pro' }[id] ?? id)
const selectPlan = (plan) => { if (plan.price > 0) pendingPlan.value = plan }
</script>
