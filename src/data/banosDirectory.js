// Directorio curado de atracciones reales de Baños de Agua Santa.
// Son fichas informativas: no venden entradas hasta que el negocio se afilie.
// Si un negocio registrado en Supabase tiene el mismo nombre, la ficha del
// directorio se oculta automáticamente (ver useBusinesses.js).
//
// Fotos: las de public/img/atracciones/ provienen de Wikimedia Commons
// (licencias Creative Commons; si el sitio sale a producción, mantener el
// crédito a los autores en una página de atribuciones). Las fichas sin foto
// usan las imágenes locales de respaldo. Para cambiar una foto, guárdala en
// public/img/atracciones/ y pon la ruta en `image`.

export const banosDirectory = [
  // ── Cascadas ──
  {
    id: 'dir-pailon-del-diablo',
    name: 'Pailón del Diablo',
    category: 'cascada',
    address: 'Río Verde, Ruta de las Cascadas',
    description: 'La cascada más famosa de Baños. Senderos, puentes colgantes y balcones que te dejan a metros del salto de agua.',
    image: '/img/atracciones/pailon.jpg',
  },
  {
    id: 'dir-manto-de-la-novia',
    name: 'Manto de la Novia',
    category: 'cascada',
    address: 'Ruta de las Cascadas, vía a Puyo',
    description: 'Caída de agua en el cañón del Pastaza que se cruza en tarabita, con vista al valle desde el cable.',
    image: '/img/atracciones/manto-novia.jpg',
  },
  {
    id: 'dir-cascada-agoyan',
    name: 'Cascada de Agoyán',
    category: 'cascada',
    address: 'Vía Baños - Puyo, sector Agoyán',
    description: 'Una de las cascadas más altas de la zona, visible desde los miradores de la carretera y la tarabita.',
    image: '/img/atracciones/agoyan.jpg',
  },

  // ── Deportes extremos ──
  {
    id: 'dir-puenting-san-francisco',
    name: 'Puenting, puente San Francisco',
    category: 'deporte',
    address: 'Puente San Francisco, centro de Baños',
    description: 'El salto al vacío clásico de Baños: péndulo sobre el cañón del río Pastaza con operadores locales.',
    image: null,
  },
  {
    id: 'dir-canopy-puntzan',
    name: 'Canopy Puntzan',
    category: 'deporte',
    address: 'Sector Puntzan, vía a Puyo',
    description: 'Líneas de tirolesa que cruzan el cañón con vistas a las cascadas y al río.',
    image: null,
  },
  {
    id: 'dir-rafting-pastaza',
    name: 'Rafting en el río Pastaza',
    category: 'deporte',
    address: 'Salidas desde el centro de Baños',
    description: 'Descensos en balsa por rápidos con guías certificados y equipo completo incluido.',
    image: '/img/atracciones/rafting.jpg',
  },
  {
    id: 'dir-canyoning-chamana',
    name: 'Canyoning en Chamana',
    category: 'deporte',
    address: 'Sector Chamana, a minutos del centro',
    description: 'Descenso en rappel por una serie de cascadas rodeadas de vegetación, apto para principiantes.',
    image: null,
  },

  // ── Termas ──
  {
    id: 'dir-termas-de-la-virgen',
    name: 'Termas de la Virgen',
    category: 'termas',
    address: 'Av. Martínez, centro de Baños',
    description: 'Las piscinas termales más conocidas de la ciudad, al pie de la cascada Cabellera de la Virgen.',
    image: '/img/atracciones/termas-virgen.jpg',
  },
  {
    id: 'dir-termas-el-salado',
    name: 'Termas El Salado',
    category: 'termas',
    address: 'Sector El Salado, vía a las antenas',
    description: 'Piscinas de aguas termales de origen volcánico con distintas temperaturas, entre montaña y río.',
    image: null,
  },

  // ── Miradores y más ──
  {
    id: 'dir-casa-del-arbol',
    name: 'La Casa del Árbol',
    category: 'otro',
    address: 'Runtún, parte alta de Baños',
    description: 'Hogar del columpio del fin del mundo, con vista directa al volcán Tungurahua cuando el cielo está despejado.',
    image: null,
  },
  {
    id: 'dir-manos-pachamama',
    name: 'Manos de la Pachamama',
    category: 'otro',
    address: 'Runtún',
    description: 'Mirador con las manos gigantes sobre el valle de Baños, columpio extremo y zonas para fotos.',
    image: null,
  },
  {
    id: 'dir-mirador-bellavista',
    name: 'Mirador Bellavista',
    category: 'otro',
    address: 'Sendero Bellavista, sobre la ciudad',
    description: 'El mirador de la cruz iluminada: subida corta desde el centro y la mejor vista nocturna de Baños.',
    image: null,
  },
  {
    id: 'dir-zoo-san-martin',
    name: 'Zoológico San Martín',
    category: 'otro',
    address: 'Sector San Martín, vía a Puyo',
    description: 'Refugio de fauna andina y amazónica rescatada, junto al cañón del río Pastaza.',
    image: null,
  },
]
