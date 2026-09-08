<template>
  <BaseCard class="max-w-2xl mx-auto p-6">
    <h2 class="text-xl font-bold text-gray-900 mb-1">Datos del pasajero</h2>
    <p class="text-sm text-gray-500 mb-6">
      {{ isOwner ? "Venta directa en efectivo. Los asientos quedan pagados al confirmar." : "Después de estos datos subirás el comprobante de la transferencia." }}
    </p>

    <!-- FORMULARIO -->
    <form v-if="!result" class="space-y-5" @submit.prevent="submit">
      <div class="grid sm:grid-cols-2 gap-4">
        <BaseInput id="customerName"    v-model.trim="form.name"    required placeholder="Nombre completo" />
        <BaseInput id="customerCedula"  v-model.trim="form.cedula"  required placeholder="Cédula o pasaporte" />
        <BaseInput id="customerPhone"   v-model.trim="form.phone"   required placeholder="Teléfono" />
        <BaseInput id="customerEmail"   v-model.trim="form.email"   type="email" required placeholder="Correo" />
      </div>
      <BaseInput id="customerAddress" v-model.trim="form.address" placeholder="Dirección (opcional)" />

      <div class="bg-gray-50 p-4 border border-gray-200 rounded-xl text-sm text-gray-700 space-y-1">
        <p class="flex justify-between"><span class="text-gray-500">Tour</span><strong>{{ selectedTour?.name }}</strong></p>
        <p class="flex justify-between"><span class="text-gray-500">Chiva</span><strong>{{ selectedTour?.chiva }}</strong></p>
        <p class="flex justify-between"><span class="text-gray-500">Salida</span><strong>{{ formatHour(selectedTour?.departure_time) }}</strong></p>
        <p class="flex justify-between"><span class="text-gray-500">Asientos</span><strong>{{ selectedSeats.join(", ") }}</strong></p>
        <p class="flex justify-between border-t border-gray-200 pt-2 mt-1"><span class="text-gray-500">Total</span><strong class="text-lg">${{ Number(total).toFixed(2) }}</strong></p>
      </div>

      <p v-if="error" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ error }}</p>

      <BaseButton full type="submit" :disabled="busy">
        {{ busy ? "Registrando..." : (isOwner ? "Confirmar venta en efectivo" : "Continuar al comprobante") }}
      </BaseButton>
    </form>

    <!-- RESULTADO -->
    <div v-else class="text-center space-y-5">
      <div class="w-14 h-14 mx-auto rounded-full bg-green-100 flex items-center justify-center">
        <PhCheckCircle :size="30" weight="fill" class="text-green-600" />
      </div>
      <div>
        <h3 class="text-lg font-bold text-gray-900">
          {{ result.status === "pagado" ? "Venta confirmada" : "Reserva registrada" }}
        </h3>
        <p class="text-sm text-gray-500 mt-1">
          {{ result.status === "pagado"
            ? "El ticket ya está activo para el embarque."
            : "Los asientos quedan reservados hasta que el dueño verifique el comprobante." }}
        </p>
      </div>

      <div class="bg-gray-50 rounded-2xl p-5 inline-block">
        <img :src="qrCodeUrl" class="w-48 mx-auto rounded-lg" alt="Código QR del ticket" />
        <p class="text-xs text-gray-400 mt-2">Se envió una copia al correo del pasajero</p>
      </div>

      <div class="flex flex-col sm:flex-row gap-3 justify-center">
        <a v-if="result.ticketUrl" :href="result.ticketUrl" target="_blank" rel="noopener"
          class="px-4 py-2.5 rounded-xl border border-gray-200 text-sm font-semibold text-gray-700 hover:bg-gray-50">
          Abrir ticket
        </a>
        <BaseButton @click="emit('purchaseConfirmed')">Nueva venta</BaseButton>
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
import { PhCheckCircle } from "@phosphor-icons/vue";
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
