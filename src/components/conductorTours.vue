<template>
  <div class="mx-auto max-w-3xl">
    <PageHeader title="Mis salidas" description="Inicia la salida cuando los pasajeros estén a bordo y finalízala al volver.">
      <template #actions>
        <RouterLink to="/panel/escanear"
          class="inline-flex h-12 items-center gap-2 rounded-lg bg-brand-600 px-5 text-base font-semibold text-white transition-colors hover:bg-brand-700">
          <PhQrCode :size="22" /> Escanear QR
        </RouterLink>
      </template>
    </PageHeader>

    <p v-if="updateError" role="alert" class="mb-4 flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-4 py-3 text-sm text-bad-700">
      <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ updateError }}
    </p>

    <!-- Cargando -->
    <div v-if="loading && tours.length === 0" class="space-y-3" aria-busy="true" aria-label="Cargando salidas">
      <div v-for="n in 2" :key="n" class="h-36 animate-pulse rounded-[var(--radius-card)] border border-gray-200 bg-white" />
    </div>

    <!-- Sin salidas -->
    <BaseCard v-else-if="tours.length === 0">
      <EmptyState :icon="PhCalendarBlank"
        title="No tienes salidas asignadas"
        description="Cuando el dueño te asigne a una chiva y programe una salida, la verás aquí con su hora." />
    </BaseCard>

    <div v-else class="space-y-8">
      <section v-for="group in groups" :key="group.key" :aria-labelledby="'g-' + group.key">
        <h2 :id="'g-' + group.key" class="mb-3 flex items-center gap-2 text-sm font-semibold text-gray-700">
          {{ group.title }}
          <span class="rounded-full bg-gray-200 px-2 py-0.5 text-xs text-gray-700 tabular-nums">{{ group.items.length }}</span>
        </h2>

        <ul class="space-y-3">
          <li v-for="tour in group.items" :key="tour.id"
            class="rounded-[var(--radius-card)] border bg-white p-4 sm:p-5"
            :class="tour.status === 'en_curso' ? 'border-ok-600 ring-1 ring-ok-600' : 'border-gray-200'">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center">
              <div class="flex flex-1 items-start gap-4">
                <div class="w-20 shrink-0">
                  <p class="text-3xl font-bold leading-none text-gray-900 tabular-nums">{{ formatTime(tour.departure_at) }}</p>
                  <p class="mt-1.5 text-sm font-medium text-gray-600 first-letter:uppercase">{{ formatDay(tour.departure_at) }}</p>
                </div>
                <div class="min-w-0 flex-1">
                  <p class="text-lg font-semibold leading-snug text-gray-900">{{ tour.tours?.title || 'Tour' }}</p>
                  <p class="mt-1 flex items-center gap-1.5 text-sm text-gray-700">
                    <PhBus :size="16" class="shrink-0" /> {{ tour.chivas?.name || 'Sin chiva' }}
                  </p>
                  <StatusBadge class="mt-2" :tone="STATUS[tour.status]?.tone || 'neutral'">
                    {{ STATUS[tour.status]?.label || tour.status }}
                  </StatusBadge>
                </div>
              </div>

              <div class="sm:w-56">
                <BaseButton v-if="tour.status === 'pendiente'" size="lg" block
                  :loading="updatingId === tour.id" @click="updateStatus(tour.id, 'en_curso')">
                  <PhPlay v-if="updatingId !== tour.id" :size="20" weight="fill" /> Iniciar salida
                </BaseButton>

                <template v-else-if="tour.status === 'en_curso'">
                  <BaseButton v-if="confirmId !== tour.id" variant="dark" size="lg" block @click="confirmId = tour.id">
                    <PhFlagCheckered :size="20" /> Finalizar salida
                  </BaseButton>
                  <div v-else class="space-y-2">
                    <BaseButton variant="danger" size="lg" block :loading="updatingId === tour.id"
                      @click="updateStatus(tour.id, 'finalizado')">
                      Sí, ya regresamos
                    </BaseButton>
                    <BaseButton variant="ghost" size="lg" block :disabled="updatingId === tour.id" @click="confirmId = null">
                      Seguir en ruta
                    </BaseButton>
                  </div>
                </template>

                <p v-else class="text-sm text-gray-600 sm:text-right">Salida terminada.</p>
              </div>
            </div>
          </li>
        </ul>
      </section>
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
  import StatusBadge from "@/components/ui/StatusBadge.vue";
  import EmptyState from "@/components/ui/EmptyState.vue";
  import { PhQrCode, PhCalendarBlank, PhBus, PhPlay, PhFlagCheckered, PhWarningCircle } from "@phosphor-icons/vue";

  const auth = useAuthStore();
  const tours = ref([]);
  const loading = ref(true);
  const updatingId = ref(null);
  const confirmId = ref(null);
  const updateError = ref("");

  const STATUS = {
    pendiente:  { tone: "info",    label: "Programada" },
    en_curso:   { tone: "success", label: "En curso" },
    finalizado: { tone: "neutral", label: "Finalizada" },
  };

  const formatTime = (d) => new Date(d).toLocaleTimeString("es-EC", { hour: "2-digit", minute: "2-digit" });
  const sameDay = (a, b) => a.toDateString() === b.toDateString();
  const formatDay = (d) => {
    const date = new Date(d);
    const today = new Date();
    const tomorrow = new Date(); tomorrow.setDate(today.getDate() + 1);
    if (sameDay(date, today)) return "hoy";
    if (sameDay(date, tomorrow)) return "mañana";
    return date.toLocaleDateString("es-EC", { weekday: "short", day: "numeric", month: "short" });
  };

  // En curso y las de hoy primero; luego las próximas y al final las atrasadas
  const groups = computed(() => {
    const today = new Date();
    const startOfToday = new Date(); startOfToday.setHours(0, 0, 0, 0);
    const now = [], upcoming = [], late = [];
    for (const t of tours.value) {
      const d = new Date(t.departure_at);
      if (t.status === "en_curso" || sameDay(d, today)) now.push(t);
      else if (d > today) upcoming.push(t);
      else if (d < startOfToday) late.push(t);
    }
    now.sort((a, b) => (a.status === "en_curso" ? -1 : 0) - (b.status === "en_curso" ? -1 : 0));
    return [
      { key: "hoy",       title: "Hoy",                        items: now },
      { key: "proximas",  title: "Próximas",                   items: upcoming },
      { key: "atrasadas", title: "Sin iniciar de días pasados", items: late },
    ].filter((g) => g.items.length);
  });

  // NUEVO: tiempo de gracia (NO afecta nada previo)
  const GRACE_MINUTES = 15;

  // ================= FETCH TOURS (IGUAL + FILTRO EXTRA) =================
  const fetchTours = async () => {
    loading.value = true;
    if (!auth.user) { loading.value = false; return; }

    // EXACTAMENTE IGUAL: chivas del conductor
    const { data: driverRows, error: driverError } = await supabase
      .from("drivers")
      .select("chiva_id")
      .eq("user_id", auth.user.id);

    if (driverError) {
      console.error("Error buscando conductor:", driverError);
      tours.value = [];
      loading.value = false;
      return;
    }

    if (!driverRows || driverRows.length === 0) {
      tours.value = [];
      loading.value = false;
      return;
    }

    const chivaIds = driverRows.map(d => d.chiva_id);

    // EXACTAMENTE IGUAL: tours asignados
    const { data, error } = await supabase
      .from("assigned_chivas")
      .select(`
        id,
        departure_at,
        status,
        finished_at,
        tours(title),
        chivas(name)
      `)
      .in("chiva_id", chivaIds)
      .order("departure_at", { ascending: true });

    if (error) {
      console.error("Error cargando tours:", error);
      tours.value = [];
      loading.value = false;
      return;
    }

    // NUEVO (NO INVASIVO):
    //    ocultar SOLO los finalizados hace más de 15 minutos
    const now = new Date();

    tours.value = (data || []).filter(tour => {
      if (tour.status !== "finalizado") return true;
      if (!tour.finished_at) return true;

      const finishedAt = new Date(tour.finished_at);
      const diffMinutes = (now - finishedAt) / 1000 / 60;

      return diffMinutes <= GRACE_MINUTES;
    });

    loading.value = false;
  };

  // ================= UPDATE STATUS (IGUAL + CAMPO EXTRA) =================
  const updateStatus = async (id, newStatus) => {
    if (updatingId.value) return;
    updatingId.value = id;
    updateError.value = "";
    // ANTES: solo status
    // AHORA: status + finished_at (solo al finalizar)
    const payload =
      newStatus === "finalizado"
        ? { status: newStatus, finished_at: new Date().toISOString() }
        : { status: newStatus };

    const { error } = await supabase
      .from("assigned_chivas")
      .update(payload)
      .eq("id", id);

    if (error) {
      console.error("Error actualizando estado:", error);
      const accion = newStatus === "finalizado" ? "finalizar" : "iniciar";
      updateError.value = error.code === "P0001"
        ? error.message
        : `No se pudo ${accion} la salida. Revisa tu conexión e intenta de nuevo.`;
    }

    updatingId.value = null;
    confirmId.value = null;
    fetchTours();
  };

  onMounted(fetchTours);
  </script>
