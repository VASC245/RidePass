// src/stores/chivasStore.js
import { defineStore } from 'pinia';
import { supabase } from '@/lib/supabase';

export const useChivasStore = defineStore('chivas', {
  state: () => ({
    chivas: [],
    loading: false,
  }),

  actions: {
    async fetchChivas() {
      this.loading = true;
      const { data, error } = await supabase
        .from('chivas')
        .select('*, drivers(*)')
        .order('created_at', { ascending: false });
      this.loading = false;
      if (error) throw error;
      this.chivas = data || [];
    },

    async createChiva({ code, plate, driver_id }) {
      const { data, error } = await supabase
        .from('chivas')
        .insert([{ code, plate, driver_id }])
        .select()
        .single();
      if (error) throw error;
      this.chivas.unshift(data);
    },

    async assignDriver(chiva_id, driver_id) {
      const { data, error } = await supabase
        .from('chivas')
        .update({ driver_id })
        .eq('id', chiva_id)
        .select()
        .single();
      if (error) throw error;
      const idx = this.chivas.findIndex(c => c.id === chiva_id);
      if (idx >= 0) this.chivas[idx] = data;
    },
  },
});
