<template>
  <div class="max-w-7xl mx-auto p-6 space-y-10">
    <h1 class="text-3xl font-extrabold text-center text-gray-800 mb-8">
      🧾 Dashboard de Agencia
    </h1>

    <div class="grid grid-cols-1 sm:grid-cols-3 gap-6">
      <KpiCard title="Ganancia Hoy" :value="formatMoney(kpiToday)" icon="💵" />
      <KpiCard title="Ganancia Mes" :value="formatMoney(kpiMonth)" icon="📅" />
      <KpiCard title="Total Histórico" :value="formatMoney(kpiLifetime)" icon="🏦" />
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-10">
      <ChartBar
        title="Ingresos por Día (Últimos 10 días)"
        :labels="barLabels"
        :values="barValues"
      />

      <ChartLine
        title="Boletos Vendidos (Últimos 10 días)"
        :labels="lineLabels"
        :values="lineValues"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";

import KpiCard from "@/components/dashboard/KpiCard.vue";
import ChartBar from "@/components/dashboard/ChartBar.vue";
import ChartLine from "@/components/dashboard/ChartLine.vue";

const auth = useAuthStore();

const kpiToday = ref(0);
const kpiMonth = ref(0);
const kpiLifetime = ref(0);

const barLabels = ref([]);
const barValues = ref([]);

const lineLabels = ref([]);
const lineValues = ref([]);

const formatMoney = (n) => "$" + Number(n).toFixed(2);

const getStartOfDay = () =>
  new Date().toISOString().split("T")[0] + "T00:00:00Z";

const getStartOfMonth = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(
    2,
    "0"
  )}-01T00:00:00Z`;
};

const loadDashboard = async () => {
  const agencyId = auth.user.id;

  const { data: pagos } = await supabase
    .from("pending_payments")
    .select("*")
    .eq("agency_id", agencyId)
    .eq("estado", "verificado");

  if (!pagos) return;

  const today = getStartOfDay();
  const monthStart = getStartOfMonth();

  kpiToday.value = pagos
    .filter((p) => new Date(p.created_at) >= new Date(today))
    .reduce((sum, p) => sum + Number(p.monto_agencia || 0), 0);

  kpiMonth.value = pagos
    .filter((p) => new Date(p.created_at) >= new Date(monthStart))
    .reduce((sum, p) => sum + Number(p.monto_agencia || 0), 0);

  kpiLifetime.value = pagos.reduce(
    (sum, p) => sum + Number(p.monto_agencia || 0),
    0
  );

  // BAR CHART
  const days = {};
  for (let i = 9; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = d.toISOString().slice(0, 10);
    days[key] = 0;
  }

  pagos.forEach((p) => {
    const key = p.created_at.slice(0, 10);
    if (days[key] !== undefined) days[key] += Number(p.monto_agencia);
  });

  barLabels.value = Object.keys(days);
  barValues.value = Object.values(days);

  // LINE CHART
  const tickets = {};
  for (const key of barLabels.value) {
    tickets[key] = 0;
  }

  pagos.forEach((p) => {
    const key = p.created_at.slice(0, 10);
    if (tickets[key] !== undefined)
      tickets[key] += Number(p.boletos_vendidos || 0);
  });

  lineLabels.value = Object.keys(tickets);
  lineValues.value = Object.values(tickets);
};

onMounted(loadDashboard);
</script>
