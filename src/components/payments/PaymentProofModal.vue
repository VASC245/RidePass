<template>
  <div class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
    <BaseCard class="w-full max-w-md p-6 relative">
      <button
        type="button"
        @click="$emit('close')"
        class="absolute top-3 right-3 w-8 h-8 rounded-full text-gray-400 hover:text-gray-700 hover:bg-gray-100"
        aria-label="Cerrar"
      >
        <PhX :size="16" weight="bold" class="mx-auto" />
      </button>

      <h2 class="text-xl font-bold text-gray-900 mb-1">Comprobante de transferencia</h2>
      <p class="text-sm text-gray-500 mb-5">
        Sube la foto o PDF del depósito. El dueño lo verificará y los asientos quedarán confirmados.
      </p>

      <form @submit.prevent="uploadProof" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Número de comprobante</label>
          <input
            v-model.trim="numeroComprobante"
            required
            maxlength="60"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-orange-500"
            placeholder="Ej: TRX-928374"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Imagen o PDF</label>
          <input
            type="file"
            accept="image/jpeg,image/png,image/webp,application/pdf"
            required
            class="block w-full text-sm text-gray-600"
            @change="handleFileChange"
          />
          <p class="text-xs text-gray-400 mt-1">JPG, PNG, WEBP o PDF. Máximo 5 MB.</p>
        </div>

        <div v-if="previewUrl" class="text-center">
          <img v-if="!isPdf" :src="previewUrl" class="w-40 h-40 object-cover border rounded-lg mx-auto" alt="Vista previa del comprobante" />
          <p v-else class="text-sm text-gray-700">{{ fileName }}</p>
        </div>

        <p v-if="error" class="text-sm text-red-600 bg-red-50 border border-red-100 rounded-lg px-3 py-2">{{ error }}</p>

        <BaseButton full type="submit" :disabled="uploading || !selectedFile">
          {{ uploading ? "Subiendo..." : "Continuar" }}
        </BaseButton>
      </form>
    </BaseCard>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { PhX } from "@phosphor-icons/vue";
import { supabase } from "@/lib/supabase";
import BaseCard from "@/components/ui/BaseCard.vue";
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

  const { data: { user } } = await supabase.auth.getUser();
  const prefix = user?.id ?? "public";
  const safeName = selectedFile.value.name.replace(/[^\w.-]+/g, "_").slice(-80);
  const storagePath = `comprobantes/${prefix}_${Date.now()}_${safeName}`;

  const { error: uploadError } = await supabase.storage
    .from("comprobantes")
    .upload(storagePath, selectedFile.value, { contentType: selectedFile.value.type });

  uploading.value = false;

  if (uploadError) {
    console.error("upload comprobante:", uploadError);
    error.value = "No se pudo subir el archivo. Intenta de nuevo.";
    return;
  }

  emit("uploaded", { path: storagePath, number: numeroComprobante.value });
};
</script>
