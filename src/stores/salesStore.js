// src/stores/salesStore.js
import { defineStore } from 'pinia';
import { supabase } from '@/lib/supabase';

export const useSalesStore = defineStore('sales', {
  state: () => ({
    seats: [],
    currentRunId: null
  }),

  actions: {
    async loadSeats(tour_run_id) {
      this.currentRunId = tour_run_id;
      const { data, error } = await supabase
        .from('tour_run_seats')
        .select('*')
        .eq('tour_run_id', tour_run_id)
        .order('seat_number', { ascending: true });
      if (error) throw error;
      this.seats = data || [];
    },

    async reserveSeat({ tour_run_id, seat_number, customer }) {
      let { data: c } = await supabase
        .from('customers')
        .select('*')
        .eq('email', customer.email)
        .maybeSingle();

      if (!c) {
        const result = await supabase
          .from('customers')
          .insert([{ full_name: customer.full_name, email: customer.email, phone: customer.phone }])
          .select()
          .single();
        if (result.error) throw result.error;
        c = result.data;
      }

      const { data, error } = await supabase
        .from('tickets')
        .insert([{
          tour_run_id,
          seat_number,
          status: 'reservado',
          customer_id: c.id
        }])
        .select()
        .single();

      if (error?.code === '23505') throw new Error('Ese asiento ya no está disponible.');
      if (error) throw error;

      return data;
    },

    async payTicket({ ticket_id, price_paid, qr_payload }) {
      const { data: updated, error } = await supabase
        .from('tickets')
        .update({ status: 'pagado', price_paid, qr_code: qr_payload })
        .eq('id', ticket_id)
        .select('*, customers(*)')
        .single();
      if (error) throw error;

      const res = await supabase.functions.invoke('send-ticket', {
        body: {
          ticket_id: updated.id,
          to_email: updated.customers?.email,
          to_name: updated.customers?.full_name,
          app_name: import.meta.env.VITE_PUBLIC_APP_NAME,
          qr_value: qr_payload
        }
      });

      if (res.error) console.error(res.error);

      return updated;
    },

    async boardTicket({ ticket_id }) {
      const { data: t, error } = await supabase
        .from('tickets')
        .update({ status: 'abordo' })
        .eq('id', ticket_id)
        .select()
        .single();
      if (error) throw error;

      await supabase.from('scans').insert([{ ticket_id: t.id }]);
      return t;
    }
  }
});
