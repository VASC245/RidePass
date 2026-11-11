// Tarifas de chivaspass para vendedores (decididas el 13 sep 2026).
//
// Esta copia solo sirve para MOSTRAR precios. Quién puede vender lo decide la
// base de datos (public.seller_plan y el trigger enforce_seller_plan), y los
// límites mensuales viven en app_settings. Si cambian, actualizar también aquí.
export const TRIAL_DAYS = 30;
export const ESTABLECIMIENTO_LIMIT = 1000;
export const PROMOTOR_FREE_LIMIT = 30;

export const PLANS = {
  chiva: {
    id: "chiva",
    name: "Chiva",
    monthly: 40,
    yearly: 400,
    perUnit: true,
    features: [
      "Precio por cada chiva registrada",
      "Tours, salidas y ventas sin límite",
      "Venta en la web, en efectivo y por agencias",
      "Mapa de asientos y embarque con QR",
      "Conductores y comprobantes en el panel",
    ],
  },
  establecimiento: {
    id: "establecimiento",
    name: "Establecimiento",
    monthly: 25,
    features: [
      `Hasta ${ESTABLECIMIENTO_LIMIT.toLocaleString("es-EC")} entradas al mes`,
      "Eventos y cupos sin límite",
      "Ficha pública en la página de atracciones",
      "Escaneo de entradas con QR",
    ],
  },
  establecimiento_plus: {
    id: "establecimiento_plus",
    name: "Establecimiento Plus",
    monthly: 40,
    features: [
      "Entradas sin límite",
      "Todo lo del plan Establecimiento",
      "Para atracciones con mucho público",
    ],
  },
  promotor_gratis: {
    id: "promotor_gratis",
    name: "Promotor",
    monthly: 0,
    free: true,
    features: [
      `Hasta ${PROMOTOR_FREE_LIMIT} tickets al mes`,
      "Vende los tours de los dueños que lo permiten",
      "Sin costo mensual",
    ],
  },
  promotor: {
    id: "promotor",
    name: "Promotor sin límite",
    monthly: 15,
    features: [
      "Tickets sin límite",
      "Todo lo del plan Promotor",
    ],
  },
};

export const PLANS_BY_ROLE = {
  "dueño": ["chiva"],
  negocio: ["establecimiento", "establecimiento_plus"],
  agencia: ["promotor_gratis", "promotor"],
};

// Lo que vende cada rol, para los textos
export const UNIT_LABEL = {
  "dueño": "tickets",
  negocio: "entradas",
  agencia: "tickets",
};

export const daysUntil = (iso) => {
  if (!iso) return 0;
  return Math.max(0, Math.ceil((new Date(iso).getTime() - Date.now()) / 86_400_000));
};

export const formatDate = (iso) =>
  iso ? new Date(iso).toLocaleDateString("es-EC", { day: "numeric", month: "long", year: "numeric" }) : "";
