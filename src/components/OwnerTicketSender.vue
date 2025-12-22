<template>
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
    <BaseCard class="w-full max-w-md">
      <h3 class="text-lg font-bold mb-4 text-gray-800 text-center">
        📧 Enviar Ticket Manualmente
      </h3>

      <form @submit.prevent="sendTicket" class="space-y-4">
        <BaseInput v-model="customerName" placeholder="Nombre del cliente" required />
        <BaseInput v-model="customerCedula" placeholder="Número de cédula" required />
        <BaseInput v-model="customerPhone" placeholder="Teléfono" required />
        <BaseInput v-model="customerAddress" placeholder="Dirección" required />
        <BaseInput v-model="customerEmail" type="email" placeholder="Correo del cliente" required />

        <div class="bg-gray-50 border rounded-lg p-4 text-sm text-gray-600 space-y-1">
          <p><strong>🎟️ Tour:</strong> {{ selectedTour?.name }}</p>
          <p><strong>🚌 Chiva:</strong> {{ selectedTour?.chiva }}</p>
          <p><strong>⏰ Fecha:</strong> {{ formatDate(selectedTour?.departure_time) }}</p>
          <p><strong>🪑 Asientos:</strong> {{ selectedSeats.join(', ') }}</p>
          <p><strong>💰 Total:</strong> ${{ selectedSeats.length * (selectedTour?.base_price || 2) }}</p>
        </div>

        <div v-if="qrCodeUrl" class="text-center">
          <p class="mb-2 text-sm text-gray-600">🎫 Este es el QR del ticket</p>
          <img :src="qrCodeUrl" alt="QR Code" class="mx-auto w-40 h-40 rounded-lg shadow-md border" />
        </div>

        <BaseButton type="submit" full>
          ✉️ Enviar Ticket al Cliente y al Dueño
        </BaseButton>
      </form>

      <BaseButton variant="secondary" full class="mt-3" @click="$emit('close')">
        Cerrar
      </BaseButton>
    </BaseCard>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { supabase } from "@/lib/supabase";
import emailjs from "@emailjs/browser";
import QRCode from "qrcode";

import BaseButton from "@/components/ui/BaseButton.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseInput from "@/components/ui/BaseInput.vue";

const props = defineProps({
  selectedTour: Object,
  selectedSeats: Array,
});

const customerName = ref("");
const customerCedula = ref("");
const customerPhone = ref("");
const customerAddress = ref("");
const customerEmail = ref("");
const qrCodeUrl = ref("");

// Formatear fecha legible
const formatDate = (dateTime) => {
  if (!dateTime) return "Sin fecha";
  return new Date(dateTime).toLocaleString([], {
    dateStyle: "short",
    timeStyle: "short",
  });
};

// Enviar ticket manualmente
const sendTicket = async () => {
  if (
    !customerName.value ||
    !customerCedula.value ||
    !customerPhone.value ||
    !customerAddress.value ||
    !customerEmail.value
  ) {
    alert("⚠️ Por favor completa todos los campos del cliente.");
    return;
  }

  // Generar QR
  qrCodeUrl.value = await QRCode.toDataURL(
  JSON.stringify({
    assigned_chiva_id: props.selectedTour.id, // 🔥 CLAVE
    tour: props.selectedTour?.name,
    seats: props.selectedSeats,
    chiva: props.selectedTour?.chiva,
    fecha: formatDate(props.selectedTour?.departure_time)
  })
);


  // Obtener agencia (usuario actual)
  const { data: session } = await supabase.auth.getUser();
  const agencyId = session?.user?.id;
  const { data: agency } = await supabase
    .from("users")
    .select("full_name, email")
    .eq("id", agencyId)
    .single();

  // Obtener dueño
  const { data: assigned } = await supabase
    .from("assigned_chivas")
    .select(`id, tours ( title, user_id ), chivas ( name )`)
    .eq("id", props.selectedTour.id)
    .single();

  const { data: owner } = await supabase
    .from("users")
    .select("full_name, email")
    .eq("id", assigned.tours.user_id)
    .single();

  // Enviar correo al cliente (template con QR)
  const clientParams = {
    cliente: customerName.value,
    correo: customerEmail.value,
    cedula: customerCedula.value,
    telefono: customerPhone.value,
    direccion: customerAddress.value,
    tour: props.selectedTour.name,
    chiva: props.selectedTour.chiva,
    fecha: formatDate(props.selectedTour.departure_time),
    asientos: props.selectedSeats.join(", "),
    total: props.selectedSeats.length * (props.selectedTour.base_price || 2),
    qr: qrCodeUrl.value,
    agencia_nombre: agency.full_name,
    dueno_nombre: owner.full_name,
  };

  // Enviar correo al dueño (notificación)
  const ownerParams = {
    dueno: owner.full_name,
    correo_dueno: owner.email,
    tour: props.selectedTour.name,
    chiva: props.selectedTour.chiva,
    asientos: props.selectedSeats.join(", "),
    total: props.selectedSeats.length * (props.selectedTour.base_price || 2),
    agencia_nombre: agency.full_name,
    agencia_correo: agency.email,
  };

  try {
    await emailjs.send("service_384ghjp", "template_ax9ioca", clientParams, "3vYtcZkms5NAqUjGI");
    await emailjs.send("service_384ghjp", "template_lakte1r", ownerParams, "3vYtcZkms5NAqUjGI");
    alert("✅ Ticket enviado correctamente al cliente y notificación al dueño.");
  } catch (error) {
    console.error("❌ Error al enviar correos:", error);
    alert("Error al enviar el ticket. Revisa la consola para más detalles.");
  }
};
</script>
