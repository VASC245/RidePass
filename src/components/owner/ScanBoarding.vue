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
const scanKind = ref("");   // ok | warn | error
const busy = ref(false);

let stream = null;
let animationFrameId = null;

const setResult = (kind, text) => {
  scanKind.value = kind;
  scanResult.value = text;
};

// Iniciar cámara
const startScanner = async () => {
  setResult("", "");
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "environment" },
    });
    videoRef.value.srcObject = stream;
    animationFrameId = requestAnimationFrame(tick);
  } catch (err) {
    console.error("Error accediendo a cámara:", err);
    setResult("error", "No se pudo acceder a la cámara. Revisa los permisos del navegador.");
  }
};

// Leer frames
const tick = async () => {
  if (!videoRef.value || videoRef.value.readyState !== videoRef.value.HAVE_ENOUGH_DATA) {
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

  if (code && !busy.value) {
    await handleScan(code.data);
    return;
  }

  animationFrameId = requestAnimationFrame(tick);
};

// El QR solo contiene el id de la venta. La función board_sale valida en la
// base de datos que la venta esté pagada, que pertenezca a este dueño o
// conductor, y marca los asientos como abordados una sola vez.
const handleScan = async (qrText) => {
  busy.value = true;
  try {
    const { data, error } = await supabase.rpc("board_sale", { p_qr: String(qrText).trim() });
    if (error) throw error;

    if (data?.ok) {
      const seats = (data.seats ?? []).join(", ");
      setResult("ok", `Abordaron ${data.customer ?? "pasajeros"} · asientos ${seats}${data.tour ? ` · ${data.tour}` : ""}.`);
      await playBeep();
    } else if (data?.code === "ALREADY_BOARDED") {
      setResult("warn", `${data.message} Asientos ${(data.seats ?? []).join(", ")}.`);
    } else {
      setResult("warn", data?.message || "QR inválido.");
    }
  } catch (err) {
    console.error("board_sale:", err);
    setResult("error", "No se pudo validar el ticket. Intenta de nuevo.");
  } finally {
    busy.value = false;
  }
};

// Sonido
const beep = typeof Audio !== "undefined" ? new Audio("/beep.wav") : null;
const playBeep = async () => {
  if (!beep) return;
  try {
    beep.currentTime = 0;
    await beep.play();
  } catch (err) {
    if (err.name !== "AbortError" && err.name !== "NotSupportedError") {
      console.error("Error al reproducir beep:", err);
    }
  }
};

// Limpieza
onBeforeUnmount(() => {
  if (stream) stream.getTracks().forEach((track) => track.stop());
  if (animationFrameId) cancelAnimationFrame(animationFrameId);
  if (beep) { beep.pause(); beep.currentTime = 0; }
});

onMounted(startScanner);

const scanResultClass = computed(() => ({
  ok:    "bg-green-100 text-green-700 border border-green-300",
  warn:  "bg-yellow-100 text-yellow-700 border border-yellow-300",
  error: "bg-red-100 text-red-700 border border-red-300",
}[scanKind.value] ?? "bg-gray-100 text-gray-700 border border-gray-200"));
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
