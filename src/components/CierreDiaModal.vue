<template>
  <div class="fixed inset-0 bg-black bg-opacity-50 flex justify-center items-center z-50">
    <BaseCard class="w-full max-w-lg p-6 relative">
      <button @click="$emit('close')" class="absolute right-4 top-4 text-xl">✖</button>

      <h2 class="text-2xl font-bold mb-4 text-center">📅 Cierre del Día</h2>

      <label class="text-sm font-semibold mb-2">Seleccione fecha a cerrar</label>
      <input
        type="date"
        v-model="fecha"
        class="w-full border rounded-lg p-2 mb-4"
      />

      <BaseButton full @click="realizarCierre" :disabled="loading">
        {{ loading ? "Procesando..." : "Cerrar Día" }}
      </BaseButton>
    </BaseCard>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { supabase } from "@/lib/supabase";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";
import { useAuthStore } from "@/stores/authStore";

const props = defineProps({
  userType: String, // "owner" o "agency"
});
const emit = defineEmits(["completed", "close"]);

const auth = useAuthStore();
const fecha = ref("");
const loading = ref(false);

const realizarCierre = async () => {
  if (!fecha.value) {
    alert("Seleccione una fecha.");
    return;
  }

  loading.value = true;

  const userId = auth.user.id;

  // 1️⃣ Obtener ventas de ese día
  const { data: sales } = await supabase
    .from("sales")
    .select("*")
    .eq("created_at", fecha.value);

  // 2️⃣ Filtrar según tipo de usuario
  let filtered = [];

  if (props.userType === "owner") {
    filtered = sales.filter((s) => s.owner_id === userId);
  } else {
    filtered = sales.filter((s) => s.agency_id === userId);
  }

  const totalIncome = filtered.reduce((a, b) => a + b.total, 0);
  const ticketsSold = filtered.reduce((a, b) => a + b.seats.length, 0);

  // 3️⃣ Insertar reporte
  if (props.userType === "owner") {
    await supabase.from("daily_closure_owner").insert({
      owner_id: userId,
      date: fecha.value,
      total_income: totalIncome,
      tickets_sold: ticketsSold,
      created_at: new Date(),
    });
  } else {
    await supabase.from("daily_closure_agency").insert({
      agency_id: userId,
      date: fecha.value,
      total_income: totalIncome,
      tickets_sold: ticketsSold,
      created_at: new Date(),
    });
  }

  alert("✅ Cierre realizado con éxito");

  loading.value = false;
  emit("completed");
  emit("close");
};
</script>
