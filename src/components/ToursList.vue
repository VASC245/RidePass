<template>
  <div class="max-w-7xl mx-auto p-8 space-y-8">
    <div class="flex items-end justify-between gap-4 flex-wrap">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Mis tours</h1>
        <p class="text-sm text-gray-500 mt-1">
          Un tour inactivo desaparece de la página pública y no se puede vender, ni siquiera desde agencias.
        </p>
      </div>
      <RouterLink to="/panel/nuevo-tour"
        class="px-4 py-2.5 rounded-xl bg-gray-900 text-white text-sm font-semibold hover:bg-gray-800">
        Nuevo tour
      </RouterLink>
    </div>

    <div v-if="loading" class="text-gray-500 text-center py-10">Cargando tours...</div>

    <div v-else-if="tours.length === 0" class="rounded-2xl border border-dashed border-gray-300 py-16 text-center text-gray-500">
      Todavía no tienes tours creados.
    </div>

    <div v-else class="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
      <div
        v-for="tour in tours"
        :key="tour.id"
        class="bg-white border rounded-2xl p-6 flex flex-col justify-between transition-all"
        :class="tour.active ? 'border-gray-200' : 'border-gray-200 bg-gray-50 opacity-80'"
      >
        <div>
          <div class="flex items-start justify-between gap-3">
            <h2 class="font-bold text-lg text-gray-900 leading-tight">{{ tour.title }}</h2>
            <span class="shrink-0 text-[11px] font-bold uppercase tracking-wide px-2 py-1 rounded-full"
              :class="tour.active ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-600'">
              {{ tour.active ? 'Activo' : 'Inactivo' }}
            </span>
          </div>
          <p class="text-sm text-gray-600 mt-2 line-clamp-3">{{ tour.description || "Sin descripción" }}</p>
          <p class="text-sm text-gray-500 mt-2">
            {{ tour.duration ? tour.duration + ' min' : 'Duración no especificada' }}
            · <strong class="text-gray-900">${{ Number(tour.base_price).toFixed(2) }}</strong> por persona
          </p>
        </div>

        <div class="mt-5 pt-4 border-t border-gray-100 space-y-3">
          <label class="flex items-center justify-between gap-3 cursor-pointer">
            <span class="text-sm text-gray-700">Tour activo</span>
            <Switch :value="tour.active" :busy="busy === tour.id + 'active'" @toggle="toggle(tour, 'active')" />
          </label>
          <label class="flex items-center justify-between gap-3 cursor-pointer">
            <span class="text-sm text-gray-700">Permitir venta por agencias</span>
            <Switch :value="tour.allow_agency_sales" :busy="busy === tour.id + 'allow_agency_sales'" @toggle="toggle(tour, 'allow_agency_sales')" />
          </label>
        </div>
      </div>
    </div>

    <p v-if="error" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-xl px-4 py-3">{{ error }}</p>
  </div>
</template>

<script setup>
import { ref, onMounted, defineComponent, h } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

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
      class: ["relative shrink-0 w-11 h-6 rounded-full transition-colors disabled:opacity-50",
        props.value ? "bg-orange-600" : "bg-gray-300"],
    }, [h("span", {
      class: ["absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform",
        props.value ? "translate-x-5" : ""],
    })]);
  },
});

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
