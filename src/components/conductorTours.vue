<template>
  <div class="max-w-5xl mx-auto py-10 space-y-8">
    <!-- Título -->
    <h2 class="text-3xl font-extrabold text-center text-gray-800">
      🚌 Mis Tours Asignados
    </h2>

    <!-- Cargando -->
    <div v-if="loading" class="text-gray-500 text-center italic">
      ⏳ Cargando tours...
    </div>

    <!-- Sin tours -->
    <div v-else-if="tours.length === 0" class="text-gray-500 text-center">
      🚫 No tienes tours asignados.
    </div>

    <!-- Lista de tours -->
    <div
      v-for="tour in tours"
      :key="tour.id"
      class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6 flex flex-col md:flex-row md:items-center md:justify-between gap-6 hover:shadow-md transition-all"
    >
      <!-- Info del tour -->
      <div class="space-y-1">
        <p class="font-bold text-xl text-gray-800">
          {{ tour.tours.title }}
        </p>
        <p class="text-sm text-gray-600">
          🚌 Chiva: <span class="font-medium">{{ tour.chivas.name }}</span>
        </p>
        <p class="text-sm text-gray-600">
          ⏰ Salida:
          <span class="font-medium">
            {{ new Date(tour.departure_at).toLocaleString() }}
          </span>
        </p>
        <p class="text-sm">
          Estado:
          <span
            :class="{
              'text-yellow-600 font-semibold': tour.status === 'pendiente',
              'text-green-600 font-semibold': tour.status === 'en_curso',
              'text-gray-500 font-medium': tour.status === 'finalizado'
            }"
          >
            {{ tour.status }}
          </span>
        </p>
      </div>

      <!-- Acciones -->
      <div class="flex gap-3">
        <button
          v-if="tour.status === 'pendiente'"
          @click="updateStatus(tour.id, 'en_curso')"
          class="bg-green-600 hover:bg-green-700 text-white px-5 py-2.5 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          ▶️ Comenzar
        </button>

        <button
          v-if="tour.status === 'en_curso'"
          @click="updateStatus(tour.id, 'finalizado')"
          class="bg-red-600 hover:bg-red-700 text-white px-5 py-2.5 rounded-xl font-semibold shadow-sm transition active:scale-95"
        >
          ⏹️ Finalizar
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
  import { ref, onMounted } from "vue";
  import { supabase } from "@/lib/supabase";
  import { useAuthStore } from "@/stores/authStore";

  const auth = useAuthStore();
  const tours = ref([]);
  const loading = ref(true);

  // ⏱️ NUEVO: tiempo de gracia (NO afecta nada previo)
  const GRACE_MINUTES = 15;

  // ================= FETCH TOURS (IGUAL + FILTRO EXTRA) =================
  const fetchTours = async () => {
    loading.value = true;
    if (!auth.user) return;

    // 1️⃣ EXACTAMENTE IGUAL: chivas del conductor
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

    // 2️⃣ EXACTAMENTE IGUAL: tours asignados
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

    // 3️⃣ NUEVO (NO INVASIVO):
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
    // 🔹 ANTES: solo status
    // 🔹 AHORA: status + finished_at (solo al finalizar)
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
    }

    // 🔄 Igual que antes
    fetchTours();
  };

  onMounted(fetchTours);
  </script>
