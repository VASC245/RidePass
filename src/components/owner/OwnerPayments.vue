<template>
  <div class="max-w-7xl mx-auto p-6 space-y-8">
    <h1 class="text-3xl font-extrabold text-center">💰 Comprobantes Recibidos</h1>

    <BaseCard>
      <h3 class="text-lg font-semibold mb-4">📄 Comprobantes</h3>

      <div v-if="loading" class="italic text-gray-500">⏳ Cargando...</div>

      <div v-else-if="comprobantes.length === 0" class="text-center text-gray-500 py-10">
        🚫 No hay comprobantes registrados todavía.
      </div>

      <div v-else class="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div
          v-for="pago in comprobantes"
          :key="pago.id"
          class="border rounded-xl p-5 shadow hover:shadow-lg transition"
        >
          <p class="text-sm text-gray-500">📅 {{ formatDate(pago.created_at) }}</p>
          <p class="text-lg font-semibold">{{ pago.tour_title }}</p>
          <p class="text-sm text-gray-700">🚌 {{ pago.chiva_name }}</p>
          <p class="text-sm">🧾 {{ pago.numero_comprobante }}</p>
          <p class="text-sm">🏢 {{ pago.agency_name }}</p>

          <p
            class="font-semibold mt-1"
            :class="{
              'text-yellow-600': pago.estado === 'pendiente',
              'text-green-600': pago.estado === 'verificado',
              'text-red-600': pago.estado === 'rechazado'
            }"
          >
            Estado: {{ pago.estado }}
          </p>

          <button
            @click="openModal(pago)"
            class="text-blue-600 underline mt-2"
          >
            📎 Ver comprobante
          </button>
        </div>
      </div>
    </BaseCard>

    <!-- MODAL -->
    <div
      v-if="selectedPago"
      class="fixed inset-0 bg-black bg-opacity-60 flex items-center justify-center z-50"
    >
      <BaseCard class="max-w-lg w-full p-6 relative">
        <button @click="selectedPago = null" class="absolute right-3 top-3">✖</button>

        <h3 class="text-xl font-bold text-center mb-4">📑 Detalles del Comprobante</h3>

        <p><strong>Tour:</strong> {{ selectedPago.tour_title }}</p>
        <p><strong>Chiva:</strong> {{ selectedPago.chiva_name }}</p>
        <p><strong>Agencia:</strong> {{ selectedPago.agency_name }}</p>
        <p><strong>N° comprobante:</strong> {{ selectedPago.numero_comprobante }}</p>
        <p><strong>Boletos vendidos:</strong> {{ selectedPago.boletos_vendidos }}</p>
        <p><strong>Total pagado por agencia:</strong> ${{ selectedPago.monto_agencia }}</p>
        <p><strong>Monto para el dueño:</strong> ${{ selectedPago.monto_owner }}</p>

        <div class="mt-3 text-center">
          <p v-if="!proofUrl" class="text-sm text-gray-400">Cargando comprobante…</p>
          <img
            v-else-if="isImage(selectedPago.comprobante_path || selectedPago.comprobante_url)"
            :src="proofUrl"
            class="max-h-80 border rounded-lg mx-auto"
          />
          <a v-else :href="proofUrl" target="_blank">📄 Ver PDF</a>
        </div>

        <p v-if="feedback" class="mt-4 text-sm text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">{{ feedback }}</p>

        <div v-if="selectedPago.estado === 'pendiente'" class="flex justify-between gap-3 mt-6">
          <button
            @click="updateEstado('rechazado')"
            :disabled="working"
            class="flex-1 border border-red-200 text-red-700 px-4 py-2.5 rounded-lg font-semibold hover:bg-red-50 disabled:opacity-50"
          >
            Rechazar
          </button>
          <button
            @click="updateEstado('verificado')"
            :disabled="working"
            class="flex-[2] bg-green-600 text-white px-4 py-2.5 rounded-lg font-semibold hover:bg-green-700 disabled:opacity-50"
          >
            {{ working ? "Procesando..." : "Verificar y confirmar asientos" }}
          </button>
        </div>
        <p v-else class="mt-6 text-center text-sm text-gray-500">
          Este comprobante ya fue {{ selectedPago.estado }}.
        </p>
      </BaseCard>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

const auth = useAuthStore();

const comprobantes = ref([]);
const selectedPago = ref(null);
const loading = ref(true);
const proofUrl = ref("");
const working = ref(false);
const feedback = ref("");

const formatDate = (d) => new Date(d).toLocaleString("es-EC");

const isImage = (url) => /\.(jpe?g|png|webp)$/i.test(url ?? "");

// El bucket es privado: URL firmada desde la ruta (RLS permite leer solo
// los comprobantes de este dueño).
const openModal = async (pago) => {
  selectedPago.value = pago;
  proofUrl.value = "";
  feedback.value = "";
  if (pago.comprobante_path) {
    const { data } = await supabase.storage
      .from("comprobantes")
      .createSignedUrl(pago.comprobante_path, 3600);
    proofUrl.value = data?.signedUrl || "";
  }
  if (!proofUrl.value && pago.comprobante_url?.startsWith("http")) {
    proofUrl.value = pago.comprobante_url;
  }
};

// Una sola consulta con joins en lugar de N+1
const fetchComprobantes = async () => {
  loading.value = true;
  const { data, error } = await supabase
    .from("pending_payments")
    .select("*, assigned_chivas ( tours ( title ), chivas ( name ) ), sales_simple ( customer_name, seats, status )")
    .eq("owner_id", auth.user.id)
    .order("created_at", { ascending: false });

  if (error) {
    console.error("pending_payments:", error.message);
    comprobantes.value = [];
  } else {
    comprobantes.value = (data ?? []).map((p) => ({
      ...p,
      tour_title: p.assigned_chivas?.tours?.title || "Sin título",
      chiva_name: p.assigned_chivas?.chivas?.name || "Sin chiva",
      customer_name: p.sales_simple?.customer_name || p.agency_name,
    }));
  }
  loading.value = false;
};

// verify_pending_payment hace todo en una transacción: marca el comprobante,
// confirma o cancela la venta y pone los asientos en pagado / disponible.
const updateEstado = async (nuevoEstado) => {
  const pago = selectedPago.value;
  if (!pago || working.value) return;
  working.value = true;
  feedback.value = "";

  const { error } = await supabase.rpc("verify_pending_payment", {
    p_payment_id: pago.id,
    p_estado: nuevoEstado,
  });

  working.value = false;

  if (error) {
    console.error("verify_pending_payment:", error.message);
    feedback.value = error.message?.includes("ALREADY_PROCESSED")
      ? "Este comprobante ya fue procesado."
      : "No se pudo actualizar el comprobante.";
    return;
  }

  selectedPago.value = null;
  fetchComprobantes();
};

onMounted(fetchComprobantes);
</script>
