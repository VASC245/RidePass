<template>
  <div>
    <PageHeader title="Salidas"
      description="Cada salida abre o cierra sus ventas por separado. Cerrar una salida no afecta a los boletos ya vendidos." />

    <div class="space-y-6">
      <!-- Formulario -->
      <BaseCard :variant="editingId ? 'highlight' : 'default'">
        <template #title>{{ editingId ? 'Editar salida' : 'Programar salida' }}</template>
        <form class="space-y-4" @submit.prevent="saveSalida">
          <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr_0.8fr]">
            <div>
              <label for="salida-tour" class="field-label">Tour</label>
              <select id="salida-tour" v-model="selectedTour" class="field-control">
                <option disabled value="">Elige un tour</option>
                <option v-for="tour in tours" :key="tour.id" :value="tour.id">
                  {{ tour.title }}{{ tour.active ? '' : ' (inactivo)' }}
                </option>
              </select>
            </div>
            <div>
              <label for="salida-chiva" class="field-label">Chiva</label>
              <select id="salida-chiva" v-model="selectedChiva" class="field-control">
                <option disabled value="">Elige una chiva</option>
                <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">{{ chiva.name }}</option>
              </select>
            </div>
            <div>
              <label for="salida-fecha" class="field-label">Fecha</label>
              <input id="salida-fecha" v-model="departureDate" type="date" :min="todayStr" class="field-control tabular-nums" />
            </div>
            <div>
              <label for="salida-hora" class="field-label">Hora</label>
              <input id="salida-hora" v-model="departureTime" type="time" class="field-control tabular-nums" />
            </div>
          </div>

          <p v-if="formError" role="alert" class="flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-3.5 py-3 text-sm text-bad-700">
            <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ formError }}
          </p>

          <div class="flex flex-wrap items-center justify-end gap-2">
            <BaseButton v-if="editingId" variant="ghost" @click="cancelEdit">Cancelar</BaseButton>
            <BaseButton type="submit" :loading="saving">{{ editingId ? 'Guardar cambios' : 'Programar salida' }}</BaseButton>
          </div>
        </form>
      </BaseCard>

      <p v-if="listError" role="alert" class="flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">
        <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ listError }}
      </p>

      <!-- Salidas agrupadas por día -->
      <div v-if="salidas.length > 0" class="space-y-6">
        <section v-for="day in salidasByDay" :key="day.key">
          <h2 class="mb-2 flex items-baseline gap-2 px-1 text-sm font-semibold text-gray-900">
            <span class="inline-block first-letter:uppercase">{{ day.label }}</span>
            <span class="font-normal text-gray-600 tabular-nums">{{ day.items.length }} {{ day.items.length === 1 ? 'salida' : 'salidas' }}</span>
          </h2>
          <ul class="divide-y divide-gray-100 overflow-hidden rounded-[var(--radius-card)] border border-gray-200 bg-white">
            <li v-for="salida in day.items" :key="salida.id"
              class="flex flex-wrap items-center gap-x-4 gap-y-3 px-4 py-4 sm:flex-nowrap sm:px-5"
              :class="editingId === salida.id && 'bg-brand-50'">
              <p class="w-14 shrink-0 text-lg font-bold text-gray-900 tabular-nums">{{ formatTime(salida.departure_at) }}</p>

              <div class="min-w-0 flex-1 basis-32">
                <p class="line-clamp-2 font-semibold text-gray-900">{{ salida.tours?.title ?? 'Tour eliminado' }}</p>
                <p class="flex items-center gap-1.5 text-sm text-gray-600">
                  <PhBus :size="15" aria-hidden="true" /> {{ salida.chivas?.name ?? 'Sin chiva' }}
                </p>
              </div>

              <StatusBadge :tone="statusOf(salida).tone" class="order-3 shrink-0 sm:order-none">{{ statusOf(salida).label }}</StatusBadge>

              <button type="button" :disabled="busy === salida.id" :aria-pressed="salida.sales_open"
                :title="salida.sales_open ? 'Cerrar ventas de esta salida' : 'Abrir ventas de esta salida'"
                class="order-3 inline-flex h-9 shrink-0 items-center gap-2 rounded-full border px-3 text-xs font-semibold transition-colors disabled:opacity-50 sm:order-none"
                :class="salida.sales_open
                  ? 'border-ok-200 bg-ok-50 text-ok-700 hover:bg-white'
                  : 'border-gray-300 bg-gray-100 text-gray-700 hover:bg-white'"
                @click="toggleSales(salida)">
                <component :is="salida.sales_open ? PhLockOpen : PhLock" :size="14" aria-hidden="true" />
                {{ salida.sales_open ? 'Ventas abiertas' : 'Ventas cerradas' }}
              </button>

              <div class="order-2 -mr-1 flex shrink-0 items-center sm:order-none">
                <button type="button" class="icon-btn" :aria-label="`Editar salida de ${salida.tours?.title ?? 'tour'}`" title="Editar" @click="editSalida(salida)">
                  <PhPencilSimple :size="18" />
                </button>
                <button type="button" class="icon-btn icon-btn--danger" :aria-label="`Eliminar salida de ${salida.tours?.title ?? 'tour'}`" title="Eliminar" @click="deleteSalida(salida)">
                  <PhTrash :size="18" />
                </button>
              </div>
            </li>
          </ul>
        </section>
      </div>

      <BaseCard v-else>
        <EmptyState :icon="PhCalendarBlank" title="No hay salidas programadas"
          description="Elige tour, chiva, fecha y hora arriba. Cada salida aparece aquí y en la página pública mientras tenga ventas abiertas." />
      </BaseCard>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import PageHeader from "@/components/ui/PageHeader.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import StatusBadge from "@/components/ui/StatusBadge.vue";
import { PhBus, PhPencilSimple, PhTrash, PhLock, PhLockOpen, PhCalendarBlank, PhWarningCircle } from "@phosphor-icons/vue";

const auth = useAuthStore();

const pad = (n) => String(n).padStart(2, "0");
const localDateStr = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
const localTimeStr = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}`;
const todayStr = localDateStr(new Date());

const selectedTour = ref("");
const selectedChiva = ref("");
const departureDate = ref(todayStr);
const departureTime = ref("");
const tours = ref([]);
const chivas = ref([]);
const salidas = ref([]);
const editingId = ref(null);
const saving = ref(false);
const busy = ref("");
const formError = ref("");
const listError = ref("");

const formatTime = (d) => localTimeStr(new Date(d));

const STATUS = {
  pendiente:  { tone: "info",    label: "Programada" },
  en_curso:   { tone: "success", label: "En curso" },
  finalizado: { tone: "neutral", label: "Finalizada" },
};
const statusOf = (salida) => STATUS[salida.status] ?? { tone: "neutral", label: salida.status };

// Agrupa por día local: "Hoy", "Mañana" o "lunes 14 de sept."
const salidasByDay = computed(() => {
  const today = new Date(); today.setHours(0, 0, 0, 0);
  const groups = new Map();
  for (const s of salidas.value) {
    const d = new Date(s.departure_at);
    const key = localDateStr(d);
    if (!groups.has(key)) {
      const day = new Date(d); day.setHours(0, 0, 0, 0);
      const diff = Math.round((day - today) / 86_400_000);
      const label = diff === 0 ? "Hoy" : diff === 1 ? "Mañana" : diff === -1 ? "Ayer"
        : d.toLocaleDateString("es-EC", { weekday: "long", day: "numeric", month: "long" });
      groups.set(key, { key, label, items: [] });
    }
    groups.get(key).items.push(s);
  }
  return [...groups.values()];
});

const fetchTours = async () => {
  if (!auth.user) return;
  const { data } = await supabase
    .from("tours").select("id, title, active").eq("user_id", auth.user.id).order("title");
  tours.value = data ?? [];
};

const fetchChivas = async () => {
  if (!auth.user) return;
  const { data } = await supabase.from("chivas").select("id, name").eq("user_id", auth.user.id).order("name");
  chivas.value = data ?? [];
};

const fetchSalidas = async () => {
  if (!auth.user) return;
  const { data, error } = await supabase
    .from("assigned_chivas")
    .select("id, departure_at, status, sales_open, tours (id, title), chivas (id, name)")
    .eq("owner_id", auth.user.id)
    .gte("departure_at", new Date(Date.now() - 24 * 3600_000).toISOString())
    .order("departure_at", { ascending: true });
  if (error) {
    console.error("salidas:", error.message);
    listError.value = "No se pudieron cargar las salidas.";
  }
  salidas.value = data ?? [];
};

// Fecha + hora en horario local del navegador → ISO
const buildDeparture = () => new Date(`${departureDate.value}T${departureTime.value}:00`);

const saveSalida = async () => {
  formError.value = "";
  if (!selectedTour.value || !selectedChiva.value || !departureDate.value || !departureTime.value) {
    formError.value = "Completa tour, chiva, fecha y hora.";
    return;
  }
  const departure = buildDeparture();
  if (Number.isNaN(departure.getTime())) { formError.value = "Fecha u hora inválida."; return; }
  if (!editingId.value && departure.getTime() < Date.now() - 5 * 60_000) {
    formError.value = "La salida no puede estar en el pasado.";
    return;
  }

  saving.value = true;
  const payload = {
    tour_id: selectedTour.value,
    chiva_id: selectedChiva.value,
    departure_at: departure.toISOString(),
  };
  const res = editingId.value
    ? await supabase.from("assigned_chivas").update(payload).eq("id", editingId.value)
    : await supabase.from("assigned_chivas").insert([{ ...payload, owner_id: auth.user.id, status: "pendiente" }]);
  saving.value = false;

  if (res.error) {
    console.error("salida:", res.error.message);
    formError.value = "No se pudo guardar la salida.";
    return;
  }
  cancelEdit();
  fetchSalidas();
};

const editSalida = (salida) => {
  editingId.value = salida.id;
  selectedTour.value = salida.tours?.id || "";
  selectedChiva.value = salida.chivas?.id || "";
  const d = new Date(salida.departure_at);
  departureDate.value = localDateStr(d);
  departureTime.value = localTimeStr(d);
};

// Abre o cierra las ventas de una salida. Se aplica en la base de datos:
// una salida cerrada rechaza cualquier reserva aunque venga de la web.
const toggleSales = async (salida) => {
  busy.value = salida.id;
  const next = !salida.sales_open;
  salida.sales_open = next;
  const { error } = await supabase.from("assigned_chivas").update({ sales_open: next }).eq("id", salida.id);
  if (error) {
    salida.sales_open = !next;
    listError.value = "No se pudo cambiar el estado de ventas.";
    console.error("toggle sales:", error.message);
  }
  busy.value = "";
};

const deleteSalida = async (salida) => {
  if (!confirm(`¿Eliminar la salida de ${salida.tours?.title ?? "este tour"}? Si tiene ventas, se perderá el historial.`)) return;
  const { error } = await supabase.from("assigned_chivas").delete().eq("id", salida.id);
  if (error) {
    listError.value = "No se pudo eliminar: la salida tiene ventas asociadas. Ciérrala en lugar de borrarla.";
    return;
  }
  fetchSalidas();
};

const cancelEdit = () => {
  editingId.value = null;
  selectedTour.value = "";
  selectedChiva.value = "";
  departureDate.value = todayStr;
  departureTime.value = "";
  formError.value = "";
};

onMounted(() => {
  fetchTours();
  fetchChivas();
  fetchSalidas();
});
</script>

<style scoped>
.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem; height: 2.25rem;
  border-radius: 8px;
  color: var(--color-gray-600);
  transition: background-color 150ms ease-out, color 150ms ease-out;
}
.icon-btn:hover { background: var(--color-gray-100); color: var(--color-gray-900); }
.icon-btn--danger:hover { background: var(--color-bad-50); color: var(--color-bad-700); }
</style>
