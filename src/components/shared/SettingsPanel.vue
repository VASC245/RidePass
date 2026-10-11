<template>
  <div class="pb-24">
    <PageHeader title="Configuración" description="Cómo vendes, cómo te pagan y cómo te ven tus clientes." />

    <div class="space-y-8">
      <!-- Controles de venta -->
      <section v-if="isSeller" class="settings-section" aria-labelledby="s-venta">
        <div>
          <h2 id="s-venta" class="settings-title">Controles de venta</h2>
          <p class="settings-desc">Lo que apagues aquí deja de funcionar de inmediato para todos: página pública, agencias y pagos.</p>
        </div>
        <BaseCard>
          <div class="-my-3 divide-y divide-gray-200">
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
        </BaseCard>
      </section>

      <!-- Horario -->
      <section v-if="isSeller" class="settings-section" aria-labelledby="s-horario">
        <div>
          <h2 id="s-horario" class="settings-title">Horario de atención</h2>
          <p class="settings-desc">Controla cuándo pueden reservar tus clientes desde la página pública.</p>
        </div>
        <BaseCard>
          <div class="-mt-3">
            <ToggleRow v-model="form.enforce_hours"
              label="Solo recibir reservas en mi horario de atención"
              hint="Fuera de ese horario el cliente ve un aviso y no puede reservar." />
          </div>
          <div class="mt-3 grid gap-4 sm:grid-cols-3" :class="!form.enforce_hours && 'opacity-60'">
            <div>
              <label for="cfg-open" class="field-label">Abre</label>
              <input id="cfg-open" v-model="form.hours_open" type="time" :disabled="!form.enforce_hours" class="field-control tabular-nums" />
            </div>
            <div>
              <label for="cfg-close" class="field-label">Cierra</label>
              <input id="cfg-close" v-model="form.hours_close" type="time" :disabled="!form.enforce_hours" class="field-control tabular-nums" />
            </div>
            <div v-if="isOwner">
              <label for="cfg-cutoff" class="field-label">Cerrar ventas antes de salir</label>
              <select id="cfg-cutoff" v-model.number="form.close_sales_minutes_before" class="field-control">
                <option :value="0">No cerrar</option>
                <option :value="15">15 minutos antes</option>
                <option :value="30">30 minutos antes</option>
                <option :value="60">1 hora antes</option>
                <option :value="120">2 horas antes</option>
              </select>
            </div>
          </div>
          <div class="mt-4">
            <label for="cfg-note" class="field-label">Nota de horario para el cliente</label>
            <input id="cfg-note" v-model="form.hours_note" type="text" maxlength="140"
              placeholder="Ej: Atendemos de lunes a domingo, feriados hasta las 21h" class="field-control" />
            <p class="field-hint tabular-nums">{{ (form.hours_note || '').length }} de 140 caracteres</p>
          </div>
        </BaseCard>
      </section>

      <!-- Datos de pago -->
      <section class="settings-section" aria-labelledby="s-pago">
        <div>
          <h2 id="s-pago" class="settings-title">Datos para transferencia</h2>
          <p class="settings-desc">Se muestran a tus clientes cuando pagan por transferencia.</p>
        </div>
        <BaseCard>
          <div class="grid gap-4 sm:grid-cols-2">
            <div>
              <label for="cfg-bank" class="field-label">Banco</label>
              <input id="cfg-bank" v-model="form.bank_name" type="text" placeholder="Ej: Banco Pichincha" class="field-control" />
            </div>
            <div>
              <label for="cfg-bank-type" class="field-label">Tipo de cuenta</label>
              <select id="cfg-bank-type" v-model="form.bank_type" class="field-control">
                <option value="ahorros">Ahorros</option>
                <option value="corriente">Corriente</option>
              </select>
            </div>
            <div>
              <label for="cfg-account" class="field-label">Número de cuenta</label>
              <input id="cfg-account" v-model="form.bank_account" type="text" inputmode="numeric" placeholder="Ej: 2200123456" class="field-control tabular-nums" />
            </div>
            <div>
              <label for="cfg-holder" class="field-label">Titular de la cuenta</label>
              <input id="cfg-holder" v-model="form.bank_owner" type="text" placeholder="Nombre completo" class="field-control" />
            </div>
          </div>
        </BaseCard>
      </section>

      <!-- Contacto -->
      <section class="settings-section" aria-labelledby="s-contacto">
        <div>
          <h2 id="s-contacto" class="settings-title">Contacto</h2>
          <p class="settings-desc">El WhatsApp recibe un aviso por cada venta o reserva nueva.</p>
        </div>
        <BaseCard>
          <div class="grid gap-4 sm:grid-cols-2">
            <div>
              <label for="cfg-phone" class="field-label">Celular</label>
              <input id="cfg-phone" v-model="form.contact_phone" type="tel" placeholder="+593 99 999 9999" class="field-control tabular-nums" aria-describedby="cfg-phone-hint" />
              <p id="cfg-phone-hint" class="field-hint">Aquí te llega un SMS con cada venta o reserva.</p>
            </div>
            <div>
              <label for="cfg-wa" class="field-label">WhatsApp</label>
              <input id="cfg-wa" v-model="form.contact_whatsapp" type="tel" placeholder="+593 99 999 9999" class="field-control tabular-nums" />
            </div>
            <div class="sm:col-span-2">
              <label for="cfg-email" class="field-label">Correo de contacto</label>
              <input id="cfg-email" v-model="form.contact_email" type="email" placeholder="contacto@tunegocio.com" class="field-control" />
            </div>
            <div>
              <label for="cfg-ig" class="field-label">Instagram</label>
              <div class="input-affix">
                <span class="input-affix__prefix" aria-hidden="true">@</span>
                <input id="cfg-ig" v-model="form.instagram" type="text" placeholder="tunegocio" class="input-affix__input" />
              </div>
            </div>
            <div>
              <label for="cfg-fb" class="field-label">Facebook</label>
              <div class="input-affix">
                <span class="input-affix__prefix" aria-hidden="true">facebook.com/</span>
                <input id="cfg-fb" v-model="form.facebook" type="text" placeholder="tunegocio" class="input-affix__input" />
              </div>
            </div>
          </div>
        </BaseCard>
      </section>

      <!-- Identidad -->
      <section class="settings-section" aria-labelledby="s-identidad">
        <div>
          <h2 id="s-identidad" class="settings-title">Identidad del negocio</h2>
          <p class="settings-desc">Cómo te presentas en la página pública y en el checkout.</p>
        </div>
        <BaseCard>
          <div class="space-y-4">
            <div>
              <label for="cfg-name" class="field-label">Nombre visible del negocio</label>
              <input id="cfg-name" v-model="form.business_name" type="text" placeholder="Ej: Tours Chiva Express Baños" class="field-control" />
            </div>
            <div>
              <label for="cfg-logo" class="field-label">URL del logo</label>
              <input id="cfg-logo" v-model="form.logo_url" type="url" placeholder="https://..." class="field-control" />
            </div>
            <div>
              <label for="cfg-notes" class="field-label">Notas para el cliente</label>
              <textarea id="cfg-notes" v-model="form.notes" rows="3" placeholder="Ej: Punto de encuentro en la plaza central a las 8:45" class="field-control"></textarea>
              <p class="field-hint">Aparecen en el checkout, antes de pagar.</p>
            </div>
          </div>
        </BaseCard>
      </section>
    </div>

    <!-- Barra de guardado -->
    <div class="fixed inset-x-0 bottom-0 z-20 border-t border-gray-200 bg-white md:left-64"
      style="padding-bottom: env(safe-area-inset-bottom)">
      <div class="mx-auto flex max-w-6xl flex-col gap-2 px-4 py-3 sm:flex-row sm:items-center sm:justify-end sm:gap-4 sm:px-6 lg:px-10">
        <p class="text-sm sm:mr-auto" aria-live="polite">
          <span v-if="error" class="inline-flex items-center gap-1.5 text-bad-700"><PhWarningCircle :size="18" />{{ error }}</span>
          <Transition name="fade">
            <span v-if="saved && !error" class="inline-flex items-center gap-1.5 font-medium text-ok-700"><PhCheckCircle :size="18" />Configuración guardada</span>
          </Transition>
        </p>
        <BaseButton size="lg" :loading="saving" class="sm:min-w-52" @click="save">
          {{ saving ? 'Guardando...' : 'Guardar configuración' }}
        </BaseButton>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, defineComponent, h } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'
import PageHeader from '@/components/ui/PageHeader.vue'
import BaseCard from '@/components/ui/BaseCard.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { PhCheckCircle, PhWarningCircle } from '@phosphor-icons/vue'

// Interruptor simple reutilizable dentro de este panel
const ToggleRow = defineComponent({
  props: { modelValue: Boolean, label: String, hint: String },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    return () => h('label', { class: 'flex items-start justify-between gap-4 py-3.5 cursor-pointer select-none' }, [
      h('span', { class: 'min-w-0' }, [
        h('span', { class: 'block text-sm font-semibold text-gray-900' }, props.label),
        props.hint ? h('span', { class: 'block text-sm text-gray-600 mt-0.5 leading-snug' }, props.hint) : null,
      ]),
      h('button', {
        type: 'button',
        role: 'switch',
        'aria-checked': props.modelValue,
        onClick: () => emit('update:modelValue', !props.modelValue),
        class: [
          'relative shrink-0 mt-0.5 w-11 h-6 rounded-full transition-colors duration-150',
          props.modelValue ? 'bg-brand-600' : 'bg-gray-300',
        ],
      }, [
        h('span', {
          class: [
            'absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow-sm transition-transform duration-200 ease-out',
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
.settings-section {
  display: grid;
  gap: 0.75rem 2rem;
}
@media (min-width: 1024px) {
  .settings-section { grid-template-columns: 15rem minmax(0, 1fr); }
}
.settings-title { font-size: 1rem; font-weight: 600; color: var(--color-gray-900); }
.settings-desc { margin-top: 0.25rem; font-size: 0.875rem; line-height: 1.5; color: var(--color-gray-600); }

.input-affix {
  display: flex;
  align-items: stretch;
  min-height: 2.75rem;
  border: 1px solid var(--color-gray-300);
  border-radius: 8px;
  background: #fff;
  overflow: hidden;
  transition: border-color 150ms ease-out, box-shadow 150ms ease-out;
}
.input-affix:hover { border-color: var(--color-gray-400); }
.input-affix:focus-within {
  border-color: var(--color-brand-600);
  box-shadow: 0 0 0 3px color-mix(in oklch, var(--color-brand-500) 22%, transparent);
}
.input-affix__prefix {
  display: flex;
  align-items: center;
  padding: 0 0.75rem;
  border-right: 1px solid var(--color-gray-200);
  background: var(--color-gray-50);
  font-size: 0.875rem;
  color: var(--color-gray-600);
}
.input-affix__input {
  flex: 1;
  min-width: 0;
  padding: 0.625rem 0.875rem;
  font-size: 0.9375rem;
  color: var(--color-gray-900);
  outline: none;
}
.input-affix__input::placeholder { color: var(--color-gray-500); }

.fade-enter-active, .fade-leave-active { transition: opacity 200ms ease-out; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
