<template>
  <BaseCard class="w-full">
    <!-- FORMULARIO -->
    <form v-if="!result" class="space-y-5" novalidate @submit.prevent="submit">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Datos del pasajero</h2>
        <p class="mt-1 text-sm text-gray-600">
          {{ isOwner ? "Venta directa en efectivo. Los asientos quedan pagados al confirmar." : "Después de estos datos subirás el comprobante de la transferencia." }}
        </p>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <BaseInput name="customerName"   label="Nombre completo"     v-model.trim="form.name"   required autocomplete="name" />
        <BaseInput name="customerCedula" label="Cédula o pasaporte"  v-model.trim="form.cedula" required />
        <BaseInput name="customerPhone"  label="Teléfono / WhatsApp" v-model.trim="form.phone"  required type="tel" autocomplete="tel" placeholder="+593 99 999 9999" />
        <BaseInput name="customerEmail"  label="Correo"              v-model.trim="form.email"  required type="email" autocomplete="email" placeholder="nombre@correo.com" />
      </div>
      <BaseInput name="customerAddress" label="Dirección (opcional)" v-model.trim="form.address" autocomplete="street-address" />

      <dl class="divide-y divide-gray-100 rounded-lg border border-gray-200 text-sm">
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Tour</dt><dd class="text-right font-semibold text-gray-900">{{ selectedTour?.name }}</dd></div>
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Chiva</dt><dd class="text-right font-semibold text-gray-900">{{ selectedTour?.chiva }}</dd></div>
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Salida</dt><dd class="text-right font-semibold text-gray-900">{{ formatHour(selectedTour?.departure_time) }}</dd></div>
        <div class="flex justify-between gap-4 px-4 py-2.5"><dt class="text-gray-600">Asientos</dt><dd class="text-right font-semibold text-gray-900 tabular-nums">{{ selectedSeats.join(", ") }}</dd></div>
        <div class="flex items-baseline justify-between gap-4 bg-gray-50 px-4 py-3"><dt class="font-medium text-gray-700">Total</dt><dd class="text-xl font-bold text-gray-900 tabular-nums">${{ Number(total).toFixed(2) }}</dd></div>
      </dl>

      <p v-if="error" role="alert" class="flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">
        <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ error }}
      </p>

      <BaseButton block size="lg" type="submit" :loading="busy">
        {{ busy ? "Registrando venta" : (isOwner ? "Confirmar venta en efectivo" : "Continuar al comprobante") }}
      </BaseButton>
    </form>

    <!-- RESULTADO -->
    <div v-else class="space-y-5 py-2 text-center">
      <span class="mx-auto inline-flex size-14 items-center justify-center rounded-full bg-ok-50 text-ok-700">
        <PhCheckCircle :size="32" weight="fill" />
      </span>
      <div>
        <h2 class="text-lg font-semibold text-gray-900">
          {{ result.status === "pagado" ? "Venta confirmada" : "Reserva registrada" }}
        </h2>
        <p class="mx-auto mt-1 max-w-[44ch] text-sm text-gray-600">
          {{ result.status === "pagado"
            ? "El ticket ya está activo para el embarque."
            : "Los asientos quedan reservados hasta que el dueño verifique el comprobante." }}
        </p>
      </div>

      <figure class="inline-block rounded-[var(--radius-card)] border border-gray-200 bg-white p-4">
        <img :src="qrCodeUrl" class="mx-auto w-48" alt="Código QR del ticket" />
        <figcaption class="mt-2 text-xs text-gray-600">Se envió una copia al correo del pasajero</figcaption>
      </figure>

      <div class="flex flex-col justify-center gap-3 sm:flex-row">
        <a v-if="result.ticketUrl" :href="result.ticketUrl" target="_blank" rel="noopener"
          class="inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white px-4 text-sm font-semibold text-gray-800 hover:bg-gray-50">
          Abrir ticket <PhArrowSquareOut :size="16" />
        </a>
        <BaseButton @click="emit('purchaseConfirmed')">Hacer otra venta</BaseButton>
      </div>
    </div>

    <!-- MODAL COMPROBANTE -->
    <PaymentProofModal
      v-if="showProofModal"
      @uploaded="onProofUploaded"
      @close="showProofModal = false"
    />
  </BaseCard>
</template>

<script setup>
import { ref, computed } from "vue";
import QRCode from "qrcode";
import { PhCheckCircle, PhWarningCircle, PhArrowSquareOut } from "@phosphor-icons/vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import { reserveTour } from "@/lib/reservations";

import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import BaseInput from "@/components/ui/BaseInput.vue";
import PaymentProofModal from "@/components/payments/PaymentProofModal.vue";

const props = defineProps({
  selectedTour: { type: Object, required: true },
  selectedSeats: { type: Array, default: () => [] },
  total: { type: Number, default: 0 },
});

const emit = defineEmits(["purchaseConfirmed"]);

const auth = useAuthStore();
const isOwner = computed(() => auth.user?.role === "dueño");

const form = ref({ name: "", cedula: "", phone: "", email: "", address: "" });
const busy = ref(false);
const error = ref("");
const showProofModal = ref(false);
const result = ref(null);
const qrCodeUrl = ref("");

const formatHour = (d) =>
  d ? new Date(d).toLocaleString("es-EC", { dateStyle: "short", timeStyle: "short" }) : "Sin hora";

const validate = () => {
  const { name, cedula, phone, email } = form.value;
  if (!name || !cedula || !phone || !email) {
    error.value = "Completa nombre, cédula, teléfono y correo.";
    return false;
  }
  error.value = "";
  return true;
};

// Paso 1: validar → dueño registra en efectivo; agencia sube comprobante.
const submit = async () => {
  if (!validate()) return;
  if (isOwner.value) {
    await finish({ paymentMethod: "efectivo" });
  } else {
    showProofModal.value = true;
  }
};

const onProofUploaded = async ({ path, number }) => {
  showProofModal.value = false;
  await finish({ proofPath: path, proofNumber: number });
};

// Paso 2: la edge function valida asientos, crea la venta y notifica.
const finish = async (extra) => {
  busy.value = true;
  error.value = "";
  try {
    const seats = props.selectedSeats.map(Number);
    const data = await reserveTour(supabase, {
      assignedChivaId: props.selectedTour.id,
      seats,
      customer: { ...form.value },
      ...extra,
    });
    qrCodeUrl.value = await QRCode.toDataURL(data.qrPayload, { width: 320, margin: 1 });
    result.value = data;
  } catch (e) {
    error.value = e.message || "No se pudo registrar la venta.";
  } finally {
    busy.value = false;
  }
};
</script>
