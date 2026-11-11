# Design

Sistema visual del panel (`/panel`) de chivaspass. Los tokens viven en `src/assets/style.css` (`@theme` de Tailwind 4) y los componentes en `src/components/ui/`.

## Tema

Panel claro sobre un blanco apenas cálido (`bg-gray-50`), con la barra lateral oscura "volcán" (`bg-side`) donde vive el logo. El naranja de marca marca acción, selección y estado activo; nunca decoración.

## Color

Estrategia **Restrained**: neutros con un toque del tono de marca y un acento naranja.

| Rol | Token | Uso |
|---|---|---|
| Acción principal | `brand-600` (hover `brand-700`) | Botón primario, enlaces, foco. Blanco encima: 4.5:1 |
| Acento suave | `brand-50` / `brand-200` / `brand-700` | Fondos de icono, selección, chips de marca |
| Tinta | `gray-900` | Títulos y cifras |
| Texto | `gray-700` / `gray-600` | Cuerpo y secundario (nunca `gray-400` para texto legible) |
| Líneas | `gray-200` | Bordes de tarjetas y separadores (borde por defecto) |
| Fondo | `gray-50` | Fondo de página |
| Barra lateral | `side`, `side-hover`, `side-active`, `side-text`, `side-mute` | Solo en la navegación |
| Éxito / Aviso / Error / Info | `ok-*`, `warn-*`, `bad-*`, `info-*` (50, 200, 600, 700) | Estados. Texto 700 sobre fondo 50 |

La escala `gray` de Tailwind está redefinida con neutros cálidos. No usar `blue-*`, `green-*`, `purple-*`, `yellow-*`, `orange-*`, `red-*` de Tailwind en el panel: usar `brand`, `ok`, `warn`, `bad`, `info`.

## Tipografía

Una sola familia: **Archivo** (Sora 800 solo en el wordmark del logo).

- Título de página: `text-2xl sm:text-[1.75rem] font-bold tracking-[-0.015em]` (vía `PageHeader`)
- Título de tarjeta: `text-base font-semibold text-gray-900`
- Cuerpo: `text-sm`/`text-[0.95rem]`, `text-gray-700`
- Etiquetas: `text-sm font-medium text-gray-600`, en minúscula tipo oración (sin mayúsculas sostenidas con tracking)
- Cifras y dinero: `tabular-nums`, `font-semibold`/`font-bold`, `text-gray-900`. El color no codifica la cifra.

## Componentes (`src/components/ui/`)

- `PageHeader` (title, description, slot `actions`): encabezado de cada pantalla. Una por página.
- `BaseCard` (variant default | highlight | danger | muted, `padded`, slots `title`/`actions`): radio 12 px, borde `gray-200`, sin sombra.
- `BaseButton` (variant primary | secondary | ghost | dark | danger | success; size sm | md | lg; `loading`, `block`): radio 8 px, alto 36/40/48 px.
- `StatusBadge` (`status="pagado"` o `tone` + texto): estado con punto y texto, nunca solo color.
- `EmptyState` (icon, title, description, slot de acción): explica qué aparecerá y cómo lograrlo.
- `SegmentedControl` (v-model, options): filtros de período o vista.
- Campos: `class="field-label"`, `class="field-control"` (input/select/textarea), `class="field-hint"`.

## Reglas

- Iconos: Phosphor (`@phosphor-icons/vue`), 18-20 px. **Sin emojis.**
- Tarjetas: borde de 1 px **o** sombra corta, nunca ambas. Sin tarjetas dentro de tarjetas. Sin bordes laterales de color.
- Radios: tarjetas 12 px, controles 8 px, chips `rounded-full`.
- Objetivos táctiles ≥ 44 px en pantallas de conductor, escaneo y venta.
- Movimiento: 150-250 ms, `ease-out`; solo para comunicar estado. `prefers-reduced-motion` ya está cubierto globalmente.
- Copy: español de Ecuador, tuteo, botones con verbo + objeto ("Guardar chiva", "Verificar pago"). Sin rayas (—).
