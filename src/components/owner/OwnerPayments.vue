<template>
  <div>
    <PageHeader
      title="Comprobantes"
      description="Transferencias que agencias y clientes subieron para pagar sus boletos. Revisa cada comprobante antes de verificarlo: al verificar se confirman los asientos."
    >
      <template #actions>
        <div class="-mx-4 max-w-[100vw] overflow-x-auto px-4 sm:mx-0 sm:px-0">
          <SegmentedControl v-model="filter" :options="filterOptions" label="Filtrar comprobantes" class="whitespace-nowrap" />
        </div>
      </template>
    </PageHeader>

    <!-- Cargando -->
    <div v-if="loading && comprobantes.length === 0" class="space-y-3" aria-busy="true" aria-label="Cargando comprobantes">
      <div v-for="n in 3" :key="n" class="h-28 animate-pulse rounded-[var(--radius-card)] border border-gray-200 bg-white" />
    </div>

    <BaseCard v-else-if="visible.length === 0">
      <EmptyState
        :icon="PhReceipt"
        :title="filter === 'pendiente' ? 'No tienes comprobantes por revisar' : 'No hay comprobantes en esta vista'"
        :description="filter === 'pendiente'
          ? 'Cuando alguien pague por transferencia y suba su comprobante, aparecerá aquí para que lo verifiques.'
          : 'Cambia el filtro para ver otros comprobantes.'"
      />
    </BaseCard>

    <ul v-else class="space-y-3">
      <li
        v-for="pago in visible"
        :key="pago.id"
        class="rounded-[var(--radius-card)] border bg-white"
        :class="pago.estado === 'pendiente' ? 'border-warn-200' : 'border-gray-200'"
      >
        <div class="flex flex-col gap-4 p-4 sm:flex-row sm:items-center sm:p-5">
          <div class="flex min-w-0 flex-1 items-start gap-4 sm:items-center">
            <!-- Miniatura del comprobante -->
            <button
              type="button"
              class="relative flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-gray-200 bg-gray-50 text-gray-500 transition-colors hover:border-gray-400 sm:size-20"
              :aria-label="`Ver comprobante ${pago.numero_comprobante || ''}`"
              @click="openModal(pago)"
            >
              <img v-if="thumbs[pago.id] && isImage(pago.comprobante_path || pago.comprobante_url)"
                :src="thumbs[pago.id]" alt="" class="size-full object-cover" loading="lazy" />
              <span v-else class="flex flex-col items-center gap-1 text-xs font-medium">
                <PhFileText :size="24" />
                {{ isPdf(pago) ? 'PDF' : 'Ver' }}
              </span>
            </button>

            <!-- Datos -->
            <div class="min-w-0 flex-1">
              <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
                <p class="truncate font-semibold text-gray-900">{{ pago.customer_name || 'Sin nombre' }}</p>
                <StatusBadge :status="pago.estado" />
              </div>
              <p class="mt-1 text-sm text-gray-700">
                {{ pago.tour_title }} <span class="text-gray-400" aria-hidden="true">·</span> {{ pago.chiva_name }}
              </p>
              <p class="mt-0.5 text-sm text-gray-600">{{ metaLine(pago) }}</p>
            </div>
          </div>

          <!-- Monto y acción -->
          <div class="flex items-center justify-between gap-4 border-t border-gray-100 pt-3 sm:border-0 sm:pt-0">
            <div class="sm:w-28 sm:text-right">
              <p class="text-xl font-bold text-gray-900 tabular-nums">{{ money(pago.monto_owner) }}</p>
              <p class="text-xs text-gray-600">
                <template v-if="Number(pago.monto_agencia) > 0">Agencia <span class="tabular-nums">{{ money(pago.monto_agencia) }}</span></template>
                <template v-else>Para ti</template>
              </p>
            </div>
            <BaseButton v-if="pago.estado === 'pendiente'" variant="primary" @click="openModal(pago)">
              <PhMagnifyingGlass :size="18" /> Revisar y verificar
            </BaseButton>
            <BaseButton v-else variant="secondary" @click="openModal(pago)">
              Ver comprobante
            </BaseButton>
          </div>
        </div>
      </li>
    </ul>

    <!-- Detalle del comprobante -->
    <Transition name="sheet">
      <div v-if="selectedPago" class="fixed inset-0 z-50 flex items-end justify-center sm:items-center sm:p-6"
        role="dialog" aria-modal="true" aria-labelledby="proof-title">
        <div class="sheet-backdrop absolute inset-0 bg-black/50" @click="closeModal" />

        <div class="sheet-panel relative flex max-h-[92dvh] w-full max-w-2xl flex-col overflow-hidden rounded-t-2xl bg-white sm:rounded-[var(--radius-card)]">
          <header class="flex items-start justify-between gap-3 border-b border-gray-200 px-5 py-4">
            <div class="min-w-0">
              <h2 id="proof-title" class="text-lg font-semibold text-gray-900">Comprobante {{ selectedPago.numero_comprobante ? 'N.º ' + selectedPago.numero_comprobante : '' }}</h2>
              <p class="text-sm text-gray-600">{{ formatDate(selectedPago.created_at) }}</p>
            </div>
            <button type="button" class="-mr-2 inline-flex size-10 items-center justify-center rounded-lg text-gray-600 hover:bg-gray-100" aria-label="Cerrar" @click="closeModal">
              <PhX :size="20" />
            </button>
          </header>

          <div class="grid flex-1 gap-5 overflow-y-auto p-5 md:grid-cols-[1.2fr_1fr]">
            <!-- Imagen -->
            <div class="flex min-h-48 items-center justify-center rounded-lg border border-gray-200 bg-gray-50 p-2">
              <p v-if="!proofUrl" class="text-sm text-gray-600">Cargando comprobante…</p>
              <a v-else-if="isImage(selectedPago.comprobante_path || selectedPago.comprobante_url)"
                :href="proofUrl" target="_blank" rel="noopener" class="block" title="Abrir en tamaño completo">
                <img :src="proofUrl" alt="Comprobante de transferencia" class="mx-auto max-h-[50dvh] rounded-md object-contain" />
              </a>
              <a v-else :href="proofUrl" target="_blank" rel="noopener"
                class="inline-flex h-11 items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 text-sm font-semibold text-gray-800 hover:bg-gray-50">
                <PhFileText :size="18" /> Abrir PDF
              </a>
            </div>

            <!-- Datos -->
            <dl class="space-y-3 text-sm">
              <div v-for="row in detailRows" :key="row.label" class="flex justify-between gap-4 border-b border-gray-100 pb-3 last:border-0">
                <dt class="text-gray-600">{{ row.label }}</dt>
                <dd class="text-right font-medium text-gray-900" :class="row.money && 'tabular-nums'">{{ row.value }}</dd>
              </div>
              <div class="flex items-center justify-between gap-4 pt-1">
                <dt class="text-gray-600">Estado</dt>
                <dd><StatusBadge :status="selectedPago.estado" /></dd>
              </div>
            </dl>
          </div>

          <footer class="border-t border-gray-200 px-5 py-4">
            <p v-if="feedback" class="mb-3 flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-3 py-2 text-sm text-bad-700" role="alert">
              <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ feedback }}
            </p>

            <div v-if="selectedPago.estado === 'pendiente'" class="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
              <BaseButton v-if="!confirmReject" variant="ghost" size="lg" class="text-bad-700 hover:bg-bad-50" :disabled="working" @click="confirmReject = true">
                Rechazar comprobante
              </BaseButton>
              <BaseButton v-else variant="danger" size="lg" :loading="working && pendingAction === 'rechazado'" :disabled="working" @click="updateEstado('rechazado')">
                Sí, rechazar y liberar asientos
              </BaseButton>
              <BaseButton variant="success" size="lg" :loading="working && pendingAction === 'verificado'" :disabled="working" @click="updateEstado('verificado')">
                <PhCheckCircle v-if="!working" :size="20" /> Verificar pago
              </BaseButton>
            </div>
            <p v-else class="text-sm text-gray-600">
              Este comprobante ya fue {{ selectedPago.estado }}. No necesitas hacer nada más.
            </p>
            <p v-if="confirmReject && selectedPago.estado === 'pendiente'" class="mt-2 text-sm text-gray-600 sm:text-right">
              Al rechazar, la venta se cancela y los asientos vuelven a estar disponibles.
            </p>
          </footer>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import PageHeader from "@/components/ui/PageHeader.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import StatusBadge from "@/components/ui/StatusBadge.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import SegmentedControl from "@/components/ui/SegmentedControl.vue";
import { PhReceipt, PhFileText, PhMagnifyingGlass, PhX, PhCheckCircle, PhWarningCircle } from "@phosphor-icons/vue";

const auth = useAuthStore();

const comprobantes = ref([]);
const selectedPago = ref(null);
const loading = ref(true);
const proofUrl = ref("");
const working = ref(false);
const pendingAction = ref("");
const confirmReject = ref(false);
const feedback = ref("");
const thumbs = ref({});

const filter = ref("pendiente");
const counts = computed(() => comprobantes.value.reduce((acc, p) => {
  acc[p.estado] = (acc[p.estado] ?? 0) + 1;
  return acc;
}, {}));
const filterOptions = computed(() => [
  { label: `Pendientes${counts.value.pendiente ? ` (${counts.value.pendiente})` : ""}`, value: "pendiente" },
  { label: "Verificados", value: "verificado" },
  { label: "Rechazados",  value: "rechazado" },
  { label: "Todos",       value: "todos" },
]);
const visible = computed(() =>
  filter.value === "todos" ? comprobantes.value : comprobantes.value.filter((p) => p.estado === filter.value));

const formatDate = (d) => new Date(d).toLocaleString("es-EC", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
const money = (v) => (v == null || v === "" ? "Sin dato" : `$${Number(v).toFixed(2)}`);

const metaLine = (p) => [
  formatDate(p.created_at),
  p.numero_comprobante && `N.º ${p.numero_comprobante}`,
  p.boletos_vendidos && `${p.boletos_vendidos} ${Number(p.boletos_vendidos) === 1 ? "boleto" : "boletos"}`,
].filter(Boolean).join(" · ");

const isImage = (url) => /\.(jpe?g|png|webp)$/i.test(url ?? "");
const isPdf = (p) => /\.pdf$/i.test(p.comprobante_path || p.comprobante_url || "");

const detailRows = computed(() => {
  const p = selectedPago.value;
  if (!p) return [];
  return [
    { label: "Cliente",          value: p.customer_name || "Sin nombre" },
    { label: "Agencia",          value: p.agency_name || "Venta directa" },
    { label: "Tour",             value: p.tour_title },
    { label: "Chiva",            value: p.chiva_name },
    { label: "Boletos",          value: p.boletos_vendidos ?? "Sin dato" },
    ...(Number(p.monto_agencia) > 0 ? [{ label: "Monto de la agencia", value: money(p.monto_agencia), money: true }] : []),
    { label: "Monto para ti",    value: money(p.monto_owner), money: true },
  ];
});

// El bucket es privado: URL firmada desde la ruta (RLS permite leer solo
// los comprobantes de este dueño).
const openModal = async (pago) => {
  selectedPago.value = pago;
  proofUrl.value = thumbs.value[pago.id] || "";
  feedback.value = "";
  confirmReject.value = false;
  if (!proofUrl.value && pago.comprobante_path) {
    const { data } = await supabase.storage
      .from("comprobantes")
      .createSignedUrl(pago.comprobante_path, 3600);
    proofUrl.value = data?.signedUrl || "";
  }
  if (!proofUrl.value && pago.comprobante_url?.startsWith("http")) {
    proofUrl.value = pago.comprobante_url;
  }
};

const closeModal = () => {
  if (working.value) return;
  selectedPago.value = null;
};

// Miniaturas: una sola llamada firmada para todos los comprobantes con ruta
const loadThumbs = async () => {
  const withPath = comprobantes.value.filter((p) => p.comprobante_path);
  const map = {};
  if (withPath.length) {
    const { data } = await supabase.storage
      .from("comprobantes")
      .createSignedUrls(withPath.map((p) => p.comprobante_path), 3600);
    (data ?? []).forEach((d, i) => { if (d?.signedUrl) map[withPath[i].id] = d.signedUrl; });
  }
  comprobantes.value.forEach((p) => {
    if (!map[p.id] && p.comprobante_url?.startsWith("http")) map[p.id] = p.comprobante_url;
  });
  thumbs.value = map;
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
    // Si no hay nada por revisar, abrir en "Todos" para no mostrar una lista vacía
    if (!comprobantes.value.some((p) => p.estado === "pendiente") && comprobantes.value.length) {
      filter.value = "todos";
    }
  }
  loading.value = false;
  loadThumbs();
};

// verify_pending_payment hace todo en una transacción: marca el comprobante,
// confirma o cancela la venta y pone los asientos en pagado / disponible.
const updateEstado = async (nuevoEstado) => {
  const pago = selectedPago.value;
  if (!pago || working.value) return;
  working.value = true;
  pendingAction.value = nuevoEstado;
  feedback.value = "";

  const { error } = await supabase.rpc("verify_pending_payment", {
    p_payment_id: pago.id,
    p_estado: nuevoEstado,
  });

  working.value = false;
  pendingAction.value = "";

  if (error) {
    console.error("verify_pending_payment:", error.message);
    feedback.value = error.message?.includes("ALREADY_PROCESSED")
      ? "Este comprobante ya fue procesado."
      : "No se pudo actualizar el comprobante. Intenta de nuevo.";
    return;
  }

  selectedPago.value = null;
  fetchComprobantes();
};

// Escape cierra el detalle y se bloquea el scroll del fondo mientras está abierto
const onKey = (e) => { if (e.key === "Escape") closeModal(); };
watch(selectedPago, (open) => {
  document.body.style.overflow = open ? "hidden" : "";
  if (open) window.addEventListener("keydown", onKey);
  else window.removeEventListener("keydown", onKey);
});
onBeforeUnmount(() => {
  document.body.style.overflow = "";
  window.removeEventListener("keydown", onKey);
});

onMounted(fetchComprobantes);
</script>

<style scoped>
.sheet-enter-active, .sheet-leave-active { transition: opacity 200ms var(--ease-out-quart); }
.sheet-enter-active .sheet-panel, .sheet-leave-active .sheet-panel { transition: transform 240ms var(--ease-out-quart); }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
.sheet-enter-from .sheet-panel, .sheet-leave-to .sheet-panel { transform: translateY(24px); }
</style>
