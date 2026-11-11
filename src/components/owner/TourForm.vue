<template>
  <div>
    <PageHeader :title="editing ? 'Editar tour' : 'Crear tour'"
      :description="editing ? `Estás editando ${form.title || 'este tour'}. Los cambios se ven en la página pública al guardar.` : 'Describe el recorrido como lo leería un turista: qué ve, dónde para y cuánto dura.'" />

    <div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_20rem]">
      <!-- Formulario -->
      <BaseCard :variant="editing ? 'highlight' : 'default'">
        <form class="space-y-5" @submit.prevent="saveTour">
          <div>
            <label for="tour-title" class="field-label">Nombre del tour</label>
            <input id="tour-title" ref="titleField" v-model="form.title" type="text" class="field-control" placeholder="Ej.: Ruta de las Cascadas" required />
          </div>

          <div>
            <label for="tour-desc" class="field-label">Descripción</label>
            <textarea id="tour-desc" v-model="form.description" rows="4" class="field-control"
              placeholder="Ej.: Recorrido por Agoyán y el Pailón del Diablo con paradas para fotos." />
          </div>

          <div class="grid gap-5 sm:grid-cols-2">
            <div>
              <label for="tour-price" class="field-label">Precio por persona (USD)</label>
              <input id="tour-price" v-model.number="form.base_price" type="number" inputmode="decimal" min="0.5" max="1000" step="0.01"
                class="field-control tabular-nums" placeholder="Ej.: 10.00" required
                :aria-invalid="priceError ? 'true' : undefined" aria-describedby="tour-price-hint" />
              <p id="tour-price-hint" class="field-hint" :class="priceError && 'text-bad-700'">
                {{ priceError || 'Lo que paga cada pasajero. En ventas web se suma el cargo por servicio.' }}
              </p>
            </div>
            <div>
              <label for="tour-duration" class="field-label">Duración (minutos)</label>
              <input id="tour-duration" v-model.number="form.duration" type="number" min="1" class="field-control tabular-nums" required />
            </div>
          </div>

          <p v-if="saveError" role="alert" class="rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">{{ saveError }}</p>

          <div class="flex flex-wrap items-center gap-2 border-t border-gray-200 pt-5">
            <BaseButton type="submit" :loading="saving">{{ editing ? 'Guardar cambios' : 'Guardar tour' }}</BaseButton>
            <BaseButton v-if="editing" variant="ghost" @click="cancelEdit">Cancelar edición</BaseButton>
          </div>
        </form>
      </BaseCard>

      <!-- Tours existentes -->
      <BaseCard :padded="false">
        <div class="flex items-center justify-between border-b border-gray-200 px-5 py-4">
          <h2 class="text-base font-semibold text-gray-900">Tus tours</h2>
          <span v-if="tours.length" class="text-sm text-gray-600 tabular-nums">{{ tours.length }}</span>
        </div>
        <ul v-if="tours.length" class="divide-y divide-gray-100">
          <li v-for="tour in tours" :key="tour.id" class="flex items-center gap-2 py-3 pl-5 pr-3"
            :class="editingId === tour.id && 'bg-brand-50'">
            <div class="min-w-0 flex-1">
              <p class="truncate text-sm font-semibold text-gray-900">{{ tour.title }}</p>
              <p class="text-xs text-gray-600 tabular-nums">
                ${{ Number(tour.base_price).toFixed(2) }} · {{ tour.duration }} min
              </p>
            </div>
            <button type="button" class="icon-btn" :aria-label="`Editar ${tour.title}`" title="Editar" @click="editTour(tour)">
              <PhPencilSimple :size="18" />
            </button>
            <button type="button" class="icon-btn icon-btn--danger" :aria-label="`Eliminar ${tour.title}`" title="Eliminar" @click="deleteTour(tour.id)">
              <PhTrash :size="18" />
            </button>
          </li>
        </ul>
        <EmptyState v-else :icon="PhMapTrifold" title="Aún no hay tours"
          description="El primero que guardes aparecerá aquí para editarlo." />
      </BaseCard>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { useRoute } from "vue-router";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import PageHeader from "@/components/ui/PageHeader.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import { PhPencilSimple, PhTrash, PhMapTrifold } from "@phosphor-icons/vue";

const auth = useAuthStore();
const route = useRoute();
const titleField = ref(null);

const EMPTY_FORM = () => ({ title: "", description: "", base_price: null, duration: 60 });
const form = ref(EMPTY_FORM());
const saving = ref(false);
const saveError = ref("");
const priceError = ref("");
const tours = ref([]);
const editing = ref(false);
const editingId = ref(null);

// Cargar tours del dueño
const fetchTours = async () => {
  if (!auth.user) return;
  const { data, error } = await supabase
    .from("tours")
    .select("id, title, description, base_price, duration")
    .eq("user_id", auth.user.id)
    .order("created_at", { ascending: false });
  if (!error) tours.value = data;
};

// El dueño fija el precio por persona. Mismos límites que la base
// (tours_base_price_range): entre $0.50 y $1000, con centavos.
const validPrice = (v) => {
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0.5 || n > 1000) return null;
  return Math.round(n * 100) / 100;
};

// Guardar o editar tour
const saveTour = async () => {
  if (!auth.user) {
    saveError.value = "Tu sesión expiró. Vuelve a iniciar sesión para guardar.";
    return;
  }
  const price = validPrice(form.value.base_price);
  priceError.value = price === null ? "Ingresa un precio entre $0.50 y $1000." : "";
  if (price === null) return;

  saving.value = true;
  saveError.value = "";
  const payload = {
    title: form.value.title,
    description: form.value.description,
    duration: form.value.duration,
    base_price: price,
  };

  const { error } = editing.value
    ? await supabase.from("tours").update(payload).eq("id", editingId.value).eq("user_id", auth.user.id)
    : await supabase.from("tours").insert([{ ...payload, user_id: auth.user.id }]);
  saving.value = false;

  if (error) {
    console.error("guardar tour:", error);
    saveError.value = "No se pudo guardar el tour. Revisa los datos e intenta de nuevo.";
    return;
  }

  cancelEdit();
  fetchTours();
};

// Editar
const editTour = (tour) => {
  editing.value = true;
  editingId.value = tour.id;
  form.value = { title: tour.title, description: tour.description, duration: tour.duration, base_price: Number(tour.base_price) };
  priceError.value = "";
  saveError.value = "";
  nextTick(() => {
    titleField.value?.focus();
    titleField.value?.scrollIntoView({ behavior: "smooth", block: "center" });
  });
};

// Eliminar
const deleteTour = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar este tour?")) return;
  await supabase
    .from("tours")
    .delete()
    .eq("id", id)
    .eq("user_id", auth.user.id);
  fetchTours();
};

// Cancelar
const cancelEdit = () => {
  editing.value = false;
  editingId.value = null;
  form.value = EMPTY_FORM();
  priceError.value = "";
  saveError.value = "";
};

// Desde la lista de tours se llega con ?edit=<id> para abrir ese tour
onMounted(async () => {
  await fetchTours();
  const target = tours.value.find((t) => t.id === route.query.edit);
  if (target) editTour(target);
});
</script>

<style scoped>
.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem; height: 2.25rem;
  flex-shrink: 0;
  border-radius: 8px;
  color: var(--color-gray-600);
  transition: background-color 150ms ease-out, color 150ms ease-out;
}
.icon-btn:hover { background: var(--color-gray-100); color: var(--color-gray-900); }
.icon-btn--danger:hover { background: var(--color-bad-50); color: var(--color-bad-700); }
</style>
