<template>
  <div class="bg-white p-6 rounded-2xl shadow border border-gray-100">
    <h3 class="text-lg font-semibold mb-4 text-gray-800">{{ title }}</h3>
    <canvas ref="canvas"></canvas>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from "vue";
import Chart from "chart.js/auto";

const props = defineProps({
  title: String,
  labels: Array,
  data: Array,
});

const canvas = ref(null);
let chart;

const renderChart = () => {
  if (chart) chart.destroy();

  chart = new Chart(canvas.value, {
    type: "bar",
    data: {
      labels: props.labels,
      datasets: [
        {
          label: props.title,
          data: props.data,
          backgroundColor: "#2563eb",
        },
      ],
    },
    options: {
      responsive: true,
    },
  });
};

onMounted(renderChart);
watch(() => [props.labels, props.data], renderChart);
</script>
