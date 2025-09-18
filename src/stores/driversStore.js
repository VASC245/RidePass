// src/stores/driversStore.js
import { defineStore } from 'pinia';
import { supabase } from '@/lib/supabase';

export const useDriversStore = defineStore('drivers', {
  state: () => ({
    drivers: [],
    loading: false,
  }),

  actions: {
    async fetchDrivers() {
      this.loading = true;
      const { data, error } = await supabase
        .from('drivers')
        .select('*')
        .order('created_at', { ascending: false });
      this.loading = false;
      if (error) throw error;
      this.drivers = data || [];
    },

    async createDriver({ full_name, phone }) {
      const { data, error } = await supabase
        .from('drivers')
        .insert([{ full_name, phone }])
        .select()
        .single();
      if (error) throw error;
      this.drivers.unshift(data);
    },
  },
});
