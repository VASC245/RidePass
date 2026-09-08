<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <h2 class="text-2xl font-bold text-gray-800">Configuración</h2>

    <!-- Controles de venta -->
    <div v-if="isSeller" class="bg-white rounded-2xl shadow-sm border p-6 space-y-5">
      <div>
        <h3 class="font-bold text-gray-800">Controles de venta</h3>
        <p class="text-sm text-gray-400 mt-1">
          Lo que apagues aquí deja de funcionar de inmediato para todos: página pública, agencias y pagos.
        </p>
      </div>

      <div class="divide-y divide-gray-100">
        <ToggleRow v-model="form.public_listing"
          label="Aparecer en la página pública"
          hint="Si lo apagas, tus tours y salidas desaparecen del sitio pero sigues pudiendo vender desde tu panel." />
        <ToggleRow v-model="form.accept_transfers"
          label="Aceptar transferencias bancarias"
          hint="Los clientes suben el comprobante y tú lo verificas." />
        <ToggleRow v-model="form.accept_cards"
          label="Aceptar tarjeta"
          hint="Requiere tener Kushki configurado. El cobro se confirma al instante." />
        <ToggleRow v-if="isOwner" v-model="form.accept_cash"
          label="Venta en efectivo desde mi panel"
          hint="Registrar ventas en persona sin comprobante." />
      </div>

      <div class="pt-2 space-y-4">
        <ToggleRow v-model="form.enforce_hours"
          label="Solo recibir reservas en mi horario de atención"
          hint="Fuera de ese horario el cliente ve un aviso y no puede reservar." />
        <div class="grid sm:grid-cols-3 gap-4" :class="!form.enforce_hours && 'opacity-50'">
          <div>
            <label class="field-label">Abre</label>
            <input v-model="form.hours_open" type="time" :disabled="!form.enforce_hours" class="field-input" />
          </div>
          <div>
            <label class="field-label">Cierra</label>
            <input v-model="form.hours_close" type="time" :disabled="!form.enforce_hours" class="field-input" />
          </div>
          <div v-if="isOwner">
            <label class="field-label">Cerrar ventas antes de salir</label>
            <select v-model.number="form.close_sales_minutes_before" class="field-input bg-white">
              <option :value="0">No cerrar</option>
              <option :value="15">15 minutos antes</option>
              <option :value="30">30 minutos antes</option>
              <option :value="60">1 hora antes</option>
              <option :value="120">2 horas antes</option>
            </select>
          </div>
        </div>
        <div>
          <label class="field-label">Nota de horario para el cliente</label>
          <input v-model="form.hours_note" type="text" maxlength="140"
            placeholder="Ej: Atendemos de lunes a domingo, feriados hasta las 21h" class="field-input" />
        </div>
      </div>
    </div>

    <!-- Datos de pago -->
    <div class="bg-white rounded-2xl shadow-sm border p-6 space-y-4">
      <h3 class="font-bold text-gray-800">Datos para transferencia</h3>
      <p class="text-sm text-gray-400 -mt-2">Se muestran a tus clientes cuando pagan por transferencia.</p>

      <div class="grid sm:grid-cols-2 gap-4">
        <div>
          <label class="field-label">Banco</label>
          <input v-model="form.bank_name" type="text" placeholder="Ej: Banco Pichincha" class="field-input" />
        </div>
        <div>
          <label class="field-label">Tipo de cuenta</label>
          <select v-model="form.bank_type" class="field-input bg-white">
            <option value="ahorros">Ahorros</option>
            <option value="corriente">Corriente</option>
          </select>
        </div>
        <div>
          <label class="field-label">Número de cuenta</label>
          <input v-model="form.bank_account" type="text" placeholder="Ej: 2200123456" class="field-input" />
        </div>
        <div>
          <label class="field-label">Titular de la cuenta</label>
          <input v-model="form.bank_owner" type="text" placeholder="Nombre completo" class="field-input" />
        </div>
      </div>
    </div>

    <!-- Contacto -->
    <div class="bg-white rounded-2xl shadow-sm border p-6 space-y-4">
      <h3 class="font-bold text-gray-800">Datos de contacto</h3>
      <p class="text-sm text-gray-400 -mt-2">El WhatsApp recibe un aviso por cada venta o reserva nueva.</p>

      <div class="grid sm:grid-cols-2 gap-4">
        <div>
          <label class="field-label">Teléfono</label>
          <input v-model="form.contact_phone" type="tel" placeholder="+593 99 999 9999" class="field-input" />
        </div>
        <div>
          <label class="field-label">WhatsApp</label>
          <input v-model="form.contact_whatsapp" type="tel" placeholder="+593 99 999 9999" class="field-input" />
        </div>
        <div class="sm:col-span-2">
          <label class="field-label">Correo de contacto</label>
          <input v-model="form.contact_email" type="email" placeholder="contacto@tunegocio.com" class="field-input" />
        </div>
      </div>
    </div>

    <!-- Redes sociales -->
    <div class="bg-white rounded-2xl shadow-sm border p-6 space-y-4">
      <h3 class="font-bold text-gray-800">Redes sociales</h3>

      <div class="grid sm:grid-cols-2 gap-4">
        <div>
          <label class="field-label">Instagram</label>
          <div class="flex items-center border border-gray-300 rounded-xl overflow-hidden shadow-sm">
            <span class="px-3 text-gray-400 text-sm bg-gray-50 border-r border-gray-300 py-2.5">@</span>
            <input v-model="form.instagram" type="text" placeholder="tunegocio" class="flex-1 px-3 py-2.5 text-sm outline-none" />
          </div>
        </div>
        <div>
          <label class="field-label">Facebook</label>
          <div class="flex items-center border border-gray-300 rounded-xl overflow-hidden shadow-sm">
            <span class="px-3 text-gray-400 text-sm bg-gray-50 border-r border-gray-300 py-2.5">fb/</span>
            <input v-model="form.facebook" type="text" placeholder="tunegocio" class="flex-1 px-3 py-2.5 text-sm outline-none" />
          </div>
        </div>
      </div>
    </div>

    <!-- Identidad -->
    <div class="bg-white rounded-2xl shadow-sm border p-6 space-y-4">
      <h3 class="font-bold text-gray-800">Identidad del negocio</h3>

      <div class="grid sm:grid-cols-2 gap-4">
        <div class="sm:col-span-2">
          <label class="field-label">Nombre visible del negocio</label>
          <input v-model="form.business_name" type="text" placeholder="Ej: Tours Chiva Express Baños" class="field-input" />
        </div>
        <div class="sm:col-span-2">
          <label class="field-label">URL del logo</label>
          <input v-model="form.logo_url" type="url" placeholder="https://..." class="field-input" />
        </div>
        <div class="sm:col-span-2">
          <label class="field-label">Notas para el cliente (aparecen en el checkout)</label>
          <textarea v-model="form.notes" rows="2" placeholder="Ej: Punto de encuentro en la plaza central a las 8:45am" class="field-input resize-none"></textarea>
        </div>
      </div>
    </div>

    <!-- Feedback -->
    <transition name="fade">
      <div v-if="saved" class="bg-green-50 border border-green-200 text-green-700 rounded-xl px-4 py-3 text-sm font-semibold">
        Configuración guardada.
      </div>
    </transition>
    <div v-if="error" class="bg-red-50 border border-red-200 text-red-600 rounded-xl px-4 py-3 text-sm">{{ error }}</div>

    <button
      @click="save"
      :disabled="saving"
      class="w-full py-3 rounded-xl font-bold text-white bg-gray-900 hover:bg-gray-800 transition-all active:scale-[0.99] disabled:opacity-50"
    >
      {{ saving ? 'Guardando...' : 'Guardar configuración' }}
    </button>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, defineComponent, h } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'

// Interruptor simple reutilizable dentro de este panel
const ToggleRow = defineComponent({
  props: { modelValue: Boolean, label: String, hint: String },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    return () => h('label', { class: 'flex items-start justify-between gap-4 py-3 cursor-pointer select-none' }, [
      h('span', { class: 'min-w-0' }, [
        h('span', { class: 'block text-sm font-semibold text-gray-800' }, props.label),
        props.hint ? h('span', { class: 'block text-xs text-gray-400 mt-0.5' }, props.hint) : null,
      ]),
      h('button', {
        type: 'button',
        role: 'switch',
        'aria-checked': props.modelValue,
        onClick: () => emit('update:modelValue', !props.modelValue),
        class: [
          'relative shrink-0 w-11 h-6 rounded-full transition-colors',
          props.modelValue ? 'bg-orange-600' : 'bg-gray-300',
        ],
      }, [
        h('span', {
          class: [
            'absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform',
            props.modelValue ? 'translate-x-5' : '',
          ],
        }),
      ]),
    ])
  },
})

const authStore = useAuthStore()
const saving = ref(false)
const saved  = ref(false)
const error  = ref('')
const exists = ref(false)

const isOwner  = computed(() => authStore.user?.role === 'dueño')
const isSeller = computed(() => ['dueño', 'negocio'].includes(authStore.user?.role))

const defaults = () => ({
  bank_name: '', bank_account: '', bank_owner: '', bank_type: 'ahorros',
  contact_phone: '', contact_whatsapp: '', contact_email: '',
  instagram: '', facebook: '',
  logo_url: '', business_name: '', notes: '',
  // controles de venta
  public_listing: true, accept_transfers: true, accept_cards: true, accept_cash: true,
  enforce_hours: false, hours_open: '07:00', hours_close: '19:00', hours_note: '',
  close_sales_minutes_before: 0,
})

const form = ref(defaults())

const FIELDS = Object.keys(defaults())

onMounted(async () => {
  const uid = authStore.user?.id
  const { data } = await supabase.from('panel_settings').select('*').eq('user_id', uid).maybeSingle()
  if (data) {
    exists.value = true
    const next = defaults()
    for (const k of FIELDS) if (data[k] !== null && data[k] !== undefined) next[k] = data[k]
    // Postgres devuelve "07:00:00"; el input type=time quiere "07:00"
    next.hours_open  = String(next.hours_open).slice(0, 5)
    next.hours_close = String(next.hours_close).slice(0, 5)
    form.value = next
  }
})

const save = async () => {
  saving.value = true
  error.value  = ''
  saved.value  = false

  const payload = { ...form.value, user_id: authStore.user?.id, updated_at: new Date().toISOString() }

  const res = exists.value
    ? await supabase.from('panel_settings').update(payload).eq('user_id', authStore.user?.id)
    : await supabase.from('panel_settings').insert(payload)

  if (res.error) {
    error.value = res.error.message
  } else {
    exists.value = true
    saved.value  = true
    setTimeout(() => (saved.value = false), 3000)
  }
  saving.value = false
}
</script>

<style scoped>
.field-input {
  width: 100%;
  padding: 0.625rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.75rem;
  box-shadow: 0 1px 2px 0 rgb(0 0 0/0.05);
  font-size: 0.875rem;
  outline: none;
}
.field-input:focus { box-shadow: 0 0 0 2px #ea580c; }
.field-input:disabled { background: #f9fafb; }
.field-label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.375rem;
}
.fade-enter-active, .fade-leave-active { transition: opacity .3s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
