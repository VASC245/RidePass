// src/stores/cartStore.js
import { defineStore } from 'pinia'

export const useCartStore = defineStore('cart', {
  state: () => ({
    items: [], // ✅ Inicializa como arreglo
  }),

  getters: {
    totalItems: (state) => state.items.length,
    totalPrice: (state) => {
      return state.items.reduce((total, item) => {
        return total + (item.price || 0)
      }, 0)
    },
  },

  actions: {
    addItem(item) {
      const exists = this.items.find((i) => i.id === item.id)
      if (!exists) {
        this.items.push(item)
      }
    },

    removeItem(id) {
      this.items = this.items.filter((i) => i.id !== id)
    },

    clearCart() {
      this.items = []
    },
  },
})
