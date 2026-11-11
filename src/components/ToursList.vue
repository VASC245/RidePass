<template>
  <div>
    <PageHeader title="Tours"
      description="Un tour inactivo desaparece de la página pública y no se puede vender, ni siquiera desde agencias.">
      <template #actions>
        <RouterLink to="/panel/nuevo-tour"
          class="inline-flex h-10 items-center gap-2 rounded-lg bg-brand-600 px-4 text-sm font-semibold text-white transition-colors hover:bg-brand-700">
          <PhPlus :size="18" weight="bold" /> Nuevo tour
        </RouterLink>
      </template>
    </PageHeader>

    <p v-if="error" role="alert" class="mb-6 flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">
      <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ error }}
    </p>

    <!-- Cargando -->
    <div v-if="loading" class="grid gap-5 sm:grid-cols-2 xl:grid-cols-3" aria-busy="true" aria-label="Cargando tours">
      <div v-for="n in 3" :key="n" class="h-64 animate-pulse rounded-[var(--radius-card)] border border-gray-200 bg-white" />
    </div>

    <BaseCard v-else-if="tours.length === 0">
      <EmptyState :icon="PhMapTrifold" title="Todavía no tienes tours"
        description="Crea tu primer tour con su recorrido y duración. Después le asignas salidas con fecha, hora y chiva.">
        <RouterLink to="/panel/nuevo-tour"
          class="inline-flex h-10 items-center gap-2 rounded-lg bg-brand-600 px-4 text-sm font-semibold text-white transition-colors hover:bg-brand-700">
          <PhPlus :size="18" weight="bold" /> Crear tour
        </RouterLink>
      </EmptyState>
    </BaseCard>

    <ul v-else class="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">
      <li v-for="tour in tours" :key="tour.id"
        class="flex flex-col rounded-[var(--radius-card)] border border-gray-200 transition-colors"
        :class="tour.active ? 'bg-white' : 'bg-gray-50'">
        <div class="flex-1 p-5">
          <div class="flex items-start justify-between gap-3">
            <h2 class="text-lg font-semibold leading-snug text-balance" :class="tour.active ? 'text-gray-900' : 'text-gray-700'">
              {{ tour.title }}
            </h2>
            <StatusBadge :status="tour.active ? 'activo' : 'inactivo'" class="mt-0.5 shrink-0" />
          </div>
          <p class="mt-2 line-clamp-2 text-sm leading-relaxed text-gray-600">{{ tour.description || 'Sin descripción' }}</p>

          <div class="mt-4 flex items-end justify-between gap-3">
            <p class="text-gray-900">
              <span class="text-2xl font-bold tracking-[-0.01em] tabular-nums">${{ Number(tour.base_price).toFixed(2) }}</span>
              <span class="ml-1 text-sm text-gray-600">por persona</span>
            </p>
            <p class="flex items-center gap-1.5 text-sm text-gray-700">
              <PhClock :size="16" class="text-gray-500" aria-hidden="true" />
              {{ formatDuration(tour.duration) }}
            </p>
          </div>
        </div>

        <div class="space-y-1 border-t border-gray-200 px-5 py-3">
          <div class="flex min-h-11 items-center justify-between gap-3">
            <label :for="`active-${tour.id}`" class="cursor-pointer text-sm text-gray-800">Visible y a la venta</label>
            <Switch :id="`active-${tour.id}`" :value="tour.active" :busy="busy === tour.id + 'active'" @toggle="toggle(tour, 'active')" />
          </div>
          <div class="flex min-h-11 items-center justify-between gap-3">
            <label :for="`agency-${tour.id}`" class="cursor-pointer text-sm text-gray-800">Venta por agencias</label>
            <Switch :id="`agency-${tour.id}`" :value="tour.allow_agency_sales" :busy="busy === tour.id + 'allow_agency_sales'" @toggle="toggle(tour, 'allow_agency_sales')" />
          </div>
        </div>

        <div class="flex border-t border-gray-200">
          <RouterLink :to="{ path: '/panel/nuevo-tour', query: { edit: tour.id } }"
            class="flex h-11 flex-1 items-center justify-center gap-2 rounded-b-[var(--radius-card)] text-sm font-semibold text-gray-700 transition-colors hover:bg-gray-50 hover:text-gray-900">
            <PhPencilSimple :size="16" /> Editar tour
          </RouterLink>
        </div>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted, defineComponent, h } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import PageHeader from "@/components/ui/PageHeader.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import StatusBadge from "@/components/ui/StatusBadge.vue";
import { PhPlus, PhClock, PhMapTrifold, PhPencilSimple, PhWarningCircle } from "@phosphor-icons/vue";

const Switch = defineComponent({
  props: { value: Boolean, busy: Boolean },
  emits: ["toggle"],
  setup(props, { emit }) {
    return () => h("button", {
      type: "button",
      role: "switch",
      "aria-checked": props.value,
      disabled: props.busy,
      onClick: () => emit("toggle"),
      class: ["relative shrink-0 w-11 h-6 rounded-full transition-colors duration-150 disabled:opacity-50",
        props.value ? "bg-brand-600" : "bg-gray-300"],
    }, [h("span", {
      class: ["absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow-sm transition-transform duration-200 ease-out",
        props.value ? "translate-x-5" : ""],
    })]);
  },
});

// 240 → "4 h", 150 → "2 h 30 min", 45 → "45 min"
const formatDuration = (min) => {
  const m = Number(min);
  if (!m) return "Sin duración";
  const h = Math.floor(m / 60), r = m % 60;
  if (!h) return `${r} min`;
  return r ? `${h} h ${r} min` : `${h} h`;
};

const auth = useAuthStore();
const tours = ref([]);
const loading = ref(true);
const busy = ref("");
const error = ref("");

const fetchTours = async () => {
  if (!auth.user) return;
  const { data, error: err } = await supabase
    .from("tours")
    .select("id, title, description, base_price, duration, active, allow_agency_sales")
    .eq("user_id", auth.user.id)
    .order("created_at", { ascending: false });
  if (err) {
    console.error("tours:", err.message);
    error.value = "No se pudieron cargar los tours.";
  }
  tours.value = data ?? [];
  loading.value = false;
};

// Cambia un interruptor y lo revierte si la base de datos lo rechaza
const toggle = async (tour, field) => {
  busy.value = tour.id + field;
  error.value = "";
  const next = !tour[field];
  tour[field] = next;
  const { error: err } = await supabase.from("tours").update({ [field]: next }).eq("id", tour.id);
  if (err) {
    tour[field] = !next;
    error.value = "No se pudo guardar el cambio.";
    console.error("toggle tour:", err.message);
  }
  busy.value = "";
};

onMounted(fetchTours);
</script>
