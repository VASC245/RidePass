<template>
  <div>
    <PageHeader title="Chivas" description="Los vehículos con los que haces tus salidas. La capacidad define cuántos asientos se pueden vender.">
      <template #actions>
        <BaseButton v-if="!showForm" @click="openNew">
          <PhPlus :size="18" weight="bold" /> Nueva chiva
        </BaseButton>
      </template>
    </PageHeader>

    <div class="space-y-6">
      <!-- Formulario: aparece solo al crear o editar -->
      <BaseCard v-if="showForm">
        <template #title>{{ editingId ? 'Editar chiva' : 'Nueva chiva' }}</template>
        <template #actions>
          <button type="button" class="icon-btn" aria-label="Cerrar formulario" @click="resetForm">
            <PhX :size="18" />
          </button>
        </template>

        <form class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4" @submit.prevent="saveChiva">
          <div class="sm:col-span-2">
            <label for="chiva-nombre" class="field-label">Nombre</label>
            <input id="chiva-nombre" ref="firstField" v-model="nombre" class="field-control" placeholder="Ej.: La Bañeña" />
          </div>
          <div>
            <label for="chiva-placa" class="field-label">Placa</label>
            <input id="chiva-placa" v-model="placa" class="field-control uppercase placeholder:normal-case" placeholder="Ej.: TBA-1234" />
          </div>
          <div>
            <label for="chiva-codigo" class="field-label">Código interno</label>
            <input id="chiva-codigo" v-model="codigo" class="field-control" placeholder="Ej.: CH-01" />
          </div>
          <div>
            <label for="chiva-capacidad" class="field-label">Capacidad</label>
            <input id="chiva-capacidad" v-model="capacidad" type="number" min="1" class="field-control tabular-nums" />
            <p class="field-hint">Asientos para pasajeros.</p>
          </div>

          <div class="flex flex-wrap items-center gap-2 sm:col-span-2 lg:col-span-4">
            <BaseButton type="submit">{{ editingId ? 'Guardar cambios' : 'Guardar chiva' }}</BaseButton>
            <BaseButton variant="ghost" @click="resetForm">Cancelar</BaseButton>
          </div>
        </form>
      </BaseCard>

      <!-- Lista -->
      <ul v-if="chivas.length" class="grid gap-4 md:grid-cols-2">
        <li v-for="chiva in chivas" :key="chiva.id"
          class="flex items-start gap-4 rounded-[var(--radius-card)] border bg-white p-5 transition-colors"
          :class="editingId === chiva.id ? 'border-brand-300 ring-2 ring-brand-100' : 'border-gray-200'">
          <span class="inline-flex size-11 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-700">
            <PhBus :size="22" />
          </span>

          <div class="min-w-0 flex-1">
            <div class="flex flex-wrap items-center gap-2">
              <p class="truncate text-base font-semibold text-gray-900">{{ chiva.name }}</p>
              <span v-if="chiva.code" class="rounded-md bg-gray-100 px-1.5 py-0.5 text-xs font-semibold text-gray-700">{{ chiva.code }}</span>
            </div>
            <dl class="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-sm text-gray-700">
              <div class="flex items-center gap-1.5">
                <dt class="sr-only">Placa</dt>
                <PhIdentificationCard :size="16" class="text-gray-500" aria-hidden="true" />
                <dd class="font-medium uppercase tabular-nums">{{ chiva.plate }}</dd>
              </div>
              <div class="flex items-center gap-1.5">
                <dt class="sr-only">Capacidad</dt>
                <PhUsersThree :size="16" class="text-gray-500" aria-hidden="true" />
                <dd><span class="font-semibold tabular-nums text-gray-900">{{ chiva.capacity }}</span> asientos</dd>
              </div>
            </dl>
          </div>

          <div class="-mr-1 -mt-1 flex shrink-0 items-center">
            <button type="button" class="icon-btn" :aria-label="`Editar ${chiva.name}`" title="Editar" @click="editChiva(chiva)">
              <PhPencilSimple :size="18" />
            </button>
            <button type="button" class="icon-btn icon-btn--danger" :aria-label="`Eliminar ${chiva.name}`" title="Eliminar" @click="deleteChiva(chiva.id)">
              <PhTrash :size="18" />
            </button>
          </div>
        </li>
      </ul>

      <BaseCard v-else-if="!showForm">
        <EmptyState :icon="PhBus" title="Aún no registras chivas"
          description="Agrega tu primera chiva para poder asignarla a las salidas de tus tours.">
          <BaseButton @click="openNew"><PhPlus :size="18" weight="bold" /> Nueva chiva</BaseButton>
        </EmptyState>
      </BaseCard>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import PageHeader from "@/components/ui/PageHeader.vue";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import { PhBus, PhPlus, PhX, PhPencilSimple, PhTrash, PhIdentificationCard, PhUsersThree } from "@phosphor-icons/vue";

const auth = useAuthStore();

const nombre = ref("");
const placa = ref("");
const codigo = ref("");
const capacidad = ref(40);
const chivas = ref([]);
const editingId = ref(null);
const showForm = ref(false);
const firstField = ref(null);

const focusForm = async () => {
  await nextTick();
  firstField.value?.focus();
  firstField.value?.scrollIntoView({ behavior: "smooth", block: "center" });
};

const openNew = () => {
  resetForm();
  showForm.value = true;
  focusForm();
};

// Cargar solo chivas del dueño
const fetchChivas = async () => {
  if (!auth.user) return;

  const { data, error } = await supabase
    .from("chivas")
    .select("id, name, plate, code, capacity, user_id")
    .eq("user_id", auth.user.id);

  if (!error) {
    chivas.value = data;
  } else {
    console.error("Error cargando chivas:", error);
  }
};

// Guardar o actualizar
const saveChiva = async () => {
  if (!nombre.value || !placa.value || !codigo.value) {
    alert("Por favor completa todos los campos.");
    return;
  }
  if (!auth.user) {
    alert("Debes iniciar sesión para guardar chivas.");
    return;
  }

  if (editingId.value) {
    const { error } = await supabase
      .from("chivas")
      .update({
        name: nombre.value,
        plate: placa.value,
        code: codigo.value,
        capacity: capacidad.value,
      })
      .eq("id", editingId.value)
      .eq("user_id", auth.user.id);

    if (error) {
      console.error("Error al actualizar chiva:", error);
      // P0001: error de negocio con mensaje legible (p. ej. capacidad menor a los asientos vendidos).
      alert(error.code === "P0001" ? error.message : "No se pudo actualizar la chiva.");
      return;
    }
  } else {
    const { error } = await supabase.from("chivas").insert([
      {
        name: nombre.value,
        plate: placa.value,
        code: codigo.value,
        capacity: capacidad.value,
        user_id: auth.user.id,
      },
    ]);

    if (error) {
      console.error("Error al guardar chiva:", error);
      alert("No se pudo guardar la chiva.");
    }
  }

  resetForm();
  fetchChivas();
};

// Editar
const editChiva = (chiva) => {
  editingId.value = chiva.id;
  nombre.value = chiva.name;
  placa.value = chiva.plate;
  codigo.value = chiva.code;
  capacidad.value = chiva.capacity;
  showForm.value = true;
  focusForm();
};

// Eliminar
const deleteChiva = async (id) => {
  if (!confirm("¿Seguro que deseas eliminar esta chiva?")) return;
  const { error } = await supabase.from("chivas").delete().eq("id", id).eq("user_id", auth.user.id);
  if (error) {
    console.error("Error al eliminar chiva:", error);
    // 23503: la chiva tiene salidas registradas (llave foránea).
    if (error.code === "23503") alert("No se puede eliminar: la chiva tiene salidas registradas.");
    else alert(error.code === "P0001" ? error.message : "No se pudo eliminar la chiva.");
    return;
  }
  fetchChivas();
};

// Resetear
const resetForm = () => {
  showForm.value = false;
  editingId.value = null;
  nombre.value = "";
  placa.value = "";
  codigo.value = "";
  capacidad.value = 40;
};

onMounted(fetchChivas);
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
