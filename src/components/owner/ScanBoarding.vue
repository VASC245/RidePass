<template>
  <BaseCard class="max-w-2xl mx-auto p-8 border border-gray-200 shadow-md rounded-2xl">
    <!-- Título -->
    <h2 class="text-3xl font-extrabold text-center text-gray-800 mb-6">
      🎫 Escaneo de QR - Embarque
    </h2>

    <div class="space-y-6 text-center">
      <!-- Cámara -->
      <div class="relative">
        <video
          ref="videoRef"
          autoplay
          playsinline
          class="w-full rounded-2xl border-4 border-gray-200 shadow-md"
        ></video>
        <div
          class="absolute inset-0 border-4 border-dashed border-green-500 rounded-2xl pointer-events-none animate-pulse"
        ></div>
      </div>

      <!-- Estado -->
      <transition name="fade">
        <div
          v-if="scanResult"
          class="p-4 rounded-xl font-semibold text-lg shadow-sm"
          :class="scanResultClass"
        >
          {{ scanResult }}
        </div>
      </transition>

      <!-- Botón reiniciar -->
      <BaseButton
        full
        @click="startScanner"
        class="mt-4 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-xl transition active:scale-95"
      >
        🔄 Reiniciar escáner
      </BaseButton>
    </div>
  </BaseCard>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, computed } from "vue";
import jsQR from "jsqr";
import { supabase } from "@/lib/supabase";

import BaseButton from "@/components/ui/BaseButton.vue";
import BaseCard from "@/components/ui/BaseCard.vue";

const videoRef = ref(null);
const scanResult = ref("");
const beep = new Audio("/beep.mp3");

let stream = null;
let animationFrameId = null;

// 🔹 Iniciar cámara
const startScanner = async () => {
  scanResult.value = "";
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "environment" },
    });
    videoRef.value.srcObject = stream;
    requestAnimationFrame(tick);
  } catch (err) {
    console.error("Error accediendo a cámara:", err);
    scanResult.value = "❌ No se pudo acceder a la cámara.";
  }
};

// 🔹 Leer frames
const tick = async () => {
  if (
    !videoRef.value ||
    videoRef.value.readyState !== videoRef.value.HAVE_ENOUGH_DATA
  ) {
    animationFrameId = requestAnimationFrame(tick);
    return;
  }

  const canvas = document.createElement("canvas");
  canvas.width = videoRef.value.videoWidth;
  canvas.height = videoRef.value.videoHeight;

  const ctx = canvas.getContext("2d");
  ctx.drawImage(videoRef.value, 0, 0, canvas.width, canvas.height);
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

  const code = jsQR(imageData.data, imageData.width, imageData.height, {
    inversionAttempts: "dontInvert",
  });

  if (code) {
    await handleScan(code.data);
    return;
  }

  animationFrameId = requestAnimationFrame(tick);
};

// 🔹 Procesar QR (ÚNICA PARTE NUEVA)
const handleScan = async (qrText) => {
  try {
    console.log("📸 QR RAW:", qrText);

    // 1️⃣ normalizar texto
    const cleaned = decodeURIComponent(qrText).trim();
    console.log("🧹 QR CLEAN:", cleaned);

    // 2️⃣ parsear
    const payload = JSON.parse(cleaned);
    console.log("📦 QR PAYLOAD:", payload);

    if (
      !payload.assigned_chiva_id ||
      !Array.isArray(payload.seats)
    ) {
      scanResult.value = "⚠️ QR inválido.";
      return;
    }

    // 3️⃣ actualizar asientos
    const { error } = await supabase
      .from("seats")
      .update({ status: "abordado" })
      .eq("assigned_chiva_id", payload.assigned_chiva_id)
      .in("seat_number", payload.seats);

    if (error) {
      console.error("❌ Error actualizando asientos:", error);
      scanResult.value = "❌ Error abordando asientos.";
      return;
    }

    scanResult.value = `✅ Pasajeros ${payload.seats.join(", ")} abordados con éxito.`;
    await playBeep();
  } catch (err) {
    console.error("❌ ERROR QR:", err);
    scanResult.value = "⚠️ QR inválido.";
  }
};


// 🔹 Sonido
const playBeep = async () => {
  try {
    beep.currentTime = 0;
    await beep.play();
  } catch (err) {
    if (err.name !== "AbortError") {
      console.error("Error al reproducir beep:", err);
    }
  }
};

// 🔹 Limpieza
onBeforeUnmount(() => {
  if (stream) stream.getTracks().forEach((track) => track.stop());
  if (animationFrameId) cancelAnimationFrame(animationFrameId);
  beep.pause();
  beep.currentTime = 0;
});

onMounted(() => {
  startScanner();
});

const scanResultClass = computed(() => {
  if (scanResult.value.startsWith("✅"))
    return "bg-green-100 text-green-700 border border-green-300";
  if (scanResult.value.startsWith("⚠️"))
    return "bg-yellow-100 text-yellow-700 border border-yellow-300";
  if (scanResult.value.startsWith("❌"))
    return "bg-red-100 text-red-700 border border-red-300";
  return "bg-gray-100 text-gray-700 border border-gray-200";
});
</script>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.4s;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
