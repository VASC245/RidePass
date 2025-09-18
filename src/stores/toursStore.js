// src/stores/toursStore.js
import { defineStore } from 'pinia';
import { supabase } from '@/lib/supabase';

export const useToursStore = defineStore('tours', {
  state: () => ({
    tours: [],
    runs: [],
    loading: false,
  }),

  actions: {
    async fetchTours() {
      this.loading = true;
      const { data, error } = await supabase
        .from('tours')
        .select('*')
        .order('created_at', { ascending: false });
      this.loading = false;
      if (error) throw error;
      this.tours = data || [];
    },

    async createTour({ title, description, base_price }) {
      const { data, error } = await supabase
        .from('tours')
        .insert([{ title, description, base_price }])
        .select()
        .single();
      if (error) throw error;
      this.tours.unshift(data);
    },

    async fetchRuns() {
      const { data, error } = await supabase
        .from('tour_runs')
        .select('*, tours(*), chivas(*)')
        .order('departure_at', { ascending: true });
      if (error) throw error;
      this.runs = data || [];
    },

    async createRun({ tour_id, chiva_id, departure_at }) {
      const { data, error } = await supabase
        .from('tour_runs')
        .insert([{ tour_id, chiva_id, departure_at }])
        .select('*, tours(*), chivas(*)')
        .single();
      if (error) throw error;
      this.runs.push(data);
    }
  }
});
