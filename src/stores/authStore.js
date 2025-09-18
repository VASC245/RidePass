// src/stores/authStore.js
import { defineStore } from "pinia";
import { supabase } from "@/lib/supabase";

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
  }),

  actions: {
    async init() {
      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (session?.user) {
        await this.loadUserProfile(session.user.id);
      }
    },

    async login(email, password) {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });
      if (error) throw error;

      if (data.user) {
        await this.loadUserProfile(data.user.id);
      }
    },

    async register(fullName, email, password, role) {
      // 1. Crear usuario en Supabase Auth
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
      });
      if (error) throw error;

      if (data.user) {
        // 2. Insertar en tabla "users" personalizada
        const { error: insertError } = await supabase.from("users").insert([
          {
            id: data.user.id,
            full_name: fullName,
            email,
            role: role || "agencia", // 👈 por defecto "agencia" si no se pasa rol
          },
        ]);
        if (insertError) throw insertError;

        // 3. Cargar perfil en el store
        await this.loadUserProfile(data.user.id);
      }
    },

    async loadUserProfile(userId) {
      const { data, error } = await supabase
        .from("users")
        .select("id, full_name, email, role")
        .eq("id", userId)
        .single();

      if (error) throw error;
      this.user = data;
    },

    async logout() {
      await supabase.auth.signOut();
      this.user = null;
    },

    getCurrentUser() {
      return this.user;
    },
  },
});
