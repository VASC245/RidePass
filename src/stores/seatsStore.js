import { defineStore } from "pinia";
import api from "@/api";

export const useSeatsStore = defineStore("seats", {
  state: () => ({
    seats: [],
    loading: false,
    error: null
  }),

  actions: {
    async fetchSeats(assignedId) {
      this.loading = true;
      this.error = null;

      try {
        const res = await api.get(`/seats/${assignedId}`);
        this.seats = res.data || [];
      } catch (err) {
        console.error("❌ Error cargando asientos:", err);
        this.error = "Error cargando asientos.";
      } finally {
        this.loading = false;
      }
    },

    clearSeats() {
      this.seats = [];
      this.error = null;
      this.loading = false;
    }
  }
});
