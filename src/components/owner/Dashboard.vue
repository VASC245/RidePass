<template>
  <div class="max-w-7xl mx-auto py-10 space-y-10 px-6">
    <!-- Título -->
    <h1 class="text-3xl font-extrabold text-gray-800 text-center">
      👑 Dashboard de Dueño
    </h1>

    <!-- Métricas -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <div
        v-for="card in cards"
        :key="card.label"
        class="bg-gradient-to-br from-white to-gray-50 border border-gray-200 rounded-2xl shadow-sm p-6 hover:shadow-md transition-all duration-200"
      >
        <p class="text-gray-500 text-sm">{{ card.label }}</p>
        <p class="text-3xl font-extrabold text-gray-800 mt-2">
          {{ card.value }}
        </p>
      </div>
    </div>

    <!-- Gráfico de tours -->
    <div class="bg-white rounded-2xl shadow-md border border-gray-200 p-8">
      <h2 class="text-xl font-bold text-gray-800 mb-4 flex items-center gap-2">
        📊 Tours del Día
      </h2>
      <BarChart
        v-if="chartData"
        :chart-data="chartData"
        :chart-options="chartOptions"
      />
      <p v-else class="text-gray-500 text-center italic mt-4">
        No hay datos para mostrar.
      </p>
    </div>

    <!-- Gráfico de ingresos -->
    <div class="bg-white rounded-2xl shadow-md border border-gray-200 p-8">
      <h2 class="text-xl font-bold text-gray-800 mb-4 flex items-center gap-2">
        💵 Ingresos del Día
      </h2>
      <BarChart
        v-if="incomeChartData"
        :chart-data="incomeChartData"
        :chart-options="chartOptions"
      />
      <p v-else class="text-gray-500 text-center italic mt-4">
        No hay datos de ingresos.
      </p>
    </div>

    <!-- Botón de reporte -->
    <div class="bg-white rounded-2xl shadow-md border border-gray-200 p-8 text-center">
      <h2 class="text-xl font-bold text-gray-800 mb-4">📄 Generar Reporte Diario</h2>
      <button
        @click="downloadReport"
        class="bg-green-600 hover:bg-green-700 text-white px-6 py-3 rounded-xl font-semibold shadow-sm transition active:scale-95"
      >
        📥 Descargar Reporte PDF
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "@/lib/supabase";
import { useAuthStore } from "@/stores/authStore";
import jsPDF from "jspdf";
import "jspdf-autotable";
import BarChart from "@/components/ui/BarChart.vue";

const auth = useAuthStore();
const cards = ref([]);
const chartData = ref(null);
const incomeChartData = ref(null);

const chartOptions = ref({
  responsive: true,
  plugins: { legend: { display: false } },
});

const loadMetrics = async () => {
  if (!auth.user) return;

  const ownerId = auth.user.id;
  const today = new Date().toISOString().split("T")[0];

  // Tours programados
  const { count: toursProgramados } = await supabase
    .from("assigned_chivas")
    .select("*", { count: "exact", head: true })
    .eq("user_id", ownerId)
    .eq("status", "pendiente");

  // Tours en curso
  const { count: toursEnCurso } = await supabase
    .from("assigned_chivas")
    .select("*", { count: "exact", head: true })
    .eq("user_id", ownerId)
    .eq("status", "en_curso");

  // Tours finalizados
  const { count: toursFinalizados } = await supabase
    .from("assigned_chivas")
    .select("*", { count: "exact", head: true })
    .eq("user_id", ownerId)
    .eq("status", "finalizado")
    .gte("updated_at", `${today}T00:00:00`)
    .lte("updated_at", `${today}T23:59:59`);

  // Ingresos del día
  const { data: ventas, error: ventasError } = await supabase
    .from("seats")
    .select(
      `
      id,
      assigned_chiva_id,
      status,
      created_at,
      assigned_chivas (
        tours ( base_price, user_id )
      )
    `
    )
    .eq("status", "pagado")
    .gte("created_at", `${today}T00:00:00`)
    .lte("created_at", `${today}T23:59:59`);

  if (ventasError) console.error("Error cargando ingresos:", ventasError);

  const ingresosTotales = (ventas || [])
    .filter((v) => v.assigned_chivas?.tours?.user_id === ownerId)
    .reduce((acc, v) => acc + (v.assigned_chivas?.tours?.base_price || 0), 0);

  cards.value = [
    { label: "Tours Programados", value: toursProgramados || 0 },
    { label: "Tours en Curso", value: toursEnCurso || 0 },
    { label: "Tours Finalizados Hoy", value: toursFinalizados || 0 },
    { label: "Ingresos de Hoy", value: `$${ingresosTotales}` },
  ];

  // Datos gráficos
  chartData.value = {
    labels: ["Programados", "En Curso", "Finalizados"],
    datasets: [
      {
        label: "Cantidad de Tours",
        data: [toursProgramados || 0, toursEnCurso || 0, toursFinalizados || 0],
        backgroundColor: ["#3B82F6", "#F59E0B", "#10B981"],
        borderRadius: 6,
      },
    ],
  };

  incomeChartData.value = {
    labels: ["Ingresos del Día"],
    datasets: [
      {
        label: "USD",
        data: [ingresosTotales],
        backgroundColor: ["#22C55E"],
        borderRadius: 6,
      },
    ],
  };
};

// Generar PDF
const downloadReport = () => {
  const doc = new jsPDF();
  doc.text("Reporte Diario - ChivaPass", 14, 20);
  const rows = cards.value.map((card) => [card.label, card.value]);
  doc.autoTable({
    head: [["Métrica", "Valor"]],
    body: rows,
    startY: 30,
  });
  doc.save("reporte_chivapass.pdf");
};

onMounted(loadMetrics);
</script>
