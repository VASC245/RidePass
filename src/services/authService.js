import { supabase } from "@/lib/supabase";

// Registro de usuario
export const registerUser = async ({ full_name, email, password, role }) => {
  const { data, error } = await supabase
    .from("users")
    .insert([{ full_name, email, password, role }])
    .select()
    .single();

  if (error) throw error;
  return data;
};

// Login de usuario
export const loginUser = async ({ email, password }) => {
  const { data, error } = await supabase
    .from("users")
    .select("id, full_name, email, role")
    .eq("email", email)
    .eq("password", password)
    .single();

  if (error) throw error;
  // Guardar en localStorage
  localStorage.setItem("user", JSON.stringify(data));
  return data;
};

// Obtener usuario actual
export const getCurrentUser = () => {
  const user = localStorage.getItem("user");
  return user ? JSON.parse(user) : null;
};

// Logout
export const logoutUser = () => {
  localStorage.removeItem("user");
};
