<template>
  <div>
    <PageHeader title="Conductores"
      description="Asigna a cada conductor una de tus chivas. Así ve sus salidas del día y puede escanear los boletos al embarcar." />

    <div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
      <!-- Conductores asignados -->
      <BaseCard :padded="false">
        <div class="flex items-center justify-between gap-3 border-b border-gray-200 px-5 py-4 sm:px-6">
          <h2 class="text-base font-semibold text-gray-900">Tu equipo</h2>
          <span v-if="drivers.length" class="text-sm text-gray-600 tabular-nums">
            {{ drivers.length }} {{ drivers.length === 1 ? 'conductor' : 'conductores' }}
          </span>
        </div>

        <ul v-if="drivers.length > 0" class="divide-y divide-gray-100">
          <li v-for="driver in drivers" :key="driver.id" class="flex flex-wrap items-center gap-x-4 gap-y-2 px-5 py-4 sm:px-6">
            <span class="inline-flex size-10 shrink-0 items-center justify-center rounded-full bg-gray-100 text-sm font-bold text-gray-700">
              {{ initialsOf(driver.full_name) }}
            </span>
            <div class="min-w-0 flex-1">
              <p class="truncate font-semibold text-gray-900">{{ driver.full_name }}</p>
              <p class="truncate text-sm text-gray-600">{{ driver.email }}</p>
            </div>
            <span class="inline-flex items-center gap-1.5 rounded-full border border-brand-200 bg-brand-50 px-2.5 py-1 text-xs font-semibold text-brand-800">
              <PhBus :size="14" aria-hidden="true" />
              {{ driver.chivas?.name ?? 'Sin chiva' }}
            </span>
            <BaseButton variant="ghost" size="sm" class="text-bad-700 hover:bg-bad-50" @click="removeDriver(driver)">
              Quitar
            </BaseButton>
          </li>
        </ul>
        <EmptyState v-else :icon="PhSteeringWheel" title="Aún no tienes conductores"
          description="Busca a tu conductor por su correo y asígnalo a una chiva. Debe estar registrado en chivaspass con el rol conductor." />
      </BaseCard>

      <!-- Agregar conductor -->
      <BaseCard class="lg:sticky lg:top-8">
        <template #title>Agregar conductor</template>

        <form class="space-y-4" @submit.prevent="fetchConductor">
          <div>
            <label for="driver-email" class="field-label">Correo del conductor</label>
            <div class="flex gap-2">
              <input id="driver-email" v-model="search" type="email" placeholder="conductor@correo.com" class="field-control" required />
              <BaseButton type="submit" variant="dark" class="h-11 shrink-0" :loading="searching" aria-label="Buscar conductor">
                <PhMagnifyingGlass v-if="!searching" :size="18" />
              </BaseButton>
            </div>
            <p class="field-hint">Escribe el correo exacto con el que se registró.</p>
          </div>

          <p v-if="searchMsg" class="rounded-lg border border-gray-200 bg-gray-50 px-3.5 py-3 text-sm text-gray-700">{{ searchMsg }}</p>
          <p v-if="formError" role="alert" class="flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-3.5 py-3 text-sm text-bad-700">
            <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ formError }}
          </p>

          <div v-if="found" class="space-y-3 rounded-lg border border-brand-200 bg-brand-50/60 p-4">
            <div class="flex items-center gap-3">
              <span class="inline-flex size-9 shrink-0 items-center justify-center rounded-full bg-brand-600 text-xs font-bold text-white">
                {{ initialsOf(found.full_name) }}
              </span>
              <div class="min-w-0">
                <p class="truncate font-semibold text-gray-900">{{ found.full_name }}</p>
                <p class="truncate text-sm text-gray-600">{{ found.email }}</p>
              </div>
            </div>
            <div>
              <label for="driver-chiva" class="field-label">Chiva</label>
              <select id="driver-chiva" v-model="selectedChiva" class="field-control">
                <option disabled value="">Elige una chiva</option>
                <option v-for="chiva in chivas" :key="chiva.id" :value="chiva.id">{{ chiva.name }}</option>
              </select>
            </div>
            <BaseButton block :loading="saving" @click="assignConductor">Asignar conductor</BaseButton>
          </div>
        </form>
      </BaseCard>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import PageHeader from "@/components/ui/PageHeader.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import { PhBus, PhSteeringWheel, PhMagnifyingGlass, PhWarningCircle } from "@phosphor-icons/vue";

const auth = useAuthStore();
const search = ref("");
const searching = ref(false);
const searchMsg = ref("");
const found = ref(null);
const selectedChiva = ref("");
const saving = ref(false);
const formError = ref("");
const drivers = ref([]);
const chivas = ref([]);

const initialsOf = (name = "") => {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  return ((parts[0]?.[0] ?? "") + (parts[1]?.[0] ?? "")).toUpperCase() || "?";
};

// find_conductor devuelve un solo conductor por correo exacto: un dueño ya
// no puede listar a todos los conductores registrados en la plataforma.
const fetchConductor = async () => {
  formError.value = "";
  found.value = null;
  searchMsg.value = "";
  searching.value = true;
  const { data, error } = await supabase.rpc("find_conductor", { p_email: search.value.trim() });
  searching.value = false;
  if (error) {
    console.error("find_conductor:", error.message);
    formError.value = "No se pudo buscar el conductor.";
    return;
  }
  const row = Array.isArray(data) ? data[0] : data;
  if (!row) {
    searchMsg.value = "No hay ningún conductor registrado con ese correo. Pídele que se registre en chivaspass con el rol conductor.";
    return;
  }
  found.value = row;
};

const fetchChivas = async () => {
  const { data } = await supabase.from("chivas").select("id, name").eq("user_id", auth.user.id).order("name");
  chivas.value = data || [];
};

const fetchDrivers = async () => {
  const { data } = await supabase
    .from("drivers")
    .select("id, full_name, email, chivas(name)")
    .eq("owner_id", auth.user.id)
    .order("full_name");
  drivers.value = data || [];
};

const assignConductor = async () => {
  if (!found.value) return;
  if (!selectedChiva.value) { formError.value = "Selecciona una chiva para asignar."; return; }
  saving.value = true;
  formError.value = "";
  const { error } = await supabase.from("drivers").insert([{
    user_id: found.value.id,
    full_name: found.value.full_name,
    email: found.value.email,
    chiva_id: selectedChiva.value,
    owner_id: auth.user.id,
  }]);
  saving.value = false;
  if (error) {
    console.error("drivers insert:", error.message);
    formError.value = "No se pudo asignar el conductor.";
    return;
  }
  found.value = null;
  search.value = "";
  selectedChiva.value = "";
  fetchDrivers();
};

const removeDriver = async (driver) => {
  if (!confirm(`¿Quitar a ${driver.full_name} de ${driver.chivas?.name ?? "la chiva"}?`)) return;
  const { error } = await supabase.from("drivers").delete().eq("id", driver.id).eq("owner_id", auth.user.id);
  if (error) { formError.value = "No se pudo quitar el conductor."; return; }
  fetchDrivers();
};

onMounted(() => {
  fetchChivas();
  fetchDrivers();
});
</script>
