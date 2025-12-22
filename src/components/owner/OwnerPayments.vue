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
          <img
            v-if="isImage(selectedPago.comprobante_url)"
            :src="selectedPago.comprobante_url"
            class="max-h-80 border rounded-lg mx-auto"
          />
          <a v-else :href="selectedPago.comprobante_url" target="_blank">📄 Ver PDF</a>
        </div>

        <div class="flex justify-between mt-6">
          <button
            @click="updateEstado('verificado')"
            class="bg-green-600 text-white px-4 py-2 rounded-lg"
          >
            ✅ Verificar
          </button>

          <button
            @click="updateEstado('rechazado')"
            class="bg-red-600 text-white px-4 py-2 rounded-lg"
          >
            ❌ Rechazar
          </button>
        </div>
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

const formatDate = (d) => new Date(d).toLocaleString();

const isImage = (url) =>
  url?.toLowerCase().endsWith(".jpg") ||
  url?.toLowerCase().endsWith(".jpeg") ||
  url?.toLowerCase().endsWith(".png");

// ABRIR MODAL
const openModal = (pago) => (selectedPago.value = pago);

// CARGAR COMPROBANTES DEL DUEÑO
const fetchComprobantes = async () => {
  loading.value = true;

  const { data: assigned } = await supabase
    .from("assigned_chivas")
    .select("id, tour_id, chiva_id")
    .eq("user_id", auth.user.id);

  if (!assigned?.length) {
    comprobantes.value = [];
    loading.value = false;
    return;
  }

  const ids = assigned.map((x) => x.id);

  const { data: pagos } = await supabase
    .from("pending_payments")
    .select("*")
    .in("assigned_chiva_id", ids)
    .order("created_at", { ascending: false });

  const enriched = [];

  for (const pago of pagos) {
    const match = assigned.find((a) => a.id === pago.assigned_chiva_id);

    const { data: tour } = await supabase
      .from("tours")
      .select("title")
      .eq("id", match?.tour_id)
      .maybeSingle();

    const { data: chiva } = await supabase
      .from("chivas")
      .select("name")
      .eq("id", match?.chiva_id)
      .maybeSingle();

    enriched.push({
      ...pago,
      tour_title: tour?.title || "Sin título",
      chiva_name: chiva?.name || "Sin chiva",
    });
  }

  comprobantes.value = enriched;
  loading.value = false;
};

// CAMBIAR ESTADO Y REGISTRAR BALANCE
const updateEstado = async (nuevoEstado) => {
  const pago = selectedPago.value;

  if (!pago) return;

  await supabase.from("pending_payments")
    .update({ estado: nuevoEstado })
    .eq("id", pago.id);

  if (nuevoEstado === "verificado") {
    // INSERT OWNER BALANCE
    await supabase.from("owner_balance").insert([
      {
        owner_id: pago.owner_id,
        assigned_chiva_id: pago.assigned_chiva_id,
        comprobante_id: pago.id,
        boletos_vendidos: pago.boletos_vendidos,
        monto_total: pago.monto_owner,
        created_at: new Date(),
      },
    ]);

    // INSERT AGENCY BALANCE
    await supabase.from("agency_balance").insert([
      {
        agency_id: pago.agency_id,
        assigned_chiva_id: pago.assigned_chiva_id,
        comprobante_id: pago.id,
        boletos_vendidos: pago.boletos_vendidos,
        monto_total: pago.monto_agencia - pago.monto_owner,
        created_at: new Date(),
      },
    ]);

    alert("✅ Comprobante verificado y registrado en balances.");
  } else {
    alert("❌ Comprobante rechazado.");
  }

  selectedPago.value = null;
  fetchComprobantes();
};

onMounted(fetchComprobantes);
</script>
