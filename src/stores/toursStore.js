// src/stores/toursStore.js
import { defineStore } from "pinia";
import { supabase } from "@/lib/supabase";

// Cuántas salidas trae la página pública. Con miles de salidas históricas
// esto evita descargar toda la tabla: solo las próximas y activas.
const PUBLIC_LIMIT = 200;

export const useToursStore = defineStore("tours", {
  state: () => ({
    tours: [],
    loading: false,
    error: null,
    loadedAt: 0,
  }),

  actions: {
    // Próximas salidas activas (público, agencias). Cachea 60 s para no
    // repetir la consulta al navegar entre landing y /tours.
    async fetchTours({ force = false } = {}) {
      if (!force && this.tours.length && Date.now() - this.loadedAt < 60_000) return;

      this.loading = true;
      this.error = null;

      try {
        const { data, error } = await supabase
          .from("assigned_chivas")
          .select(`
            id,
            status,
            departure_at,
            owner_id,
            sales_open,
            tours ( id, title, base_price, duration, active, allow_agency_sales ),
            chivas ( name, plate )
          `)
          .in("status", ["pendiente", "en_curso"])
          .eq("sales_open", true)
          .gte("departure_at", new Date(Date.now() - 30 * 60_000).toISOString())
          .order("departure_at", { ascending: true })
          .limit(PUBLIC_LIMIT);

        if (error) throw error;

        // RLS ya oculta tours inactivos y vendedores no públicos para el
        // resto; este filtro cubre al propio dueño, que sí ve los suyos.
        this.tours = (data ?? [])
          .filter((item) => item.tours?.title && item.tours?.active !== false)
          .map((item) => ({
            id: item.id,
            tour_id: item.tours?.id,
            title: item.tours?.title,
            base_price: item.tours?.base_price,
            duration: item.tours?.duration,
            allow_agency_sales: item.tours?.allow_agency_sales !== false,
            chiva_name: item.chivas?.name,
            plate: item.chivas?.plate,
            status: item.status,
            departure_at: item.departure_at,
            owner_id: item.owner_id,
            formattedHour: new Date(item.departure_at).toLocaleTimeString("es-EC", {
              hour: "2-digit",
              minute: "2-digit",
            }),
          }));
        this.loadedAt = Date.now();
      } catch (err) {
        console.error("Error cargando tours:", err);
        this.error = "Error cargando tours.";
      } finally {
        this.loading = false;
      }
    },
  },
});
