<template>
  <div class="max-w-6xl mx-auto py-10 px-6 space-y-8">
    <div>
      <h2 class="text-2xl font-bold text-gray-900">Salidas programadas</h2>
      <p class="text-sm text-gray-500 mt-1">
        Cada salida abre o cierra sus ventas de forma independiente. Cerrar una salida no afecta a las ya vendidas.
      </p>
    </div>

    <!-- Formulario -->
    <form @submit.prevent="saveSalida" class="bg-white p-6 rounded-2xl border border-gray-200 space-y-5">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div>
          <label class="field-label">Tour</label>
          <select v-model="selectedTour" class="field-input bg-white">
            <option disabled value="">Seleccione un tour</option>
            <option v-for="tour in tours" :key="tour.id" :value="tour.id">
              {{ tour.title }}{{ tour.active ? '' : ' (inactivo)' }}
            </option>
          </select>
        </div>
        <div>
          <label class="field-label">Chiva</label>
          <select v-model="selectedChiva" class="field-input bg-white">
            <option disabled value="">Seleccione una chiva</option>
            <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">{{ chiva.name }}</option>
          </select>
        </div>
        <div>
          <label class="field-label">Fecha</label>
          <input type="date" v-model="departureDate" :min="todayStr" class="field-input" />
        </div>
        <div>
          <label class="field-label">Hora de salida</label>
          <input type="time" v-model="departureTime" class="field-input" />
        </div>
      </div>

      <p v-if="formError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ formError }}</p>

      <div class="flex gap-3 justify-end">
        <button v-if="editingId" type="button" @click="cancelEdit"
          class="px-5 py-2.5 rounded-xl border border-gray-200 text-gray-700 text-sm font-semibold hover:bg-gray-50">
          Cancelar
        </button>
        <button type="submit" :disabled="saving"
          class="px-5 py-2.5 rounded-xl bg-gray-900 text-white text-sm font-semibold hover:bg-gray-800 disabled:opacity-50">
          {{ saving ? 'Guardando...' : (editingId ? 'Guardar cambios' : 'Programar salida') }}
        </button>
      </div>
    </form>

    <!-- Lista de salidas -->
    <div v-if="salidas.length > 0" class="overflow-x-auto border border-gray-200 rounded-2xl">
      <table class="w-full text-left text-sm">
        <thead class="bg-gray-50 text-xs uppercase tracking-wide text-gray-500">
          <tr>
            <th class="px-5 py-3">Tour</th>
            <th class="px-5 py-3">Chiva</th>
            <th class="px-5 py-3">Salida</th>
            <th class="px-5 py-3">Estado</th>
            <th class="px-5 py-3">Ventas</th>
            <th class="px-5 py-3 text-right">Acciones</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          <tr v-for="salida in salidas" :key="salida.id" class="hover:bg-gray-50">
            <td class="px-5 py-3 font-medium text-gray-800">{{ salida.tours?.title }}</td>
            <td class="px-5 py-3 text-gray-600">{{ salida.chivas?.name }}</td>
            <td class="px-5 py-3 text-gray-600">{{ formatDate(salida.departure_at) }}</td>
            <td class="px-5 py-3">
              <span class="text-xs font-bold uppercase tracking-wide px-2 py-1 rounded-full"
                :class="{
                  'bg-yellow-100 text-yellow-700': salida.status === 'pendiente',
                  'bg-green-100 text-green-700': salida.status === 'en_curso',
                  'bg-gray-200 text-gray-600': salida.status === 'finalizado',
                }">
                {{ salida.status }}
              </span>
            </td>
            <td class="px-5 py-3">
              <button type="button" @click="toggleSales(salida)" :disabled="busy === salida.id"
                class="inline-flex items-center gap-2 text-xs font-semibold px-3 py-1.5 rounded-full border transition-colors disabled:opacity-50"
                :class="salida.sales_open
                  ? 'border-green-200 bg-green-50 text-green-700 hover:bg-green-100'
                  : 'border-red-200 bg-red-50 text-red-700 hover:bg-red-100'">
                <span class="w-2 h-2 rounded-full" :class="salida.sales_open ? 'bg-green-500' : 'bg-red-500'"></span>
                {{ salida.sales_open ? 'Abiertas' : 'Cerradas' }}
              </button>
            </td>
            <td class="px-5 py-3">
              <div class="flex gap-2 justify-end">
                <button @click="editSalida(salida)"
                  class="px-3 py-1.5 rounded-lg border border-gray-200 text-xs font-semibold text-gray-700 hover:bg-gray-50">
                  Editar
                </button>
                <button @click="deleteSalida(salida)"
                  class="px-3 py-1.5 rounded-lg border border-red-200 text-xs font-semibold text-red-700 hover:bg-red-50">
                  Eliminar
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <p v-else class="text-gray-500 text-center py-10 rounded-2xl border border-dashed border-gray-300">
      No hay salidas programadas.
    </p>

    <p v-if="listError" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ listError }}</p>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

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

const formatDate = (d) =>
  new Date(d).toLocaleString("es-EC", { weekday: "short", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });

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
.field-input {
  width: 100%;
  padding: 0.625rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.75rem;
  font-size: 0.875rem;
  outline: none;
}
.field-input:focus { box-shadow: 0 0 0 2px #ea580c; }
.field-label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.375rem;
}
</style>
