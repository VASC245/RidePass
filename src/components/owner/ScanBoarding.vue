<template>
  <BaseCard class="max-w-2xl mx-auto">
    <h2 class="text-xl font-bold mb-4">Escaneo de QR - Embarque</h2>

    <div class="space-y-4">
      <!-- Cámara -->
      <video
        ref="videoRef"
        autoplay
        playsinline
        class="w-full rounded-lg border"
      ></video>

      <!-- Estado -->
      <div v-if="scanResult" class="p-3 rounded-lg" :class="scanResultClass">
        {{ scanResult }}
      </div>

      <!-- Botón manual -->
      <BaseButton full @click="startScanner">Reiniciar escáner</BaseButton>
    </div>
  </BaseCard>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, computed } from 'vue';
import jsQR from 'jsqr';
import { supabase } from '@/lib/supabase';

import BaseButton from '@/components/ui/BaseButton.vue';
import BaseCard from '@/components/ui/BaseCard.vue';

const videoRef = ref(null);
const scanResult = ref('');
const beep = new Audio('/beep.mp3'); // archivo beep.mp3 en public/

let stream = null;
let animationFrameId = null;

// 🔹 Escáner
const startScanner = async () => {
  scanResult.value = '';
  try {
    stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
    videoRef.value.srcObject = stream;
    requestAnimationFrame(tick);
  } catch (err) {
    console.error('Error accediendo a cámara:', err);
    scanResult.value = 'No se pudo acceder a la cámara';
  }
};

// 🔹 Leer frames y detectar QR
const tick = async () => {
  if (!videoRef.value || videoRef.value.readyState !== videoRef.value.HAVE_ENOUGH_DATA) {
    animationFrameId = requestAnimationFrame(tick);
    return;
  }

  const canvas = document.createElement('canvas');
  canvas.width = videoRef.value.videoWidth;
  canvas.height = videoRef.value.videoHeight;

  const ctx = canvas.getContext('2d');
  ctx.drawImage(videoRef.value, 0, 0, canvas.width, canvas.height);
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

  const code = jsQR(imageData.data, imageData.width, imageData.height, {
    inversionAttempts: 'dontInvert',
  });

  if (code) {
    await handleScan(code.data);
    return; // detener tras encontrar uno
  }

  animationFrameId = requestAnimationFrame(tick);
};

// 🔹 Procesar QR
const handleScan = async (qrText) => {
  try {
    // QR esperado: "Tour: X, Chiva: Y, Asientos: 10,15"
    const seatsMatch = qrText.match(/Asientos: ([\d, ]+)/);
    if (!seatsMatch) {
      scanResult.value = 'QR inválido';
      return;
    }

    const seats = seatsMatch[1].split(',').map(s => s.trim());

    // 🔹 Actualizar estado en Supabase
    await supabase
      .from('seats')
      .update({ status: 'abordado' })
      .in('seat_number', seats);

    scanResult.value = `✅ Pasajeros ${seats.join(', ')} abordados`;

    await playBeep();
  } catch (err) {
    console.error('Error procesando QR:', err);
    scanResult.value = 'Error procesando QR';
  }
};

// 🔹 Reproducir beep sin errores AbortError
const playBeep = async () => {
  try {
    beep.currentTime = 0;
    await beep.play();
  } catch (err) {
    if (err.name !== 'AbortError') {
      console.error('Error al reproducir beep:', err);
    }
  }
};

// 🔹 Limpieza al desmontar
onBeforeUnmount(() => {
  if (stream) {
    stream.getTracks().forEach(track => track.stop());
  }
  if (animationFrameId) {
    cancelAnimationFrame(animationFrameId);
  }
  beep.pause();
  beep.currentTime = 0;
});

// 🔹 Iniciar al montar
onMounted(() => {
  startScanner();
});

const scanResultClass = computed(() => {
  if (scanResult.value.startsWith('✅')) return 'bg-green-100 text-green-700';
  if (scanResult.value.startsWith('QR inválido')) return 'bg-yellow-100 text-yellow-700';
  if (scanResult.value.startsWith('Error')) return 'bg-red-100 text-red-700';
  return 'bg-gray-100 text-gray-700';
});
</script>
