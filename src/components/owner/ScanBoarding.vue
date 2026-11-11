<template>
  <div class="mx-auto max-w-xl">
    <PageHeader title="Embarque" description="Apunta la cámara al QR del boleto. Cada boleto se valida una sola vez." />

    <div class="space-y-4">
      <!-- Cámara -->
      <div class="relative aspect-square overflow-hidden rounded-[var(--radius-card)] bg-gray-950 sm:aspect-[4/3]">
        <video ref="videoRef" autoplay playsinline muted class="size-full object-cover" :class="cameraError && 'invisible'" />

        <!-- Visor -->
        <div v-if="!cameraError" class="pointer-events-none absolute inset-0 flex items-center justify-center">
          <div class="viewfinder" :class="[scanKind && 'viewfinder--' + scanKind, busy && 'viewfinder--busy']">
            <span /><span /><span /><span />
          </div>
          <p class="absolute bottom-4 left-1/2 -translate-x-1/2 rounded-full bg-black/60 px-3 py-1 text-sm font-medium text-white">
            {{ busy ? 'Validando…' : scanResult ? 'Escaneo en pausa' : 'Buscando QR…' }}
          </p>
        </div>

        <!-- Sin cámara -->
        <div v-else class="absolute inset-0 flex flex-col items-center justify-center px-6 text-center text-white">
          <span class="mb-4 inline-flex size-14 items-center justify-center rounded-full bg-white/10">
            <PhCameraSlash :size="28" />
          </span>
          <p class="text-lg font-semibold">No se pudo abrir la cámara</p>
          <p class="mt-1 max-w-[34ch] text-sm text-gray-300">Permite el acceso a la cámara en tu navegador y vuelve a intentarlo.</p>
          <BaseButton variant="primary" size="lg" class="mt-5" @click="startScanner">
            <PhCamera :size="20" /> Activar cámara
          </BaseButton>
        </div>
      </div>

      <!-- Resultado -->
      <div aria-live="assertive" aria-atomic="true">
        <Transition name="result">
          <div v-if="scanResult" :key="resultKey" class="result" :class="resultStyle.box">
            <component :is="resultStyle.icon" :size="44" weight="fill" class="shrink-0" :class="resultStyle.icon_color" />
            <div class="min-w-0">
              <p class="text-xl font-bold leading-tight" :class="resultStyle.title_color">{{ resultStyle.title }}</p>
              <p class="mt-1 text-base text-gray-800">{{ scanResult }}</p>
            </div>
          </div>
        </Transition>
      </div>

      <BaseButton v-if="!cameraError" :variant="scanResult ? 'primary' : 'secondary'" size="lg" block @click="startScanner">
        <PhQrCode v-if="scanResult" :size="20" />
        <PhArrowsClockwise v-else :size="20" />
        {{ scanResult ? 'Escanear siguiente boleto' : 'Reiniciar cámara' }}
      </BaseButton>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, computed } from "vue";
import jsQR from "jsqr";
import { supabase } from "@/lib/supabase";

import BaseButton from "@/components/ui/BaseButton.vue";
import PageHeader from "@/components/ui/PageHeader.vue";
import {
  PhCamera, PhCameraSlash, PhQrCode, PhArrowsClockwise,
  PhCheckCircle, PhWarningCircle, PhXCircle, PhWifiSlash,
} from "@phosphor-icons/vue";

const videoRef = ref(null);
const scanResult = ref("");
const scanKind = ref("");   // ok | used | wrong | invalid | error
const busy = ref(false);
const cameraError = ref(false);
const resultKey = ref(0);

let stream = null;
let animationFrameId = null;

const setResult = (kind, text) => {
  scanKind.value = kind;
  scanResult.value = text;
  resultKey.value++;
};

const stopCamera = () => {
  if (animationFrameId) cancelAnimationFrame(animationFrameId);
  animationFrameId = null;
  if (stream) stream.getTracks().forEach((track) => track.stop());
  stream = null;
};

// Iniciar cámara
const startScanner = async () => {
  setResult("", "");
  cameraError.value = false;
  stopCamera();
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: "environment" },
    });
    videoRef.value.srcObject = stream;
    animationFrameId = requestAnimationFrame(tick);
  } catch (err) {
    console.error("Error accediendo a cámara:", err);
    cameraError.value = true;
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
      setResult("ok", `${data.customer ?? "Pasajeros"} · asientos ${seats}${data.tour ? ` · ${data.tour}` : ""}`);
      await playBeep();
    } else if (data?.code === "ALREADY_BOARDED") {
      setResult("used", `${data.message} Asientos ${(data.seats ?? []).join(", ")}.`);
    } else if (data?.code === "DEPARTURE_PAST" || data?.code === "WRONG_DEPARTURE") {
      // Ticket pagado pero de otra salida: se muestra el mensaje del servidor con el titular.
      const who = [data.customer, data.tour].filter(Boolean).join(" · ");
      setResult("wrong", `${data.message ?? "Este ticket es de otra salida."}${who ? ` ${who}.` : ""}`);
    } else {
      // Cualquier otro código (NOT_PAID, FORBIDDEN, NO_SEATS, nuevos…) trae su propio mensaje.
      setResult("invalid", data?.message || "Este código no corresponde a un boleto.");
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
  stopCamera();
  if (beep) { beep.pause(); beep.currentTime = 0; }
});

onMounted(startScanner);

const RESULT_STYLES = {
  ok:      { title: "Pasajero válido, puede subir", icon: PhCheckCircle,   box: "border-ok-600 bg-ok-50",     icon_color: "text-ok-600",   title_color: "text-ok-700" },
  used:    { title: "Boleto ya usado",              icon: PhWarningCircle, box: "border-warn-600 bg-warn-50", icon_color: "text-warn-600", title_color: "text-warn-700" },
  wrong:   { title: "Boleto de otra salida",        icon: PhWarningCircle, box: "border-warn-600 bg-warn-50", icon_color: "text-warn-600", title_color: "text-warn-700" },
  invalid: { title: "QR no válido",                 icon: PhXCircle,       box: "border-bad-600 bg-bad-50",   icon_color: "text-bad-600",  title_color: "text-bad-700" },
  error:   { title: "No se pudo validar",           icon: PhWifiSlash,     box: "border-gray-400 bg-gray-100", icon_color: "text-gray-600", title_color: "text-gray-900" },
};
const resultStyle = computed(() => RESULT_STYLES[scanKind.value] ?? RESULT_STYLES.error);
</script>

<style scoped>
.viewfinder {
  position: relative;
  width: min(62%, 16rem);
  aspect-ratio: 1;
  color: #fff;
  transition: color 200ms var(--ease-out-quart), transform 200ms var(--ease-out-quart);
}
.viewfinder span {
  position: absolute;
  width: 2.25rem; height: 2.25rem;
  border-color: currentColor;
  border-style: solid;
}
.viewfinder span:nth-child(1) { top: 0; left: 0; border-width: 4px 0 0 4px; border-top-left-radius: 12px; }
.viewfinder span:nth-child(2) { top: 0; right: 0; border-width: 4px 4px 0 0; border-top-right-radius: 12px; }
.viewfinder span:nth-child(3) { bottom: 0; left: 0; border-width: 0 0 4px 4px; border-bottom-left-radius: 12px; }
.viewfinder span:nth-child(4) { bottom: 0; right: 0; border-width: 0 4px 4px 0; border-bottom-right-radius: 12px; }
.viewfinder--busy { transform: scale(0.96); }
.viewfinder--ok { color: var(--color-ok-200); }
.viewfinder--used, .viewfinder--wrong { color: var(--color-warn-200); }
.viewfinder--invalid, .viewfinder--error { color: var(--color-bad-200); }

.result {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
  padding: 1.25rem;
  border-width: 2px;
  border-radius: var(--radius-card);
}

.result-enter-active { transition: opacity 200ms var(--ease-out-quart), transform 200ms var(--ease-out-quart); }
.result-enter-from { opacity: 0; transform: translateY(8px); }
</style>
