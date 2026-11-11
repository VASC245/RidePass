// Estado del plan del vendedor con sesión (RPC my_plan). Compartido entre el
// aviso del panel y la página de planes para no consultarlo dos veces.
import { ref, computed } from "vue";
import { supabase } from "@/lib/supabase";
import { daysUntil } from "@/lib/plans";

const plan = ref(null);
const loading = ref(false);
let loadedFor = null;

export function usePlan() {
  const load = async (userId, { force = false } = {}) => {
    if (!userId) { plan.value = null; loadedFor = null; return; }
    if (!force && loadedFor === userId && plan.value) return;
    loading.value = true;
    try {
      const { data, error } = await supabase.rpc("my_plan");
      if (error) throw error;
      plan.value = data;
      loadedFor = userId;
    } catch (e) {
      // Sin el plan el panel sigue funcionando; la base de datos bloquea igual.
      console.error("my_plan:", e?.message ?? e);
      plan.value = null;
    } finally {
      loading.value = false;
    }
  };

  const trialDaysLeft = computed(() => daysUntil(plan.value?.trial_ends_at));
  const paidDaysLeft = computed(() => daysUntil(plan.value?.expires_at));
  const usagePct = computed(() => {
    const limit = plan.value?.monthly_limit;
    return limit ? Math.min(1, (plan.value.used_this_month ?? 0) / limit) : 0;
  });

  return { plan, loading, load, trialDaysLeft, paidDaysLeft, usagePct };
}
