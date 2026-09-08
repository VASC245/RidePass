<template>
  <Transition name="modal">
    <div v-if="tour"
      class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm p-0 sm:p-4"
      @click.self="$emit('close')">

      <div class="bg-white w-full sm:max-w-2xl rounded-t-2xl sm:rounded-2xl max-h-[93vh] overflow-y-auto shadow-2xl">

        <!-- cabecera -->
        <div class="sticky top-0 bg-white z-10 px-6 pt-5 pb-4 border-b border-gray-100">
          <div class="flex items-center justify-between mb-4 gap-4">
            <div class="min-w-0">
              <h2 class="font-bold text-gray-900 text-lg leading-tight truncate">{{ tour.title }}</h2>
              <p class="text-sm text-gray-500 mt-0.5">{{ formatHour(tour.departure_at) }} · ${{ tour.base_price }} por persona</p>
            </div>
            <button @click="$emit('close')"
              class="w-9 h-9 shrink-0 flex items-center justify-center rounded-full bg-gray-100 hover:bg-gray-200 text-gray-600 transition-colors"
              aria-label="Cerrar">
              <PhX :size="16" weight="bold" />
            </button>
          </div>

          <div v-if="step < 4" class="flex items-center gap-2">
            <template v-for="s in 3" :key="s">
              <div :class="step >= s ? 'bg-orange-600 text-white' : 'bg-gray-100 text-gray-400'"
                class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 transition-all">
                <PhCheck v-if="step > s" :size="13" weight="bold" />
                <span v-else>{{ s }}</span>
              </div>
              <div v-if="s < 3" :class="step > s ? 'bg-orange-600' : 'bg-gray-200'"
                class="flex-1 h-1 rounded-full transition-all"></div>
            </template>
            <span class="ml-2 text-xs text-gray-500 font-medium flex-shrink-0">{{ stepLabels[step - 1] }}</span>
          </div>
        </div>

        <div class="px-6 pb-8 pt-5">

          <!-- PASO 1: Asientos -->
          <div v-if="step === 1">
            <p class="text-sm text-gray-500 mb-5">Selecciona uno o más asientos disponibles</p>
            <SeatGrid :assignedChivaId="tour.id" @selectSeats="onSelectSeats" />

            <div v-if="selectedSeats.length > 0"
              class="mt-6 bg-orange-50 border border-orange-200 rounded-2xl p-4 flex items-center justify-between gap-4">
              <div>
                <p class="text-sm text-gray-600">{{ selectedSeats.length }} asiento(s) seleccionado(s)</p>
                <p class="text-2xl font-extrabold text-gray-900">${{ subtotal }}</p>
              </div>
              <button @click="step = 2"
                class="bg-orange-600 hover:bg-orange-700 text-white font-bold px-6 py-3 rounded-[10px] transition-all active:scale-95">
                Continuar
              </button>
            </div>
          </div>

          <!-- PASO 2: Datos -->
          <div v-if="step === 2" class="space-y-4">
            <p class="text-sm text-gray-500 mb-2">Completa tus datos para el ticket</p>

            <div class="grid sm:grid-cols-2 gap-4">
              <div>
                <label class="field-label">Nombre completo *</label>
                <input v-model="form.name" placeholder="Nombre y apellido" class="field-input" />
              </div>
              <div>
                <label class="field-label">Cédula / Pasaporte *</label>
                <input v-model="form.cedula" placeholder="0912345678" class="field-input" />
              </div>
              <div>
                <label class="field-label">Teléfono / WhatsApp *</label>
                <input v-model="form.phone" placeholder="+593 99 999 9999" class="field-input" />
              </div>
              <div>
                <label class="field-label">Correo electrónico *</label>
                <input v-model="form.email" type="email" placeholder="tu@correo.com" class="field-input" />
              </div>
              <div class="sm:col-span-2">
                <label class="field-label">Dirección *</label>
                <input v-model="form.address" placeholder="Ciudad, barrio" class="field-input" />
              </div>
            </div>

            <div class="bg-gray-50 rounded-xl p-4 text-sm text-gray-600 space-y-1 mt-2">
              <div class="flex justify-between"><span>Tour</span><strong class="text-gray-900">{{ tour.title }}</strong></div>
              <div class="flex justify-between"><span>Asientos</span><strong class="text-gray-900">{{ selectedSeats.join(', ') }}</strong></div>
              <div class="flex justify-between pt-2 border-t border-gray-200 mt-2">
                <span class="font-bold text-gray-900">Total</span>
                <strong class="text-orange-700 text-base">${{ subtotal }}</strong>
              </div>
            </div>

            <p v-if="formError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ formError }}</p>

            <div class="flex gap-3 pt-2">
              <button @click="step = 1" class="btn-secondary flex-1">Volver</button>
              <button @click="validateFormAndNext" class="btn-primary flex-[2]">Ir al pago</button>
            </div>
          </div>

          <!-- PASO 3: Pago -->
          <div v-if="step === 3" class="space-y-5">
            <div v-if="!salesOpenNow" class="bg-amber-50 border border-amber-200 rounded-2xl p-4 text-sm text-amber-800">
              <p class="font-bold">Este vendedor no recibe reservas a esta hora.</p>
              <p class="mt-1">Horario de atención: {{ controls.hours_open }} a {{ controls.hours_close }}.
                <span v-if="controls.hours_note">{{ controls.hours_note }}</span></p>
            </div>
            <p v-else-if="controls.hours_note" class="text-xs text-gray-500">{{ controls.hours_note }}</p>

            <div v-if="!canTransfer && !controls.accept_cards" class="bg-gray-50 border border-gray-200 rounded-2xl p-6 text-center text-sm text-gray-600">
              Este vendedor no tiene métodos de pago en línea activos por ahora. Contáctalo directamente.
            </div>

            <div class="grid grid-cols-2 gap-3">
              <button v-if="canTransfer" @click="paymentMethod = 'transfer'"
                :class="paymentMethod === 'transfer' ? 'border-2 border-orange-600 bg-orange-50 text-orange-800' : 'border border-gray-200 text-gray-600 hover:border-gray-300'"
                class="rounded-2xl p-4 text-center transition-all">
                <PhBank :size="24" class="mx-auto mb-1.5" />
                <div class="font-bold text-sm">Transferencia</div>
                <div class="text-xs text-gray-400 mt-0.5">Depósito bancario</div>
              </button>
              <button v-if="controls.accept_cards" @click="paymentMethod = 'card'"
                :class="paymentMethod === 'card' ? 'border-2 border-orange-600 bg-orange-50 text-orange-800' : 'border border-gray-200 text-gray-600 hover:border-gray-300'"
                class="rounded-2xl p-4 text-center transition-all">
                <PhCreditCard :size="24" class="mx-auto mb-1.5" />
                <div class="font-bold text-sm">Tarjeta</div>
                <div class="text-xs text-gray-400 mt-0.5">{{ kushkiEnabled ? 'Débito o crédito' : 'Próximamente' }}</div>
              </button>
            </div>

            <div v-if="paymentMethod === 'transfer' && canTransfer" class="space-y-4">
              <div class="bg-gray-50 border border-gray-200 rounded-2xl p-4">
                <p class="text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">Datos para transferencia</p>
                <div class="space-y-1 text-sm text-gray-700">
                  <p>Banco: <strong>{{ bankInfo.bank }}</strong></p>
                  <p>Tipo: <strong>Cuenta {{ bankInfo.type }}</strong></p>
                  <p>Cuenta: <strong>{{ bankInfo.account }}</strong></p>
                  <p>Titular: <strong>{{ bankInfo.owner }}</strong></p>
                  <p>Concepto: <strong>ChivaPass, {{ tour.title }}</strong></p>
                  <p>Monto: <strong class="text-orange-700">${{ subtotal }}</strong></p>
                  <p v-if="bankInfo.notes" class="mt-2 text-xs text-gray-500">{{ bankInfo.notes }}</p>
                </div>
              </div>

              <div>
                <label class="field-label">N° de comprobante *</label>
                <input v-model="proof.number" placeholder="Ej: TRX-928374" class="field-input" />
              </div>

              <div>
                <label class="field-label">Foto / PDF del comprobante *</label>
                <label class="flex items-center gap-3 border-2 border-dashed border-gray-200 hover:border-orange-400 rounded-xl p-4 cursor-pointer transition-all">
                  <PhPaperclip :size="22" class="text-gray-400 shrink-0" />
                  <div>
                    <p class="text-sm font-semibold text-gray-700">{{ proof.fileName || 'Seleccionar archivo' }}</p>
                    <p class="text-xs text-gray-400">JPG, PNG o PDF · máx 5 MB</p>
                  </div>
                  <input type="file" accept="image/*,application/pdf" class="hidden" @change="onFileChange" />
                </label>
                <img v-if="proof.previewUrl && !proof.isPdf" :src="proof.previewUrl"
                  class="mt-3 w-28 h-28 object-cover rounded-xl border border-gray-200 shadow-sm mx-auto block" />
              </div>

              <p v-if="formError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ formError }}</p>

              <div class="flex gap-3 pt-1">
                <button @click="step = 2" class="btn-secondary flex-1">Volver</button>
                <button @click="submitTransfer" :disabled="uploading || !salesOpenNow" class="btn-primary flex-[2] disabled:opacity-50">
                  {{ uploading ? 'Procesando...' : 'Confirmar reserva' }}
                </button>
              </div>
            </div>

            <div v-if="paymentMethod === 'card' && controls.accept_cards">
              <div v-if="!kushkiEnabled">
                <div class="bg-amber-50 border border-amber-200 rounded-2xl p-6 text-center">
                  <p class="font-bold text-amber-800">Pago con tarjeta próximamente</p>
                  <p class="text-sm text-amber-700 mt-1">Por ahora usa la opción de transferencia bancaria.</p>
                </div>
                <button @click="paymentMethod = 'transfer'" class="btn-secondary w-full mt-4">Usar transferencia</button>
              </div>

              <div v-else class="space-y-4">
                <div>
                  <label class="field-label">Nombre en la tarjeta *</label>
                  <input v-model="card.name" placeholder="Como aparece en la tarjeta" autocomplete="cc-name" class="field-input" />
                </div>
                <div>
                  <label class="field-label">Número de tarjeta *</label>
                  <input v-model="card.number" @input="formatCardNumber" inputmode="numeric" autocomplete="cc-number"
                    placeholder="4242 4242 4242 4242" maxlength="23" class="field-input" />
                </div>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="field-label">Vence (MM/AA) *</label>
                    <input v-model="card.expiry" @input="formatExpiry" inputmode="numeric" autocomplete="cc-exp"
                      placeholder="09/27" maxlength="5" class="field-input" />
                  </div>
                  <div>
                    <label class="field-label">CVV *</label>
                    <input v-model="card.cvv" type="password" inputmode="numeric" autocomplete="cc-csc"
                      placeholder="123" maxlength="4" class="field-input" />
                  </div>
                </div>

                <div class="bg-gray-50 rounded-xl p-4 text-sm flex items-center justify-between">
                  <span class="text-gray-600">Total a cobrar</span>
                  <strong class="text-orange-700 text-base">${{ subtotal }}</strong>
                </div>

                <p v-if="cardError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ cardError }}</p>

                <div class="flex gap-3 pt-1">
                  <button @click="step = 2" class="btn-secondary flex-1">Volver</button>
                  <button @click="payWithCard" :disabled="charging || !salesOpenNow" class="btn-primary flex-[2] disabled:opacity-50">
                    {{ charging ? 'Procesando pago...' : `Pagar $${subtotal}` }}
                  </button>
                </div>
                <p class="text-xs text-gray-400 text-center">Pago procesado por Kushki. Los datos de tu tarjeta nunca pasan por nuestros servidores.</p>
              </div>
            </div>
          </div>

          <!-- PASO 4: Éxito -->
          <div v-if="step === 4" class="text-center py-4">
            <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-green-100 flex items-center justify-center">
              <PhCheckCircle :size="34" weight="fill" class="text-green-600" />
            </div>
            <h3 class="text-2xl font-extrabold text-gray-900 mb-1">
              {{ resultStatus === 'pagado' ? 'Pago confirmado' : 'Reserva recibida' }}
            </h3>
            <p class="text-gray-500 text-sm mb-5">
              {{ resultStatus === 'pagado'
                ? 'Tu ticket ya está activo. Te enviamos una copia al correo.'
                : 'El vendedor verificará tu comprobante. Te avisaremos por correo cuando el QR quede activo.' }}
            </p>

            <div class="bg-gray-50 rounded-2xl p-5 mb-4 inline-block">
              <p class="text-xs font-bold text-gray-500 uppercase tracking-wide mb-3">Tu QR de embarque</p>
              <img :src="qrCodeUrl" class="w-48 mx-auto rounded-xl shadow" alt="Código QR de embarque" />
              <p class="text-xs text-gray-400 mt-3">Muéstralo al conductor al abordar</p>
            </div>

            <a v-if="ticketUrl" :href="ticketUrl" target="_blank" rel="noopener"
              class="block text-sm font-semibold text-orange-700 hover:underline mb-4">
              Abrir mi ticket en una pestaña
            </a>

            <div class="bg-white border border-gray-200 rounded-xl p-4 text-sm text-left space-y-2 mb-5">
              <div class="flex justify-between text-gray-600"><span>Tour</span><strong class="text-gray-900">{{ tour.title }}</strong></div>
              <div class="flex justify-between text-gray-600"><span>Asientos</span><strong class="text-gray-900">{{ selectedSeats.join(', ') }}</strong></div>
              <div class="flex justify-between text-gray-600"><span>Salida</span><strong class="text-gray-900">{{ formatHour(tour.departure_at) }}</strong></div>
              <div class="flex justify-between text-gray-600 pt-2 border-t border-gray-100"><span>Total pagado</span><strong class="text-orange-700">${{ subtotal }}</strong></div>
            </div>

            <a :href="whatsAppUrl" target="_blank"
              class="w-full flex items-center justify-center gap-2 bg-[#25D366] hover:bg-[#1ebe5d] text-white font-bold py-3 rounded-[10px] transition-all mb-3">
              <PhWhatsappLogo :size="20" weight="fill" />
              Enviar a mi WhatsApp
            </a>

            <button @click="$emit('completed')" class="btn-secondary w-full">Reservar otro tour</button>
          </div>

        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup>
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import QRCode from 'qrcode'
import { supabase } from '@/lib/supabase'
import { kushkiEnabled, tokenizeCard } from '@/lib/kushki'
import { reserveTour, chargeCard, sellerPaymentInfo } from '@/lib/reservations'
import SeatGrid from '@/components/asientos/SeatGrid.vue'
import {
  PhX, PhCheck, PhBank, PhCreditCard, PhPaperclip, PhCheckCircle, PhWhatsappLogo,
} from '@phosphor-icons/vue'

const props = defineProps({ tour: { type: Object, default: null } })
defineEmits(['close', 'completed'])

const step          = ref(1)   // 1 asientos | 2 datos | 3 pago | 4 éxito
const selectedSeats = ref([])
const uploading     = ref(false)
const qrCodeUrl     = ref('')
const ticketUrl     = ref('')
const resultStatus  = ref('')  // 'pagado' | 'pendiente'
const paymentMethod = ref('transfer')
const stepLabels    = ['Elige asientos', 'Tus datos', 'Pago']
const formError     = ref('')

const form  = ref({ name: '', cedula: '', phone: '', email: '', address: '' })
const proof = ref({ number: '', file: null, previewUrl: '', isPdf: false, fileName: '' })

// pago con tarjeta (Kushki)
const card      = ref({ name: '', number: '', expiry: '', cvv: '' })
const charging  = ref(false)
const cardError = ref('')

const emptyBank = { bank: 'Consultar al vendedor', account: '–', owner: '–', type: 'ahorros', notes: '' }
const bankInfo  = ref({ ...emptyBank })

// Controles del vendedor (qué métodos acepta y si está en horario)
const defaultControls = { accept_transfers: true, accept_cards: true, enforce_hours: false, hours_open_now: true, hours_open: '', hours_close: '', hours_note: '' }
const controls = ref({ ...defaultControls })
const canTransfer  = computed(() => controls.value.accept_transfers)
const canCard      = computed(() => kushkiEnabled && controls.value.accept_cards)
const salesOpenNow = computed(() => controls.value.hours_open_now !== false)

watch(() => props.tour, (t) => {
  if (t) {
    step.value          = 1
    selectedSeats.value = []
    qrCodeUrl.value     = ''
    ticketUrl.value     = ''
    resultStatus.value  = ''
    paymentMethod.value = 'transfer'
    formError.value     = ''
    form.value          = { name: '', cedula: '', phone: '', email: '', address: '' }
    proof.value         = { number: '', file: null, previewUrl: '', isPdf: false, fileName: '' }
    card.value          = { name: '', number: '', expiry: '', cvv: '' }
    cardError.value     = ''
    document.body.style.overflow = 'hidden'
    loadSellerSettings(t.owner_id)
  } else {
    document.body.style.overflow = ''
  }
})

onBeforeUnmount(() => { document.body.style.overflow = '' })

// Datos bancarios del vendedor (solo los de este vendedor, vía RPC)
const loadSellerSettings = async (ownerId) => {
  const data = await sellerPaymentInfo(supabase, ownerId)
  bankInfo.value = data
    ? {
        bank:    data.bank_name    || emptyBank.bank,
        account: data.bank_account || emptyBank.account,
        owner:   data.bank_owner   || emptyBank.owner,
        type:    data.bank_type    || emptyBank.type,
        notes:   data.notes        || '',
      }
    : { ...emptyBank }
  controls.value = { ...defaultControls, ...(data ?? {}) }
  // Si el vendedor apagó las transferencias, arrancar en tarjeta
  if (!canTransfer.value && canCard.value) paymentMethod.value = 'card'
}

const subtotal = computed(() =>
  props.tour ? selectedSeats.value.length * props.tour.base_price : 0
)

const whatsAppUrl = computed(() => {
  if (!props.tour) return '#'
  const msg = [
    `Mi ticket para ${props.tour.title}`,
    `Salida: ${formatHour(props.tour.departure_at)}`,
    `Asientos: ${selectedSeats.value.join(', ')}`,
    `Total: $${subtotal.value}`,
    ticketUrl.value ? `\nVer mi código QR:\n${ticketUrl.value}` : '',
    ``,
    `ChivaPass · Baños de Agua Santa`,
  ].join('\n')
  return `https://wa.me/?text=${encodeURIComponent(msg)}`
})

const onSelectSeats = (seats) => { selectedSeats.value = seats }

const validateFormAndNext = () => {
  const { name, cedula, phone, email, address } = form.value
  if (!name || !cedula || !phone || !email || !address) {
    formError.value = 'Por favor completa todos los campos.'
    return
  }
  formError.value = ''
  step.value = 3
}

const onFileChange = (e) => {
  const file = e.target.files[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) {
    cardError.value = ''
    formError.value = 'El archivo supera los 5 MB.'
    e.target.value = ''
    return
  }
  formError.value = ''
  proof.value.file     = file
  proof.value.fileName = file.name
  proof.value.isPdf    = file.type === 'application/pdf'
  if (!proof.value.isPdf) {
    const reader = new FileReader()
    reader.onload = ev => (proof.value.previewUrl = ev.target.result)
    reader.readAsDataURL(file)
  } else {
    proof.value.previewUrl = ''
  }
}

// El servidor crea la venta, guarda el QR y envía correo + aviso al dueño.
const showResult = async (data) => {
  qrCodeUrl.value    = await QRCode.toDataURL(data.qrPayload, { width: 320, margin: 1 })
  ticketUrl.value    = data.ticketUrl || `${window.location.origin}/ticket/${data.saleId}`
  resultStatus.value = data.status || 'pagado'
  step.value = 4
}

const submitTransfer = async () => {
  if (!proof.value.number || !proof.value.file) {
    formError.value = 'Completa el número de comprobante y sube el archivo.'
    return
  }
  formError.value = ''
  uploading.value = true
  try {
    // 1. subir archivo del comprobante
    const safeName = proof.value.file.name.replace(/[^\w.-]+/g, '_').slice(-80)
    const path = `comprobantes/public_${Date.now()}_${safeName}`
    const { error: upErr } = await supabase.storage
      .from('comprobantes')
      .upload(path, proof.value.file, { contentType: proof.value.file.type })
    if (upErr) throw new Error('No se pudo subir el comprobante. Intenta de nuevo.')

    // 2. registrar la reserva (valida asientos, crea venta pendiente, notifica)
    const data = await reserveTour(supabase, {
      assignedChivaId: props.tour.id,
      seats: selectedSeats.value.map(Number),
      customer: { ...form.value },
      proofNumber: proof.value.number,
      proofPath: path,
    })
    await showResult(data)
  } catch (err) {
    formError.value = err.message || 'Error al procesar la reserva. Intenta de nuevo.'
  } finally {
    uploading.value = false
  }
}

// ─── pago con tarjeta (Kushki) ────────────────────────────────
const formatCardNumber = () => {
  card.value.number = card.value.number
    .replace(/\D/g, '').slice(0, 19)
    .replace(/(\d{4})(?=\d)/g, '$1 ')
}

const formatExpiry = () => {
  let v = card.value.expiry.replace(/\D/g, '').slice(0, 4)
  if (v.length > 2) v = v.slice(0, 2) + '/' + v.slice(2)
  card.value.expiry = v
}

const payWithCard = async () => {
  cardError.value = ''
  const { name, number, expiry, cvv } = card.value
  if (!name || !number || !expiry || !cvv) {
    cardError.value = 'Completa todos los datos de la tarjeta.'
    return
  }
  charging.value = true
  try {
    // 1. Tokenizar la tarjeta directo con Kushki
    const token = await tokenizeCard({ name, number, expiry, cvv, amount: subtotal.value })

    // 2. Cobrar en el servidor (monto calculado allá, asientos validados allá)
    const data = await chargeCard(supabase, 'tour', token, {
      assignedChivaId: props.tour.id,
      seats: selectedSeats.value.map(Number),
      customer: { ...form.value },
    })
    await showResult({ ...data, status: 'pagado' })
  } catch (e) {
    cardError.value = e.message
  } finally {
    charging.value = false
  }
}

const formatHour = (d) =>
  new Date(d).toLocaleString('es-EC', { dateStyle: 'short', timeStyle: 'short' })
</script>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.25s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.modal-enter-active > div, .modal-leave-active > div { transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1); }
.modal-enter-from > div, .modal-leave-to > div { transform: translateY(40px); }

.field-label {
  font-size: 0.75rem;
  font-weight: 600;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.3rem;
  display: block;
}
.field-input {
  width: 100%;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 0.7rem 1rem;
  font-size: 0.875rem;
  outline: none;
  transition: box-shadow .15s, border-color .15s;
}
.field-input:focus {
  border-color: transparent;
  box-shadow: 0 0 0 2px #ea580c;
}
.btn-primary {
  background: #ea580c;
  color: #fff;
  font-weight: 700;
  padding: 0.75rem 1rem;
  border-radius: 10px;
  transition: background .15s, transform .1s;
}
.btn-primary:hover { background: #c2410c; }
.btn-primary:active { transform: scale(0.98); }
.btn-secondary {
  border: 1px solid #e5e7eb;
  color: #4b5563;
  font-weight: 600;
  padding: 0.75rem 1rem;
  border-radius: 10px;
  transition: background .15s;
}
.btn-secondary:hover { background: #f9fafb; }
</style>
