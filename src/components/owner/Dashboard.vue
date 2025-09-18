<template>
  <div class="max-w-6xl mx-auto space-y-6">
    <h1 class="text-2xl font-bold text-gray-700">👑 Dashboard de Dueño</h1>

    <!-- Métricas -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <div v-for="card in cards" :key="card.label" class="bg-white rounded-xl shadow-md p-5">
        <p class="text-gray-500 text-sm">{{ card.label }}</p>
        <p class="text-2xl font-bold mt-2">{{ card.value }}</p>
      </div>
    </div>

    <!-- Botón de reporte -->
    <div class="bg-white rounded-xl shadow-md p-6">
      <h2 class="text-lg font-bold mb-4">Generar reporte</h2>
      <button
        @click="downloadReport"
        class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded"
      >
        Descargar reporte PDF
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

const auth = useAuthStore();
const cards = ref([]);

const loadMetrics = async () => {
  if (!auth.user) return;

  const ownerId = auth.user.id;

  // Tours en marcha
  const { count: toursEnMarcha } = await supabase
    .from("assigned_chivas")
    .select("*", { count: "exact", head: true })
    .eq("user_id", ownerId)
    .eq("status", "en_curso");

  // Tours creados
  const { count: toursCreados } = await supabase
    .from("tours")
    .select("*", { count: "exact", head: true })
    .eq("user_id", ownerId);

  // Conductores
  const { count: conductores } = await supabase
    .from("drivers")
    .select("*", { count: "exact", head: true })
    .eq("owner_id", ownerId);

  // Asientos vendidos en el día
  const today = new Date().toISOString().split("T")[0];
  const { count: asientosVendidos } = await supabase
    .from("seats")
    .select("id", { count: "exact", head: true })
    .eq("status", "pagado")
    .gte("created_at", `${today}T00:00:00`)
    .lte("created_at", `${today}T23:59:59`);

  // Tours realizados en el día (finalizados hoy)
  const { count: toursHechos } = await supabase
    .from("assigned_chivas")
    .select("*", { count: "exact", head: true })
    .eq("user_id", ownerId)
    .gte("created_at", `${today}T00:00:00`)
    .lte("created_at", `${today}T23:59:59`)
    .eq("status", "finalizado");

  cards.value = [
    { label: "Tours en marcha", value: toursEnMarcha || 0 },
    { label: "Tours creados", value: toursCreados || 0 },
    { label: "Conductores", value: conductores || 0 },
    { label: "Asientos vendidos hoy", value: asientosVendidos || 0 },
    { label: "Tours hechos hoy", value: toursHechos || 0 },
  ];
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

onMounted(() => {
  loadMetrics();
});
</script>
