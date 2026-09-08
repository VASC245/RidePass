import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { banosDirectory } from '@/data/banosDirectory'

// Normaliza nombres para comparar (minúsculas, sin tildes, sin artículos iniciales)
const normalizeName = (name) =>
  String(name ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/^(la|el|los|las)\s+/, '')
    .trim()

// Negocios/atracciones activos con conteo de eventos activos,
// más el directorio curado de Baños como fichas informativas.
export function useBusinesses() {
  const businesses = ref([])
  const loading    = ref(true)

  const fetchBusinesses = async () => {
    loading.value = true
    try {
      const { data, error } = await supabase
        .from('businesses')
        .select('*, business_events(id, status, event_date)')
        .eq('active', true)
        .order('name')
      if (error) throw error
      const now = Date.now()
      businesses.value = (data ?? []).map(b => ({
        ...b,
        events_count: (b.business_events ?? [])
          .filter(e => e.status === 'activo' && new Date(e.event_date).getTime() >= now).length,
      }))
    } catch (e) {
      console.error('businesses fetch:', e.message)
      businesses.value = []
    } finally {
      loading.value = false
    }
  }

  // Afiliadas primero; luego el directorio, ocultando las que ya están registradas
  const catalog = computed(() => {
    const registered = new Set(businesses.value.map(b => normalizeName(b.name)))
    const directory = banosDirectory
      .filter(d => !registered.has(normalizeName(d.name)))
      .map(d => ({ ...d, unaffiliated: true, events_count: 0 }))
    return [...businesses.value, ...directory]
  })

  return { businesses, catalog, loading, fetchBusinesses }
}
