// src/main.js
import { createApp } from "vue";
import App from "./App.vue";
import "./assets/style.css";

import { createPinia } from "pinia";
import router from "./router";

const app = createApp(App);

app.use(createPinia());
app.use(router);

// La sesión se restaura en el guard del router (authStore.init) antes de
// resolver la primera ruta, así que no hace falta inicializarla aquí.
app.mount("#app");
