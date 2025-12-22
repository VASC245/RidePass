// src/stores/cartStore.ts
import { defineStore } from "pinia";

export const useCartStore = defineStore("cart", {
  state: () => ({
    tour: null,
    seats: [],
  }),

  actions: {
    setTour(tour) {
      this.tour = tour;
    },

    addSeat(seat) {
      if (!this.seats.find(s => s.seat_number === seat.seat_number)) {
        this.seats.push(seat);
      }
    },

    removeSeat(number) {
      this.seats = this.seats.filter(s => s.seat_number !== number);
    },

    clearCart() {
      this.tour = null;
      this.seats = [];
    }
  },

  getters: {
    total(state) {
      if (!state.tour) return 0;
      return state.seats.length * state.tour.tours.base_price;
    }
  }
});
