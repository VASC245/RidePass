<template>
  <div class="fixed inset-0 bg-black bg-opacity-60 flex items-center justify-center z-50">
    <BaseCard class="w-full max-w-md p-6 relative">
      <button
        @click="$emit('close')"
        class="absolute top-3 right-3 text-gray-400 hover:text-gray-600 text-xl"
      >
        ✖
      </button>

      <h2 class="text-2xl font-bold text-center mb-4">💳 Subir Comprobante</h2>

      <form @submit.prevent="uploadProof" class="space-y-4">
        <div>
          <label class="text-sm font-medium">Número de Comprobante</label>
          <input
            v-model="numeroComprobante"
            required
            class="w-full border rounded-lg px-3 py-2"
            placeholder="Ej: TRX-928374"
          />
        </div>

        <div>
          <label class="text-sm font-medium">Imagen o PDF</label>
          <input type="file" accept="image/*,application/pdf" @change="handleFileChange" required />
        </div>

        <div v-if="previewUrl" class="text-center">
          <img v-if="!isPdf" :src="previewUrl" class="w-40 h-40 object-cover border rounded-lg mx-auto" />
          <p v-else class="text-blue-600 underline">{{ fileName }}</p>
        </div>

        <BaseButton full type="submit" :disabled="uploading">
          {{ uploading ? "⏳ Subiendo..." : "📤 Subir Comprobante" }}
        </BaseButton>
      </form>
    </BaseCard>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { supabase } from "@/lib/supabase";
import BaseCard from "@/components/ui/BaseCard.vue";
import BaseButton from "@/components/ui/BaseButton.vue";

const props = defineProps({
  assignedChivaId: String,
  ownerId: String,
});
const emit = defineEmits(["uploaded", "close"]);

const numeroComprobante = ref("");
const selectedFile = ref(null);
const previewUrl = ref("");
const isPdf = ref(false);
const uploading = ref(false);
const fileName = ref("");

const handleFileChange = (e) => {
  const file = e.target.files[0];
  selectedFile.value = file;
  fileName.value = file.name;
  isPdf.value = file.type === "application/pdf";

  if (!isPdf.value) {
    const reader = new FileReader();
    reader.onload = (ev) => (previewUrl.value = ev.target.result);
    reader.readAsDataURL(file);
  }
};

// SUBIR COMPROBANTE
const uploadProof = async () => {
  uploading.value = true;

  const { data: session } = await supabase.auth.getUser();
  const agencyId = session.user.id;

  // Obtener nombre agencia
  const { data: agency } = await supabase
    .from("users")
    .select("full_name")
    .eq("id", agencyId)
    .single();

  const timestamp = Date.now();
  const storagePath = `comprobantes/${agencyId}_${timestamp}_${selectedFile.value.name}`;

  // Subir archivo
  const { error: uploadError } = await supabase.storage
    .from("comprobantes")
    .upload(storagePath, selectedFile.value);
  if (uploadError) {
    alert("Error subiendo archivo");
    uploading.value = false;
    return;
  }

  // Obtener URL pública
  const { data: urlData } = supabase.storage.from("comprobantes").getPublicUrl(storagePath);

  // Insertar registro en pendiente
  await supabase.from("pending_payments").insert({
    assigned_chiva_id: props.assignedChivaId,
    owner_id: props.ownerId,
    agency_id: agencyId,
    numero_comprobante: numeroComprobante.value,
    comprobante_path: storagePath,
    comprobante_url: urlData.publicUrl,
    estado: "pendiente",
    agency_name: agency.full_name,
  });

  emit("uploaded", urlData.publicUrl);
  uploading.value = false;
};
</script>
