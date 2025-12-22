// src/stores/toursStore.js
import { defineStore } from "pinia";
import { supabase } from "@/lib/supabase";

export const useToursStore = defineStore("tours", {
  state: () => ({
    tours: [],
    loading: false,
    error: null
  }),

  actions: {
    async fetchTours() {
      this.loading = true;
      this.error = null;

      try {
        // 🟦 Obtener tours programados: assigned_chivas + join con tours + chivas
        const { data, error } = await supabase
          .from("assigned_chivas")
          .select(`
            id,
            status,
            departure_at,
            tours (
              title,
              base_price,
              duration
            ),
            chivas (
              name,
              plate
            )
          `)
          .order("departure_at", { ascending: true });

        if (error) throw error;

        // 🟨 Mismo mapeo EXACTO que tu backend original
        this.tours = data.map((item) => ({
          id: item.id,
          title: item.tours?.title,
          base_price: item.tours?.base_price,
          duration: item.tours?.duration,
          chiva_name: item.chivas?.name,
          plate: item.chivas?.plate,
          status: item.status,
          departure_at: item.departure_at,
          formattedHour: new Date(item.departure_at).toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit"
          })
        }));

      } catch (err) {
        console.error("❌ Error cargando tours:", err);
        this.error = "Error cargando tours.";
      } finally {
        this.loading = false;
      }
    }
  }
});
