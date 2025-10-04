<template>
  <BaseCard class="max-w-2xl mx-auto p-6">
    <h2 class="text-2xl font-extrabold mb-6 text-gray-800 text-center">
      🧾 Finalizar compra
    </h2>

    <!-- Formulario -->
    <form
      class="space-y-6"
      @submit.prevent="confirmPurchase"
      v-if="!qrVisible"
    >
      <!-- Campos del cliente -->
      <BaseInput
        v-model="customerName"
        name="name"
        placeholder="Nombre del cliente"
        required
      />
      <BaseInput
        v-model="customerCedula"
        name="cedula"
        placeholder="Número de cédula"
        required
      />
      <BaseInput
        v-model="customerPhone"
        type="tel"
        name="phone"
        placeholder="Número de teléfono"
        required
      />
      <BaseInput
        v-model="customerAddress"
        name="address"
        placeholder="Dirección del cliente"
        required
      />
      <BaseInput
        v-model="customerEmail"
        type="email"
        name="email"
        placeholder="Correo del cliente"
        required
      />

      <!-- Info del Tour -->
      <div class="text-sm text-gray-700 space-y-1 bg-gray-50 p-4 rounded-lg border">
        <p><strong>🎟️ Tour:</strong> {{ selectedTour?.name }}</p>
        <p><strong>🚌 Chiva:</strong> {{ selectedTour?.chiva }}</p>
        <p><strong>⏰ Hora salida:</strong> {{ formatHour(selectedTour?.departure_time) }}</p>
        <p class="font-bold text-green-700"><strong>💵 Total:</strong> ${{ total }}</p>
      </div>

      <!-- Asientos -->
      <div class="pt-2">
        <h4 class="font-semibold mb-3 text-gray-800">🪑 Asientos seleccionados:</h4>
        <div class="flex flex-wrap gap-3">
          <div
            v-for="seat in selectedSeats"
            :key="seat"
            class="w-12 h-12 flex items-center justify-center rounded-full bg-green-600 text-white text-sm font-bold shadow hover:bg-green-700 transition"
          >
            {{ seat }}
          </div>
        </div>
      </div>

      <!-- Botón confirmar -->
      <BaseButton full type="submit" class="mt-6">
        ✅ Confirmar y Generar QR
      </BaseButton>
    </form>

    <!-- Vista QR -->
    <div v-if="qrVisible" class="text-center space-y-6">
      <h3 class="text-lg font-semibold text-gray-800">🎫 Ticket generado</h3>
      <p class="text-gray-600">Escanea o guarda tu código QR</p>
      <img
        :src="qrCodeUrl"
        alt="QR Ticket"
        class="mx-auto w-56 h-56 rounded-lg shadow-md border"
      />
      <p class="text-sm text-gray-500">
        ⏳ Este QR desaparecerá en <span class="font-semibold">{{ countdown }}</span> segundos
      </p>
    </div>
  </BaseCard>
</template>

<script setup>
import { ref } from 'vue';
import QRCode from 'qrcode';
import { supabase } from '@/lib/supabase';
import emailjs from '@emailjs/browser';

import BaseButton from '@/components/ui/BaseButton.vue';
import BaseCard from '@/components/ui/BaseCard.vue';
import BaseInput from '@/components/ui/BaseInput.vue';

const props = defineProps({
  selectedTour: Object,
  selectedSeats: Array,
  total: Number
});
const emit = defineEmits(['purchaseConfirmed']);

// Campos del cliente
const customerName = ref('');
const customerCedula = ref('');
const customerPhone = ref('');
const customerAddress = ref('');
const customerEmail = ref('');
const qrCodeUrl = ref('');
const qrVisible = ref(false);
const countdown = ref(10);
let timerId = null;

// Formatear hora legible
const formatHour = (dateTime) => {
  if (!dateTime) return 'Sin hora';
  return new Date(dateTime).toLocaleString([], {
    dateStyle: 'short',
    timeStyle: 'short'
  });
};

// Confirmar compra
const confirmPurchase = async () => {
  if (
    !customerName.value ||
    !customerEmail.value ||
    !customerCedula.value ||
    !customerPhone.value ||
    !customerAddress.value
  ) {
    alert("⚠️ Debes completar todos los campos del cliente.");
    return;
  }

  // Generar QR
  const text = `Tour: ${props.selectedTour.name}, Chiva: ${props.selectedTour.chiva}, Asientos: ${props.selectedSeats.join(', ')}`;
  qrCodeUrl.value = await QRCode.toDataURL(text);

  // Actualizar asientos
  await supabase
    .from('seats')
    .update({ status: 'pagado' })
    .in('seat_number', props.selectedSeats)
    .eq('assigned_chiva_id', props.selectedTour.id);

  // Enviar correo
  sendEmail();

  // Mostrar QR
  qrVisible.value = true;
  countdown.value = 10;
  timerId = setInterval(() => {
    if (countdown.value > 1) countdown.value--;
    else {
      clearInterval(timerId);
      qrVisible.value = false;
      emit('purchaseConfirmed');
    }
  }, 1000);
};

// Enviar correo con EmailJS
const sendEmail = () => {
  const destinatario = customerEmail.value || "chivaspass@gmail.com";

  const templateParams = {
    cliente: customerName.value,
    correo: destinatario,
    cedula: customerCedula.value,
    telefono: customerPhone.value,
    direccion: customerAddress.value,
    tour: props.selectedTour.name,
    chiva: props.selectedTour.chiva,
    fecha: formatHour(props.selectedTour.departure_time),
    asientos: props.selectedSeats.join(', '),
    total: props.total,
    qr: qrCodeUrl.value
  };

  emailjs
    .send(
      "service_384ghjp",     // 👈 tu Service ID
      "template_ax9ioca",    // 👈 tu Template ID (usa el nuevo HTML)
      templateParams,
      "3vYtcZkms5NAqUjGI"    // 👈 tu Public Key
    )
    .then(
      (response) => console.log("✅ Ticket enviado:", response.status, response.text),
      (error) => console.error("❌ Error enviando ticket:", error)
    );
};
</script>
