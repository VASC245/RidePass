<template>
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <BaseCard class="w-full max-w-md">
      <h3 class="text-lg font-bold mb-4">Enviar Ticket</h3>

      <form
        action="https://formsubmit.co/chivaspass@gmail.com"
        method="POST"
        class="space-y-4"
      >
        <!-- Correos -->
        <BaseInput type="hidden" name="CorreoCliente" :value="customerEmail" />
        <BaseInput type="hidden" name="_replyto" :value="customerEmail" />

        <!-- Datos del ticket -->
        <BaseInput type="hidden" name="Cliente" :value="customerName" />
        <BaseInput type="hidden" name="Tour" :value="selectedTour?.name" />
        <BaseInput type="hidden" name="Chiva" :value="selectedTour?.chiva" />
        <BaseInput
          type="hidden"
          name="Fecha"
          :value="formatDate(selectedTour?.departure_time)"
        />
        <BaseInput
          type="hidden"
          name="Asientos"
          :value="selectedSeats.join(', ')"
        />
        <BaseInput type="hidden" name="QR" :value="qrCodeUrl" />

        <!-- Configuración de FormSubmit -->
        <input type="hidden" name="_subject" value="🎟️ Nuevo Ticket ChivaPass" />
        <input type="hidden" name="_template" value="custom" />
        <input type="hidden" name="_captcha" value="false" />
        <input type="hidden" name="_next" value="https://tusitio.com/gracias" />
        <input
          type="hidden"
          name="_autoresponse"
          value="✅ Hemos recibido tu compra en ChivaPass. Tu ticket está en este correo."
        />

        <!-- Vista previa del QR -->
        <div v-if="qrCodeUrl" class="text-center">
          <p class="mb-2 text-sm text-gray-600">Este es tu ticket digital</p>
          <img :src="qrCodeUrl" alt="QR Code" class="mx-auto w-40 h-40" />
          <a
            :href="qrCodeUrl"
            download="ticket.png"
            class="text-blue-600 underline text-sm block mt-2"
          >
            Descargar QR
          </a>
        </div>

        <!-- Botón de enviar -->
        <BaseButton type="submit" full>
          Enviar Ticket al Correo
        </BaseButton>
      </form>

      <BaseButton variant="secondary" full class="mt-3" @click="$emit('close')">
        Cerrar
      </BaseButton>
    </BaseCard>
  </div>
</template>

<script setup>
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseCard from '@/components/ui/BaseCard.vue';
import BaseInput from '@/components/ui/BaseInput.vue';

const props = defineProps({
  customerName: String,
  customerEmail: String,
  selectedTour: Object,
  selectedSeats: Array,
  qrCodeUrl: String
});

// 🔹 Formatear fecha legible
const formatDate = (dateTime) => {
  if (!dateTime) return 'Sin fecha';
  return new Date(dateTime).toLocaleString([], {
    dateStyle: 'short',
    timeStyle: 'short'
  });
};
</script>
