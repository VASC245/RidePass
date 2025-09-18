<template>
  <BaseCard class="max-w-2xl mx-auto">
    <h2 class="text-xl font-bold mb-4">Finalizar compra</h2>

    <!-- Formulario inicial -->
    <form class="space-y-4" @submit.prevent="confirmPurchase" v-if="!qrVisible">
      <BaseInput v-model="customerName" name="name" placeholder="Nombre del cliente" required />
      <BaseInput v-model="customerEmail" type="email" name="email" placeholder="Correo del cliente" required />

      <div class="text-sm text-gray-600 space-y-1">
        <p><strong>Tour:</strong> {{ selectedTour?.name }}</p>
        <p><strong>Chiva:</strong> {{ selectedTour?.chiva }}</p>
        <p><strong>Hora salida:</strong> {{ formatHour(selectedTour?.departure_time) }}</p>
        <p><strong>Total:</strong> ${{ total }}</p>
      </div>

      <div class="pt-2">
        <h4 class="font-semibold mb-2">Asientos seleccionados:</h4>
        <div class="flex flex-wrap gap-2">
          <div
            v-for="seat in selectedSeats"
            :key="seat"
            class="w-10 h-10 flex items-center justify-center rounded bg-green-600 text-white text-sm font-bold"
          >
            {{ seat }}
          </div>
        </div>
      </div>

      <BaseButton full type="submit">
        Confirmar y Generar QR
      </BaseButton>
    </form>

    <!-- Vista QR -->
    <div v-if="qrVisible" class="text-center space-y-4">
      <p class="font-semibold">Escanea o toma captura de tu ticket</p>
      <img :src="qrCodeUrl" alt="QR Ticket" class="mx-auto w-48 h-48" />
      <p class="text-sm text-gray-500">Este QR desaparecerá en {{ countdown }} segundos</p>
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

const customerName = ref('');
const customerEmail = ref('');
const qrCodeUrl = ref('');
const qrVisible = ref(false);
const countdown = ref(10);

let timerId = null;

const formatHour = (dateTime) => {
  if (!dateTime) return 'Sin hora';
  return new Date(dateTime).toLocaleString([], {
    dateStyle: 'short',
    timeStyle: 'short'
  });
};

const confirmPurchase = async () => {
  if (!customerName.value || !customerEmail.value) {
    alert("⚠️ Debes ingresar el nombre y correo del cliente.");
    return;
  }

  // 🔹 Generar QR
  const text = `Tour: ${props.selectedTour.name}, Chiva: ${props.selectedTour.chiva}, Asientos: ${props.selectedSeats.join(', ')}`;
  qrCodeUrl.value = await QRCode.toDataURL(text);

  // 🔹 Actualizar asientos en Supabase
  await supabase
    .from('seats')
    .update({ status: 'pagado' })
    .in('seat_number', props.selectedSeats)
    .eq('assigned_chiva_id', props.selectedTour.id);

  // 🔹 Enviar correo dinámico con EmailJS
  sendEmail();

  // 🔹 Mostrar QR y contador
  qrVisible.value = true;
  countdown.value = 10;

  timerId = setInterval(() => {
    if (countdown.value > 1) {
      countdown.value--;
    } else {
      clearInterval(timerId);
      qrVisible.value = false;
      emit('purchaseConfirmed'); // Reinicia SellPage
    }
  }, 1000);
};

// 🔹 Enviar email con EmailJS (siempre al admin, opcional al cliente)
const sendEmail = () => {
  // Si el cliente dejó vacío, usamos solo el admin
  const destinatario = customerEmail.value
    ? customerEmail.value
    : "chivaspass@gmail.com";

  const templateParams = {
    cliente: customerName.value,
    correo: destinatario, // 👈 coincide con {{correo}} en plantilla
    tour: props.selectedTour.name,
    chiva: props.selectedTour.chiva,
    fecha: formatHour(props.selectedTour.departure_time),
    asientos: props.selectedSeats.join(', '),
    total: props.total,
    qr: qrCodeUrl.value
  };

  emailjs
    .send(
      "service_384ghjp",   // 👈 tu Service ID
      "template_ax9ioca",  // 👈 tu Template ID
      templateParams,
      "3vYtcZkms5NAqUjGI"    // 👈 tu Public Key
    )
    .then(
      (response) => {
        console.log("✅ Ticket enviado:", response.status, response.text);
      },
      (error) => {
        console.error("❌ Error enviando ticket:", error);
      }
    );
};
</script>
