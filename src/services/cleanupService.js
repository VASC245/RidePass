import { supabase } from '@/lib/supabase';

/**
 * Libera asientos de tours terminados
 */
export const releaseSeats = async () => {
  const { error } = await supabase.rpc('release_seats');
  if (error) {
    console.error('❌ Error al liberar asientos:', error);
  } else {
    console.log('✅ Asientos liberados automáticamente');
  }
};

/**
 * Ejecuta limpieza periódica
 */
export const runCleanup = async () => {
  console.log('♻️ Ejecutando limpieza...');
  await releaseSeats();
};
