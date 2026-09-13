<template>
  <div class="max-w-lg mx-auto space-y-6">
    <h2 class="text-2xl font-bold text-gray-800">Escanear Entrada</h2>

    <!-- Cámara -->
    <div class="bg-black rounded-2xl overflow-hidden aspect-square relative">
      <video ref="videoEl" class="w-full h-full object-cover" playsinline autoplay muted></video>
      <canvas ref="canvasEl" class="hidden"></canvas>
      <div class="absolute inset-0 border-4 border-orange-400 rounded-2xl pointer-events-none opacity-50"></div>
      <p v-if="!scanning" class="absolute inset-0 flex items-center justify-center text-white text-sm font-semibold bg-black/60 rounded-2xl">
        Presiona "Iniciar" para abrir la cámara
      </p>
    </div>

    <button
      @click="scanning ? stopScan() : startScan()"
      class="w-full py-3 rounded-xl font-bold text-white transition"
      :class="scanning ? 'bg-red-500 hover:bg-red-600' : 'bg-orange-600 hover:bg-orange-700'"
    >
      {{ scanning ? 'Detener cámara' : 'Iniciar escaneo' }}
    </button>

    <!-- Resultado -->
    <transition name="fade">
      <div
        v-if="result"
        class="rounded-2xl p-5 border-2 shadow-sm"
        :class="result.ok ? 'bg-green-50 border-green-400' : 'bg-red-50 border-red-400'"
      >
        <p class="text-xl font-extrabold mb-2" :class="result.ok ? 'text-green-700' : 'text-red-600'">
          {{ result.ok ? 'Entrada válida' : 'Entrada inválida' }}
        </p>
        <template v-if="result.ticket">
          <p class="font-semibold text-gray-800">{{ result.ticket.customer_name }}</p>
          <p class="text-sm text-gray-600">{{ result.ticket.business_events?.title }}</p>
          <p class="text-sm text-gray-500">{{ result.ticket.quantity }} entrada(s)</p>
        </template>
        <p v-if="result.msg" class="text-sm mt-1 font-medium" :class="result.ok ? 'text-green-600' : 'text-red-500'">{{ result.msg }}</p>
        <button @click="result = null" class="mt-3 text-sm text-gray-500 hover:underline">Escanear otro</button>
      </div>
    </transition>

    <!-- Manual -->
    <div class="bg-white rounded-2xl shadow-sm border p-5 space-y-3">
      <p class="font-semibold text-gray-700 text-sm">Buscar por código manualmente</p>
      <div class="flex gap-2">
        <input v-model="manualCode" type="text" placeholder="Pega el código QR aquí..." class="flex-1 px-4 py-2.5 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-orange-500 focus:outline-none" />
        <button @click="verifyCode(manualCode)" class="bg-orange-600 hover:bg-orange-700 text-white px-4 py-2.5 rounded-xl font-semibold text-sm transition">Verificar</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onUnmounted } from 'vue'
import { supabase } from '@/lib/supabase'
import jsQR from 'jsqr'

const videoEl = ref(null)
const canvasEl = ref(null)
const scanning = ref(false)
const result = ref(null)
const manualCode = ref('')
let stream = null
let rafId = null

const startScan = async () => {
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } })
  } catch {
    result.value = { ok: false, msg: 'No se pudo acceder a la cámara. Revisa los permisos del navegador.' }
    return
  }
  videoEl.value.srcObject = stream
  scanning.value = true
  tick()
}

const stopScan = () => {
  stream?.getTracks().forEach(t => t.stop())
  cancelAnimationFrame(rafId)
  scanning.value = false
}

const tick = () => {
  if (!scanning.value) return
  const video = videoEl.value
  if (video.readyState === video.HAVE_ENOUGH_DATA) {
    const canvas = canvasEl.value
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    const ctx = canvas.getContext('2d')
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
    const img = ctx.getImageData(0, 0, canvas.width, canvas.height)
    const code = jsQR(img.data, img.width, img.height)
    if (code?.data) { stopScan(); verifyCode(code.data); return }
  }
  rafId = requestAnimationFrame(tick)
}

// use_business_ticket marca la entrada como usada de forma atómica: si dos
// personas escanean el mismo QR a la vez, solo una recibe "ok".
const verifyCode = async (payload) => {
  const code = String(payload ?? '').trim()
  if (!code) return
  const { data, error } = await supabase.rpc('use_business_ticket', { p_qr: code })
  if (error) {
    console.error('use_business_ticket:', error.message)
    result.value = { ok: false, msg: 'No se pudo validar la entrada. Intenta de nuevo.' }
    return
  }
  const ticket = {
    customer_name: data?.customer ?? '',
    quantity: data?.quantity ?? '',
    business_events: { title: data?.event ?? '' },
    used: data?.ok || data?.code === 'ALREADY_USED',
    payment_status: data?.code === 'NOT_PAID' ? 'pendiente' : 'verificado',
  }
  result.value = data?.ok
    ? { ok: true, ticket, msg: 'Entrada válida. Bienvenido.' }
    : { ok: false, ticket: data?.code === 'NOT_FOUND' ? null : ticket, msg: data?.message ?? 'Entrada no válida.' }
  manualCode.value = ''
}

onUnmounted(stopScan)
</script>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity 0.3s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
