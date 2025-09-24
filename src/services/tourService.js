// src/services/tourService.js
import { supabase } from "@/lib/supabase";

/**
 * Obtiene tours asignados según filtros
 * @param {Object} options
 * @param {string} [options.userId] - Si se pasa, filtra tours creados por ese dueño
 * @param {string} [options.chivaId] - Si se pasa, filtra tours de esa chiva (conductor)
 * @returns {Promise<Array>}
 */
export async function fetchAssignedTours({ userId = null, chivaId = null } = {}) {
  try {
    let query = supabase
      .from("assigned_chivas")
      .select(`
        id,
        departure_at,
        status,
        tours ( id, title, base_price, user_id ),
        chivas ( id, name )
      `)
      .order("departure_at", { ascending: true });

    if (userId) query = query.eq("tours.user_id", userId);
    if (chivaId) query = query.eq("chiva_id", chivaId);

    const { data, error } = await query;
    if (error) throw error;

    return data || [];
  } catch (err) {
    console.error("❌ Error al cargar tours asignados:", err);
    return [];
  }
}

/**
 * Cambia el estado de un tour
 * @param {string} id - ID del assigned_chiva
 * @param {"pendiente"|"en_curso"|"finalizado"} newStatus
 */
export async function updateTourStatus(id, newStatus) {
  try {
    if (newStatus === "finalizado") {
      // 🚀 Eliminar asientos y asignación
      await supabase.from("seats").delete().eq("assigned_chiva_id", id);
      await supabase.from("assigned_chivas").delete().eq("id", id);
    } else {
      await supabase.from("assigned_chivas").update({ status: newStatus }).eq("id", id);
    }
    return true;
  } catch (err) {
    console.error("❌ Error actualizando tour:", err);
    return false;
  }
}

/**
 * Finaliza un tour directamente
 * @param {string} id
 */
export async function finalizarTour(id) {
  return updateTourStatus(id, "finalizado");
}
