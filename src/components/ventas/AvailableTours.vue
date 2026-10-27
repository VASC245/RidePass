<template>
  <div>
    <PageHeader title="Tours disponibles"
      description="Salidas programadas de las chivas que venden por agencia. Revisa los asientos o empieza una venta." />

    <div v-if="loading" class="space-y-3" aria-busy="true">
      <div v-for="n in 3" :key="n" class="h-24 animate-pulse rounded-[var(--radius-card)] bg-gray-100" />
    </div>

    <p v-else-if="loadError" role="alert" class="flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">
      <PhWarningCircle :size="18" class="mt-px shrink-0" />
      <span>{{ loadError }} <button type="button" class="font-semibold underline underline-offset-2" @click="fetchTours">Reintentar</button></span>
    </p>

    <BaseCard v-else-if="assignedTours.length === 0">
      <EmptyState :icon="PhCalendarBlank" title="No hay salidas programadas"
        description="Cuando un dueño programe una salida y permita la venta por agencias, aparecerá aquí." />
    </BaseCard>

    <div v-else class="space-y-8">
      <section v-for="group in groups" :key="group.key" :aria-label="group.label">
        <h2 class="mb-3 flex items-baseline gap-2 text-sm font-semibold text-gray-900">
          <span>{{ group.label }}</span>
          <span class="font-normal text-gray-600">{{ group.items.length }} {{ group.items.length === 1 ? 'salida' : 'salidas' }}</span>
        </h2>

        <ul class="overflow-hidden rounded-[var(--radius-card)] border border-gray-200 bg-white divide-y divide-gray-200">
          <li v-for="tour in group.items" :key="tour.id"
            class="grid grid-cols-[4.5rem_1fr] gap-x-4 gap-y-3 p-4 sm:grid-cols-[5.5rem_1fr_auto] sm:items-center sm:p-5"
            :class="isPast(tour.departure_at) && 'bg-gray-50'">
            <!-- Hora de salida -->
            <div class="row-span-2 sm:row-span-1">
              <p class="text-2xl font-bold tracking-[-0.02em] text-gray-900 tabular-nums">{{ formatTime(tour.departure_at) }}</p>
              <p class="text-xs text-gray-600">{{ convertirDuracion(tour.tours.duration) }}</p>
            </div>

            <!-- Tour -->
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2">
                <p class="text-base font-semibold text-gray-900">{{ tour.tours.title }}</p>
                <StatusBadge v-if="isPast(tour.departure_at)" tone="neutral">Ya salió</StatusBadge>
              </div>
              <p class="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-gray-600">
                <span class="inline-flex items-center gap-1.5"><PhBus :size="16" class="text-gray-500" />{{ tour.chivas?.name ?? 'Chiva sin nombre' }}</span>
                <span class="inline-flex items-center gap-1.5 font-semibold text-gray-900 tabular-nums">
                  ${{ Number(tour.tours.base_price).toFixed(2) }}<span class="font-normal text-gray-600">por persona</span>
                </span>
              </p>
            </div>

            <!-- Acciones -->
            <div class="col-span-2 grid grid-cols-2 gap-2 sm:col-span-1 sm:col-start-3 sm:flex">
              <BaseButton variant="secondary" class="h-11 sm:h-10" @click="openSeatModal(tour.id)">
                <PhArmchair :size="18" /> Ver asientos
              </BaseButton>
              <RouterLink v-if="!isPast(tour.departure_at)"
                :to="{ name: 'SellPage', query: { assignedId: tour.id } }"
                class="inline-flex h-11 items-center justify-center gap-2 rounded-lg bg-brand-600 px-4 text-sm font-semibold text-white transition-colors hover:bg-brand-700 sm:h-10">
                <PhTicket :size="18" /> Vender
              </RouterLink>
            </div>
          </li>
        </ul>
      </section>
    </div>

    <!-- Mapa de asientos -->
    <Transition name="dialog">
      <div v-if="showSeatsModal" class="fixed inset-0 z-50 flex items-end justify-center sm:items-center sm:p-6"
        role="dialog" aria-modal="true" aria-labelledby="seat-dialog-title">
        <div class="dialog-backdrop absolute inset-0 bg-black/45" @click="closeSeatModal" />
        <div class="dialog-panel relative max-h-[92dvh] w-full overflow-y-auto rounded-t-[var(--radius-card)] bg-white p-5 sm:max-w-lg sm:rounded-[var(--radius-card)] sm:p-6">
          <div class="mb-4 flex items-start justify-between gap-4">
            <div>
              <h2 id="seat-dialog-title" class="text-lg font-semibold text-gray-900">Asientos</h2>
              <p v-if="selectedTour" class="text-sm text-gray-600">
                {{ selectedTour.tours.title }} · {{ formatDate(selectedTour.departure_at) }}
              </p>
            </div>
            <button type="button" class="-mr-2 -mt-1 inline-flex size-10 items-center justify-center rounded-lg text-gray-600 hover:bg-gray-100 hover:text-gray-900"
              aria-label="Cerrar" @click="closeSeatModal">
              <PhX :size="20" />
            </button>
          </div>
          <SeatGrid :assignedChivaId="selectedTourId" :readonly="true" />
        </div>
      </div>
    </Transition>
  </div>
</template>


<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import dayjs from "dayjs";
import SeatGrid from "@/components/asientos/SeatGrid.vue";
import PageHeader from "@/components/ui/PageHeader.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import StatusBadge from "@/components/ui/StatusBadge.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import { PhBus, PhArmchair, PhTicket, PhX, PhCalendarBlank, PhWarningCircle } from "@phosphor-icons/vue";

const auth = useAuthStore();

const assignedTours = ref([]);
const showSeatsModal = ref(false);
const selectedTourId = ref(null);
const loading = ref(true);
const loadError = ref("");

// Mismo tope que la página pública: solo próximas salidas, no todo el historial.
const LIST_LIMIT = 200;

const selectedTour = computed(() => assignedTours.value.find((t) => t.id === selectedTourId.value));

const onKey = (e) => { if (e.key === "Escape") closeSeatModal(); };
const openSeatModal = (tourId) => {
  selectedTourId.value = tourId;
  showSeatsModal.value = true;
  window.addEventListener("keydown", onKey);
};
const closeSeatModal = () => {
  showSeatsModal.value = false;
  selectedTourId.value = null;
  window.removeEventListener("keydown", onKey);
};
onBeforeUnmount(() => window.removeEventListener("keydown", onKey));

// Cargar salidas programadas: próximas, con ventas abiertas y de tours
// activos que permiten la venta por agencias (mismos filtros que toursStore).
const fetchTours = async () => {
  loading.value = true;
  loadError.value = "";
  try {
    let query = supabase
      .from("assigned_chivas")
      .select(`
        id,
        departure_at,
        status,
        sales_open,
        tours!inner (
          id,
          title,
          duration,
          base_price,
          user_id,
          active,
          allow_agency_sales
        ),
        chivas (
          id,
          name,
          user_id
        )
      `)
      .in("status", ["pendiente", "en_curso"])
      .eq("sales_open", true)
      .eq("tours.active", true)
      .eq("tours.allow_agency_sales", true)
      .gte("departure_at", new Date(Date.now() - 30 * 60_000).toISOString())
      .order("departure_at", { ascending: true })
      .limit(LIST_LIMIT);

    // Si es dueño, solo sus tours
    if (auth.user && auth.user.role === "dueño") {
      query = query.eq("tours.user_id", auth.user.id);
    }

    const { data, error } = await query;

    if (error) throw error;

    // Mostrar solo tours válidos
    assignedTours.value = (data || []).filter(
      (item) => item.tours?.title && item.tours?.base_price > 0
    );
  } catch (err) {
    console.error("Error al cargar tours asignados:", err);
    assignedTours.value = [];
    loadError.value = "No pudimos cargar las salidas. Revisa tu conexión e intenta de nuevo.";
  } finally {
    loading.value = false;
  }
};

const formatDate = (dateStr) => {
  return dayjs(dateStr).format("DD/MM/YYYY, HH:mm");
};

const formatTime = (dateStr) => dayjs(dateStr).format("HH:mm");
const isPast = (dateStr) => dayjs(dateStr).isBefore(dayjs());

// Agrupar por día de salida: próximas primero, las pasadas al final
const dayLabel = (d) => {
  const day = dayjs(d).startOf("day");
  const today = dayjs().startOf("day");
  if (day.isSame(today)) return "Hoy";
  if (day.isSame(today.add(1, "day"))) return "Mañana";
  const label = new Date(d).toLocaleDateString("es-EC", { weekday: "long", day: "numeric", month: "long" });
  return label.charAt(0).toUpperCase() + label.slice(1);
};

const groups = computed(() => {
  const sorted = [...assignedTours.value].sort((a, b) => {
    const pa = isPast(a.departure_at), pb = isPast(b.departure_at);
    if (pa !== pb) return pa ? 1 : -1;
    return pa
      ? new Date(b.departure_at) - new Date(a.departure_at)
      : new Date(a.departure_at) - new Date(b.departure_at);
  });
  const map = new Map();
  for (const t of sorted) {
    const key = dayjs(t.departure_at).format("YYYY-MM-DD");
    if (!map.has(key)) map.set(key, { key, label: dayLabel(t.departure_at), items: [] });
    map.get(key).items.push(t);
  }
  return [...map.values()];
});

const convertirDuracion = (minutos) => {
  if (!minutos) return "Sin duración";
  const horas = Math.floor(minutos / 60);
  const mins = minutos % 60;
  if (horas > 0 && mins > 0) return `${horas}h ${mins}m`;
  if (horas > 0) return `${horas}h`;
  return `${mins}m`;
};

onMounted(fetchTours);
</script>

<style scoped>
.dialog-enter-active, .dialog-leave-active { transition: opacity 200ms ease-out; }
.dialog-enter-active .dialog-panel, .dialog-leave-active .dialog-panel { transition: transform 240ms var(--ease-out-quart); }
.dialog-enter-from, .dialog-leave-to { opacity: 0; }
.dialog-enter-from .dialog-panel, .dialog-leave-to .dialog-panel { transform: translateY(16px); }
</style>
