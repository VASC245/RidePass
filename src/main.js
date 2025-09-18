// src/main.js
import { createApp } from "vue";
import App from "./App.vue";
import "./assets/style.css";

import { createPinia } from "pinia";
import router from "./router";

// QR scanner
import { QrcodeStream, QrcodeDropZone, QrcodeCapture } from "vue-qrcode-reader";

// Stores
import { useAuthStore } from "@/stores/authStore";

const app = createApp(App);

// instalar pinia primero
app.use(createPinia());

// inicializar authStore después de instalar pinia
const authStore = useAuthStore();
authStore.init();

app.use(router);

// registrar componentes QR globales
app.component("QrcodeStream", QrcodeStream);
app.component("QrcodeDropZone", QrcodeDropZone);
app.component("QrcodeCapture", QrcodeCapture);

app.mount("#app");
