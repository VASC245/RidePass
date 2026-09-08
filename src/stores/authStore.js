// src/stores/authStore.js
import { defineStore } from "pinia";
import { supabase } from "@/lib/supabase";

const PROFILE_FIELDS = "id, full_name, email, role, plan";

let listening = false;

export const useAuthStore = defineStore("auth", {
  state: () => ({
    user: null,
    ready: false,
  }),

  actions: {
    async init() {
      if (!listening) {
        listening = true;
        // Mantiene el store sincronizado con la sesión real (expiración,
        // logout en otra pestaña, refresh de token).
        supabase.auth.onAuthStateChange((event, session) => {
          if (event === "SIGNED_OUT" || !session?.user) {
            this.user = null;
          } else if (!this.user || this.user.id !== session.user.id) {
            this.loadUserProfile(session.user.id).catch(() => (this.user = null));
          }
        });
      }

      const { data: { session } } = await supabase.auth.getSession();
      if (session?.user) {
        await this.loadUserProfile(session.user.id);
      } else {
        this.user = null;
      }
      this.ready = true;
    },

    async login(email, password) {
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
      if (data.user) await this.loadUserProfile(data.user.id);
    },

    // ownerCode: código de invitación requerido para registrarse como dueño
    // (lo valida el trigger handle_new_user en la base de datos).
    async register(fullName, email, password, role, ownerCode = "") {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: {
            full_name: fullName,
            role: role || "agencia",
            ...(ownerCode ? { owner_code: ownerCode } : {}),
          },
        },
      });
      if (error) throw error;

      // El perfil lo crea el trigger. Solo se carga si ya hay sesión
      // (proyectos sin confirmación de correo).
      if (data.user && data.session) {
        await this.loadUserProfile(data.user.id);
      }
      return data;
    },

    async loadUserProfile(userId) {
      const { data, error } = await supabase
        .from("users")
        .select(PROFILE_FIELDS)
        .eq("id", userId)
        .single();

      if (error) throw error;
      this.user = data;
      return data;
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
