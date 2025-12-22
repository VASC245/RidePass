<template>
  <div class="max-w-7xl mx-auto p-6 space-y-10">
    <h1 class="text-3xl font-extrabold text-center text-gray-800 mb-8">
      🔥 Panel de Ventas
    </h1>

    <!-- ================= FILTROS ================= -->
    <div class="flex flex-wrap gap-4 justify-center mb-6">
      <button @click="filter = 'today'" :class="btnClass(filter === 'today')">Hoy</button>
      <button @click="filter = 'month'" :class="btnClass(filter === 'month')">Este mes</button>
      <button @click="filter = 'all'" :class="btnClass(filter === 'all')">Todo</button>
    </div>

    <!-- ================= KPIS ================= -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
      <KpiCard title="Ingresos (Owner)" :value="formatMoney(totalIngresos)" icon="💵" />
      <KpiCard title="Boletos vendidos" :value="totalBoletos" icon="🎟️" />
      <KpiCard title="Ventas registradas" :value="filtered.length" icon="📄" />
    </div>

    <!-- ================= GRAFICOS ================= -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-10">
      <ChartBar
        title="Ingresos por Día"
        :labels="chartIngresos.labels"
        :data="chartIngresos.data"
      />
      <ChartLine
        title="Ventas por Día"
        :labels="chartVentas.labels"
        :data="chartVentas.data"
      />
    </div>
  </div>
</template>

<script setup>
  import { ref, computed, onMounted, onUnmounted, watch } from "vue";
  import { supabase } from "@/lib/supabase";
  import { useAuthStore } from "@/stores/authStore";

  import KpiCard from "@/components/ui/KpiCard.vue";
  import ChartBar from "@/components/ui/ChartBar.vue";
  import ChartLine from "@/components/ui/ChartLine.vue";

  const auth = useAuthStore();

  // ================= STATE =================
  const allSales = ref([]);
  const filtered = ref([]);
  const filter = ref("all");

  let salesChannel = null;

  // ================= FETCH =================
  const loadSales = async () => {
    if (!auth.user?.id) {
      console.warn("⏳ Usuario no listo aún");
      return;
    }

    // 🔐 IDENTIDAD ÚNICA
    const agencyId = String(auth.user.id);

    console.log("🔐 Dashboard Agency ID:", agencyId);

    const { data, error } = await supabase
      .from("sales_simple")
      .select("*")
      .eq("agency_id", agencyId)
      .eq("status", "pagado");

    if (error) {
      console.error("❌ Error cargando ventas:", error);
      return;
    }

    allSales.value = (data || []).map(s => ({
      ...s,
      boletos_vendidos: JSON.parse(s.seats || "[]").length,
      ingreso: Number(s.owner_gain ?? 0), // 💵 ingreso real
      created_at: s.created_at
    }));

    applyFilters();
  };

  // ================= REALTIME =================
  const setupRealtime = () => {
    if (!auth.user?.id) return;

    const agencyId = String(auth.user.id);

    salesChannel = supabase
      .channel("agency-sales-realtime")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "sales_simple" },
        async payload => {
          if (payload.new?.agency_id === agencyId) {
            await loadSales();
          }
        }
      )
      .subscribe();
  };

  // ================= LIFECYCLE =================
  onMounted(async () => {
    await loadSales();
    setupRealtime();
  });

  onUnmounted(() => {
    if (salesChannel) supabase.removeChannel(salesChannel);
  });

  // ================= FILTROS =================
  const todayStart = () => {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  };

  const monthStart = () => {
    const d = new Date();
    return new Date(d.getFullYear(), d.getMonth(), 1);
  };

  const applyFilters = () => {
    let data = [...allSales.value];

    if (filter.value === "today") {
      data = data.filter(s => new Date(s.created_at) >= todayStart());
    }

    if (filter.value === "month") {
      data = data.filter(s => new Date(s.created_at) >= monthStart());
    }

    filtered.value = data;
  };

  watch(filter, applyFilters);

  // ================= KPIS =================
  const totalIngresos = computed(() =>
    filtered.value.reduce((sum, s) => sum + s.ingreso, 0)
  );

  const totalBoletos = computed(() =>
    filtered.value.reduce((sum, s) => sum + s.boletos_vendidos, 0)
  );

  // ================= GRAFICOS =================
  const chartIngresos = computed(() => {
    const map = {};
    filtered.value.forEach(s => {
      const d = s.created_at.slice(0, 10);
      map[d] = (map[d] || 0) + s.ingreso;
    });
    return {
      labels: Object.keys(map),
      data: Object.values(map),
    };
  });

  const chartVentas = computed(() => {
    const map = {};
    filtered.value.forEach(s => {
      const d = s.created_at.slice(0, 10);
      map[d] = (map[d] || 0) + 1;
    });
    return {
      labels: Object.keys(map),
      data: Object.values(map),
    };
  });

  // ================= UTILS =================
  const formatMoney = n => "$" + Number(n).toFixed(2);

  const btnClass = active =>
    `px-4 py-2 rounded-lg font-semibold shadow ${
      active ? "bg-blue-600 text-white" : "bg-gray-200 text-gray-800"
    }`;
  </script>
