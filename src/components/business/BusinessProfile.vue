<template>
  <div class="max-w-2xl mx-auto space-y-6">
    <h2 class="text-2xl font-bold text-gray-800">Mi Negocio</h2>

    <div class="bg-white rounded-2xl shadow-sm border p-6 space-y-5">
      <!-- Imagen -->
      <div class="flex items-center gap-5">
        <div class="w-24 h-24 rounded-2xl bg-gray-100 overflow-hidden border flex items-center justify-center text-4xl">
          <img v-if="form.image_url" :src="form.image_url" class="w-full h-full object-cover" />
          <PhStorefront v-else :size="36" class="text-gray-300" />
        </div>
        <div>
          <label class="block text-sm font-semibold text-gray-600 mb-1">URL de imagen</label>
          <input v-model="form.image_url" type="url" placeholder="https://..." class="input-field w-64" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-700 mb-1">Nombre del negocio *</label>
        <input v-model="form.name" type="text" required class="input-field" />
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-700 mb-1">Descripción</label>
        <textarea v-model="form.description" rows="3" class="input-field resize-none" placeholder="Describe tu negocio o atracción..."></textarea>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-1">Categoría</label>
          <select v-model="form.category" class="input-field bg-white">
            <option value="cascada">Cascada</option>
            <option value="deporte">Deporte extremo</option>
            <option value="termas">Termas</option>
            <option value="restaurante">Restaurante</option>
            <option value="otro">Otro</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-semibold text-gray-700 mb-1">Dirección</label>
          <input v-model="form.address" type="text" class="input-field" placeholder="Ej: Av. Amazónica km 2" />
        </div>
      </div>

      <div class="flex items-center gap-3">
        <input v-model="form.active" type="checkbox" id="active" class="w-4 h-4 accent-orange-600" />
        <label for="active" class="text-sm font-medium text-gray-700">Negocio activo (visible en la landing)</label>
      </div>

      <div v-if="saved" class="text-green-600 font-semibold text-sm">Cambios guardados</div>
      <div v-if="error" class="text-red-500 text-sm">{{ error }}</div>

      <button @click="save" :disabled="saving" class="w-full bg-orange-600 hover:bg-orange-700 text-white py-3 rounded-xl font-semibold transition">
        {{ saving ? 'Guardando...' : 'Guardar cambios' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'
import { PhStorefront } from '@phosphor-icons/vue'

const authStore = useAuthStore()
const saving = ref(false)
const saved = ref(false)
const error = ref('')
const businessId = ref(null)

const form = ref({
  name: '',
  description: '',
  category: 'otro',
  address: '',
  image_url: '',
  active: true,
})

onMounted(async () => {
  const uid = authStore.user?.id
  const { data } = await supabase.from('businesses').select('*').eq('owner_id', uid).single()
  if (data) {
    businessId.value = data.id
    form.value = { name: data.name, description: data.description, category: data.category, address: data.address ?? '', image_url: data.image_url ?? '', active: data.active }
  }
})

const save = async () => {
  saving.value = true
  error.value = ''
  saved.value = false
  const uid = authStore.user?.id
  const payload = { ...form.value, owner_id: uid }

  let res
  if (businessId.value) {
    res = await supabase.from('businesses').update(payload).eq('id', businessId.value)
  } else {
    res = await supabase.from('businesses').insert(payload).select().single()
    if (res.data) businessId.value = res.data.id
  }

  if (res.error) { error.value = res.error.message } else { saved.value = true }
  saving.value = false
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
  box-shadow: 0 0 0 2px #ea580c;
}
</style>
