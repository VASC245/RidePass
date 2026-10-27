<template>
  <div class="fixed inset-0 z-50 flex items-end justify-center bg-black/55 p-0 sm:items-center sm:p-4"
    role="dialog" aria-modal="true" aria-labelledby="proof-title" @click.self="$emit('close')">
    <div class="relative w-full max-w-md rounded-t-2xl bg-white p-5 sm:rounded-[var(--radius-card)] sm:p-6">
      <button
        type="button"
        @click="$emit('close')"
        class="absolute right-3 top-3 inline-flex size-10 items-center justify-center rounded-lg text-gray-500 hover:bg-gray-100 hover:text-gray-900"
        aria-label="Cerrar"
      >
        <PhX :size="18" weight="bold" />
      </button>

      <h2 id="proof-title" class="pr-10 text-lg font-semibold text-gray-900">Comprobante de transferencia</h2>
      <p class="mb-5 mt-1 text-sm text-gray-600">
        Sube la foto o PDF del depósito. El dueño lo verificará y los asientos quedarán confirmados.
      </p>

      <form @submit.prevent="uploadProof" class="space-y-4">
        <div>
          <label for="proof-number" class="field-label">Número de comprobante</label>
          <input id="proof-number" v-model.trim="numeroComprobante" required maxlength="60"
            class="field-control" placeholder="Ej: TRX-928374" />
        </div>

        <div>
          <label for="proof-file" class="field-label">Imagen o PDF</label>
          <label for="proof-file"
            class="flex cursor-pointer items-center gap-3 rounded-lg border border-dashed border-gray-300 bg-gray-50 px-4 py-3 transition-colors hover:border-brand-400 hover:bg-brand-50">
            <PhUploadSimple :size="22" class="shrink-0 text-brand-700" />
            <span class="min-w-0 text-sm">
              <span class="block truncate font-semibold text-gray-900">{{ fileName || "Elegir archivo" }}</span>
              <span class="text-gray-600">JPG, PNG, WEBP o PDF. Máximo 5 MB.</span>
            </span>
          </label>
          <input id="proof-file" type="file" class="sr-only" required
            accept="image/jpeg,image/png,image/webp,application/pdf" @change="handleFileChange" />
        </div>

        <div v-if="previewUrl && !isPdf" class="text-center">
          <img :src="previewUrl" class="mx-auto h-40 w-40 rounded-lg border border-gray-200 object-cover" alt="Vista previa del comprobante" />
        </div>

        <p v-if="error" role="alert" class="flex items-start gap-2 rounded-lg border border-bad-200 bg-bad-50 px-3 py-2.5 text-sm text-bad-700">
          <PhWarningCircle :size="18" class="mt-px shrink-0" /> {{ error }}
        </p>

        <BaseButton block size="lg" type="submit" :loading="uploading" :disabled="!selectedFile">
          {{ uploading ? "Subiendo comprobante" : "Subir y continuar" }}
        </BaseButton>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { PhX, PhUploadSimple, PhWarningCircle } from "@phosphor-icons/vue";
import { supabase } from "@/lib/supabase";
import { uploadProof as uploadProofFile } from "@/lib/reservations";
import BaseButton from "@/components/ui/BaseButton.vue";

// Este modal SOLO sube el archivo al bucket. El registro del comprobante lo
// hace la edge function public-reserve junto con la venta, para que ambos
// queden enlazados (sale_id) y la verificación pueda liberar asientos.
const emit = defineEmits(["uploaded", "close"]);

const MAX_BYTES = 5 * 1024 * 1024;

const numeroComprobante = ref("");
const selectedFile = ref(null);
const previewUrl = ref("");
const isPdf = ref(false);
const uploading = ref(false);
const fileName = ref("");
const error = ref("");

const handleFileChange = (e) => {
  const file = e.target.files?.[0];
  error.value = "";
  previewUrl.value = "";
  selectedFile.value = null;
  if (!file) return;

  if (file.size > MAX_BYTES) {
    error.value = "El archivo supera los 5 MB.";
    e.target.value = "";
    return;
  }

  selectedFile.value = file;
  fileName.value = file.name;
  isPdf.value = file.type === "application/pdf";

  if (!isPdf.value) {
    const reader = new FileReader();
    reader.onload = (ev) => (previewUrl.value = ev.target.result);
    reader.readAsDataURL(file);
  } else {
    previewUrl.value = "pdf";
  }
};

const uploadProof = async () => {
  if (!selectedFile.value || !numeroComprobante.value) return;
  uploading.value = true;
  error.value = "";

  // URL firmada desde public-reserve (los paneles no necesitan captcha)
  let storagePath;
  try {
    storagePath = await uploadProofFile(supabase, selectedFile.value);
  } catch (e) {
    console.error("upload comprobante:", e.message);
    error.value = e.message || "No se pudo subir el archivo. Intenta de nuevo.";
    return;
  } finally {
    uploading.value = false;
  }

  emit("uploaded", { path: storagePath, number: numeroComprobante.value });
};
</script>
