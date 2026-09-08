<template>
  <div class="space-y-6">
    <div class="flex items-center justify-between">
      <h2 class="text-2xl font-bold text-gray-800">Mis Eventos</h2>
      <button @click="openNew" class="bg-purple-600 hover:bg-purple-700 text-white px-5 py-2.5 rounded-xl font-semibold text-sm transition">
        + Nuevo evento
      </button>
    </div>

    <!-- Lista -->
    <div v-if="loading" class="text-center py-12 text-gray-400">Cargando eventos...</div>
    <div v-else-if="events.length === 0" class="text-center py-12 text-gray-400">No tienes eventos aún.</div>
    <div v-else class="space-y-3">
      <div
        v-for="ev in events"
        :key="ev.id"
        class="bg-white rounded-2xl shadow-sm border p-5 flex items-center justify-between gap-4"
      >
        <div class="flex-1 min-w-0">
          <p class="font-bold text-gray-800 truncate">{{ ev.title }}</p>
          <p class="text-sm text-gray-500 mt-0.5">{{ formatDate(ev.event_date) }}</p>
          <div class="flex items-center gap-3 mt-2 text-xs text-gray-500">
            <span class="bg-green-50 text-green-700 px-2 py-0.5 rounded-full font-semibold">${{ ev.price }}</span>
            <span>{{ ev.capacity }} cupos</span>
            <span v-if="ev.duration_minutes">{{ ev.duration_minutes }} min</span>
          </div>
        </div>
        <div class="flex flex-col items-end gap-2 shrink-0">
          <span
            class="text-xs px-2.5 py-1 rounded-full font-semibold"
            :class="{
              'bg-green-100 text-green-700': ev.status === 'activo',
              'bg-red-100 text-red-600': ev.status === 'agotado',
              'bg-gray-100 text-gray-500': ev.status === 'cancelado' || ev.status === 'finalizado',
            }"
          >{{ ev.status }}</span>
          <div class="flex gap-2">
            <button @click="openEdit(ev)" class="text-xs text-purple-600 hover:underline font-semibold">Editar</button>
            <button @click="deleteEvent(ev.id)" class="text-xs text-red-500 hover:underline font-semibold">Eliminar</button>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="showModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div class="bg-white rounded-2xl w-full max-w-lg shadow-2xl p-6 space-y-4">
        <h3 class="text-xl font-bold text-gray-800">{{ editing ? 'Editar evento' : 'Nuevo evento' }}</h3>

        <div>
          <label class="label">Título *</label>
          <input v-model="form.title" type="text" class="input-field" placeholder="Ej: Rafting río Pastaza" />
        </div>
        <div>
          <label class="label">Descripción</label>
          <textarea v-model="form.description" rows="2" class="input-field resize-none"></textarea>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Precio ($) *</label>
            <input v-model.number="form.price" type="number" min="0" step="0.01" class="input-field" />
          </div>
          <div>
            <label class="label">Capacidad *</label>
            <input v-model.number="form.capacity" type="number" min="1" class="input-field" />
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="label">Fecha y hora *</label>
            <input v-model="form.event_date" type="datetime-local" class="input-field" />
          </div>
          <div>
            <label class="label">Duración (minutos)</label>
            <input v-model.number="form.duration_minutes" type="number" min="1" class="input-field" />
          </div>
        </div>
        <div>
          <label class="label">Estado</label>
          <select v-model="form.status" class="input-field bg-white">
            <option value="activo">Activo</option>
            <option value="agotado">Agotado</option>
            <option value="cancelado">Cancelado</option>
            <option value="finalizado">Finalizado</option>
          </select>
        </div>

        <div v-if="formError" class="text-red-500 text-sm">{{ formError }}</div>

        <div class="flex gap-3 pt-2">
          <button @click="showModal = false" class="flex-1 py-2.5 rounded-xl border border-gray-300 text-gray-600 font-semibold text-sm hover:bg-gray-50">
            Cancelar
          </button>
          <button @click="save" :disabled="saving" class="flex-1 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white font-semibold text-sm transition">
            {{ saving ? 'Guardando...' : 'Guardar' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'

const authStore = useAuthStore()
const loading = ref(true)
const saving = ref(false)
const events = ref([])
const showModal = ref(false)
const editing = ref(null)
const formError = ref('')
const businessId = ref(null)

const emptyForm = () => ({ title: '', description: '', price: 0, capacity: 50, event_date: '', duration_minutes: null, status: 'activo' })
const form = ref(emptyForm())

const formatDate = (d) => new Date(d).toLocaleDateString('es-EC', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })

onMounted(async () => {
  const uid = authStore.user?.id
  const { data: biz } = await supabase.from('businesses').select('id').eq('owner_id', uid).single()
  if (biz) businessId.value = biz.id
  await fetchEvents()
})

const fetchEvents = async () => {
  loading.value = true
  const uid = authStore.user?.id
  const { data } = await supabase.from('business_events').select('*').eq('owner_id', uid).order('event_date')
  events.value = data ?? []
  loading.value = false
}

const openNew = () => {
  editing.value = null
  form.value = emptyForm()
  formError.value = ''
  showModal.value = true
}

const openEdit = (ev) => {
  editing.value = ev.id
  form.value = {
    title: ev.title,
    description: ev.description,
    price: ev.price,
    capacity: ev.capacity,
    event_date: ev.event_date?.slice(0, 16),
    duration_minutes: ev.duration_minutes,
    status: ev.status,
  }
  formError.value = ''
  showModal.value = true
}

const save = async () => {
  if (!form.value.title || !form.value.event_date) { formError.value = 'Título y fecha son obligatorios'; return }
  if (!businessId.value) { formError.value = 'Primero configura tu perfil de negocio'; return }
  saving.value = true
  formError.value = ''

  const payload = { ...form.value, business_id: businessId.value, owner_id: authStore.user?.id }

  const res = editing.value
    ? await supabase.from('business_events').update(payload).eq('id', editing.value)
    : await supabase.from('business_events').insert(payload)

  if (res.error) { formError.value = res.error.message } else { showModal.value = false; await fetchEvents() }
  saving.value = false
}

const deleteEvent = async (id) => {
  if (!confirm('¿Eliminar este evento? Se borrarán también sus tickets.')) return
  await supabase.from('business_events').delete().eq('id', id)
  await fetchEvents()
}
</script>

<style scoped>
.input-field {
  width: 100%;
  padding: 0.625rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.75rem;
  box-shadow: 0 1px 2px 0 rgb(0 0 0/0.05);
  font-size: 0.875rem;
  outline: none;
}
.input-field:focus {
  box-shadow: 0 0 0 2px #a855f7;
}
.label {
  display: block;
  font-size: 0.875rem;
  font-weight: 600;
  color: #374151;
  margin-bottom: 0.25rem;
}
</style>
