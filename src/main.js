// src/main.js
import { createApp } from "vue";
import App from "./App.vue";
import "./assets/style.css";

import { createPinia } from "pinia";
import router from "./router";

// Un chunk precargado que ya no existe (deploy nuevo con la pestaña
// abierta): el router se encarga de recargar; aquí solo se evita el error
// en consola sin manejar.
window.addEventListener("vite:preloadError", (event) => event.preventDefault());

const app = createApp(App);

app.use(createPinia());
app.use(router);

// La sesión se restaura en el guard del router (authStore.init) antes de
// resolver la primera ruta, así que no hace falta inicializarla aquí.
app.mount("#app");
