<template>
  <BaseCard class="max-w-2xl mx-auto p-6">
    <h2 class="text-2xl font-extrabold mb-6 text-center text-gray-800">
      🧾 Finalizar compra
    </h2>

    <!-- FORMULARIO -->
    <form
      v-if="!qrVisible"
      class="space-y-6"
      @submit.prevent="tryToConfirmPurchase"
    >
      <BaseInput id="customerName" v-model="customerName" required placeholder="Nombre del cliente" />
      <BaseInput id="customerCedula" v-model="customerCedula" required placeholder="Número de cédula" />
      <BaseInput id="customerPhone" v-model="customerPhone" required placeholder="Teléfono" />
      <BaseInput id="customerAddress" v-model="customerAddress" required placeholder="Dirección" />
      <BaseInput id="customerEmail" v-model="customerEmail" type="email" required placeholder="Correo del cliente" />

      <div class="bg-gray-50 p-4 border rounded-lg text-sm text-gray-700">
        <p><strong>🎟️ Tour:</strong> {{ selectedTour?.name }}</p>
        <p><strong>🚌 Chiva:</strong> {{ selectedTour?.chiva }}</p>
        <p><strong>⏰ Salida:</strong> {{ formatHour(selectedTour?.departure_time) }}</p>
        <p><strong>💵 Total:</strong> ${{ total }}</p>
      </div>

      <div>
        <h4 class="font-semibold mb-3">🪑 Asientos seleccionados:</h4>
        <div class="flex flex-wrap gap-3">
          <div
            v-for="seat in selectedSeats"
            :key="seat"
            class="w-12 h-12 bg-green-600 text-white rounded-full shadow flex items-center justify-center font-bold"
          >
            {{ seat }}
          </div>
        </div>
      </div>

      <BaseButton full type="submit">💵 Continuar al comprobante</BaseButton>
    </form>

    <!-- QR -->
    <div v-if="qrVisible" class="text-center space-y-6">
      <h3 class="text-lg font-semibold">🎫 Ticket generado</h3>
      <img :src="qrCodeUrl" class="w-56 mx-auto rounded-lg shadow" />
      <p class="text-gray-600 text-sm">⏳ Este QR desaparecerá en <strong>{{ countdown }}</strong> segundos</p>
    </div>

    <!-- MODAL -->
    <PaymentProofModal
      v-if="showProofModal"
      :assignedChivaId="selectedTour?.id"
      :ownerId="selectedTour?.owner_id"
      @uploaded="completeSaleAfterProof"
      @close="cancelProofUpload"
    />
  </BaseCard>
</template>

<script setup>
import { ref } from "vue";
import QRCode from "qrcode";
import { supabase } from "@/lib/supabase";
import emailjs from "@emailjs/browser";

import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import BaseInput from "@/components/ui/BaseInput.vue";
import PaymentProofModal from "@/components/payments/PaymentProofModal.vue";

const props = defineProps({
  selectedTour: Object,
  selectedSeats: Array,
  total: Number
});

const emit = defineEmits(["purchaseConfirmed"]);

// CAMPOS CLIENTE
const customerName = ref("");
const customerCedula = ref("");
const customerPhone = ref("");
const customerAddress = ref("");
const customerEmail = ref("");

// QR
const qrVisible = ref(false);
const qrCodeUrl = ref("");
const countdown = ref(10);
let qrTimer = null;

// MODAL
const showProofModal = ref(false);
let proofTimer = null;

// Formato de hora
const formatHour = d =>
  new Date(d).toLocaleString([], { dateStyle: "short", timeStyle: "short" });


// ----------------------
// Paso 1: Validar formulario
// ----------------------
const tryToConfirmPurchase = () => {
  if (!customerName.value || !customerCedula.value || !customerPhone.value || !customerAddress.value || !customerEmail.value) {
    alert("⚠️ Completa todos los campos.");
    return;
  }

  showProofModal.value = true;

  proofTimer = setTimeout(() => {
    alert("⏳ Tiempo agotado. Vuelve a subir el comprobante.");
    cancelProofUpload();
  }, 600000);
};

const cancelProofUpload = () => {
  showProofModal.value = false;
  clearTimeout(proofTimer);
};



// ----------------------
// Paso 2: Procesar venta COMPLETA
// ----------------------
const completeSaleAfterProof = async (proofUrl) => {
  clearTimeout(proofTimer);
  showProofModal.value = false;

  // Obtener usuario actual
  const { data: session } = await supabase.auth.getUser();
  const agencyId = session?.user?.id || "";

  // -----------------------------------
  // NO MÁS VALIDACIONES QUE FALLAN
  // -----------------------------------
  // Vamos a permitir guardar aunque selectedTour esté incompleto
  // Se guardará igual en sales_simple
  // -----------------------------------

  // Datos para ventas
  const seatsInt = props.selectedSeats.map(n => Number(n));
  const pricePerSeat = props.total / seatsInt.length;
  const ownerGain = seatsInt.length * 2;
  const agencyGain = props.total - ownerGain;

  // ==========================================
  // INSERT A LA TABLA NUEVA SIN RESTRICCIONES
  // ==========================================

  const { error: salesError } = await supabase.from("sales_simple").insert([
    {
      assigned_chiva_id: props.selectedTour?.id || "",
      tour_id: props.selectedTour?.tour_id || "",
      owner_id: props.selectedTour?.owner_id || "",
      agency_id: agencyId,

      seats: JSON.stringify(seatsInt),
      sale_price: pricePerSeat,
      total_sale: props.total,
      owner_gain: ownerGain,
      agency_gain: agencyGain,
      status: "pagado"
    }
  ]);

  if (salesError) {
    console.error("❌ ERROR SALES_SIMPLE:", salesError);
    alert("Error al registrar la venta.");
    return;
  }

  // -----------------------------------
  // Actualizar estado de asientos
  // -----------------------------------
  await supabase
    .from("seats")
    .update({ status: "pagado" })
    .in("seat_number", seatsInt)
    .eq("assigned_chiva_id", props.selectedTour?.id || "");

  // -----------------------------------
  // Generar QR
  // -----------------------------------
  qrCodeUrl.value = await QRCode.toDataURL(
  JSON.stringify({
    assigned_chiva_id: props.selectedTour.id, // 🔥 ESTE ERA EL FALTANTE
    tour: props.selectedTour?.name,
    seats: seatsInt,
    chiva: props.selectedTour?.chiva,
    fecha: formatHour(props.selectedTour?.departure_time)
  })
);


  // -----------------------------------
  // Enviar correo
  // -----------------------------------
  sendEmail();

  // -----------------------------------
  // Mostrar QR y cuenta regresiva
  // -----------------------------------
  qrVisible.value = true;
  countdown.value = 10;

  qrTimer = setInterval(() => {
    if (countdown.value > 1) countdown.value--;
    else {
      clearInterval(qrTimer);
      qrVisible.value = false;
      emit("purchaseConfirmed");
    }
  }, 1000);
};


// Enviar correo
const sendEmail = () => {
  emailjs.send(
    "service_384ghjp",
    "template_ax9ioca",
    {
      cliente: customerName.value,
      correo: customerEmail.value,
      cedula: customerCedula.value,
      telefono: customerPhone.value,
      direccion: customerAddress.value,
      tour: props.selectedTour?.name,
      chiva: props.selectedTour?.chiva,
      fecha: formatHour(props.selectedTour?.departure_time),
      asientos: props.selectedSeats.join(", "),
      total: props.total,
      qr: qrCodeUrl.value,
    },
    "3vYtcZkms5NAqUjGI"
  );
};
</script>
