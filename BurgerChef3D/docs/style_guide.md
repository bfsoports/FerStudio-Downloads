# Guía de estilo

## Identidad
Cartoon 3D cálido y limpio: formas redondeadas, colores de hamburguesería (ketchup, mostaza, lechuga, pan) y una interfaz oscura de tono chocolate que hace resaltar los iconos brillantes del pack, sin saturación extrema.

## Paleta (`scripts/core/palette.gd`)
Ketchup `#d8392b` · Mostaza `#f2b134` · Lechuga `#6fb43f` · Pan `#d9964f` · Crema `#fff1d6` · Marrón `#3a2620` · Turquesa `#3f9a95` · Cielo `#4a90d9`.

## Interfaz
- **Grande, compacta y adaptable:** el lienzo base es de 1024 x 576 y crece en la dirección que le sobra a cada pantalla. Todo se coloca dentro de un `ContentFrame` de 1500 unidades como máximo; las ventanas miden hasta 1020 x 640 y se encogen si la pantalla es menor; las tarjetas son de ancho fijo y el número de columnas se calcula con el ancho disponible (`UIKit.fit_columns`). Ajustes permite elegir el tamaño de la interfaz (pequeña 0,9, normal 1,0, grande 1,15).
- **Compacta y sin estirarse (antes):** todo el contenido vive en un `ContentFrame` de 1280 px como máximo (HUD, menús, diálogos) y las ventanas miden 1020 px. Las tarjetas son de ancho fijo (300-470 px) y se colocan en cuadrículas centradas; no se usan botones ni paneles que se expandan de lado a lado.
- Tipografía: Poppins Bold (títulos y botones) y Poppins Medium (texto). Tamaño base 22 px sobre un lienzo de 1280x720; títulos de ventana 36 px, cabeceras 24-30 px, texto secundario 16-18 px.
- Ventanas oscuras (`#2a1c18`, borde `#7a5646`), tarjetas `#3d2a24`, esquinas de 16-26 px, cabecera con icono, título, monedas y botón de cierre (aspa roja del pack).
- Botones con relieve inferior (se hunden al pulsar): Primary (mostaza), Secondary (marrón claro), Success (verde), Danger (rojo), Dark, Toggle (pestañas, mostaza al activarse) y Round/Icon (solo icono). Alturas: 58 (tarjetas y pestañas), 68 (normal) y 84 (principal). Un icono real a la izquierda del texto en cada botón con acción reconocible.
- Comandas del HUD como tickets de papel crema de 176 px; monedas, nivel, temporizador y objetivo en pastillas oscuras translúcidas con texto de contorno marrón sobre la escena 3D; la información nunca depende solo del color (texto + icono + barra).
- **Iconos:** 48 iconos 3D cartoon propios hechos con Canva (`assets/ui/icons/<nombre>.webp`, 160 px, ~6 KB cada uno; lista en `UIKit.ICON_NAMES`). `UIKit.icon(nombre, px)` los reescala al tamaño real. Para añadir uno: generar una hoja de 12 en Canva con el mismo estilo, quitar el fondo, exportar en PNG transparente y recortar con `tools/slice_icons.py`.
- **Menú principal:** diseño de referencia de 1672 x 941 (`main_menu.gd`): fondo ilustrado en modo «cubrir» (nunca se estira ni deja bandas negras), logotipo, JUGAR y CONTINUAR como imágenes de 9 partes y pastillas marrones para las secciones. Tipografía Fredoka Bold en títulos y botones.
- Márgenes de 12-24 px más la zona segura del dispositivo.

## 3D
Muebles, equipos y comida con los modelos low-poly de KayKit Restaurant Bits y Kenney Food Kit (formas redondeadas y paleta naranja, rojo, verde azulado y crema), a su escala real: módulos de 2 m. La estructura (paredes, suelos, techo), los clientes y la decoración sin equivalente siguen siendo primitivas con proporciones exageradas, materiales mate de un color y texturas limpias (damero, azulejo, madera) con repetición por metros. Iluminación cálida con ambiente fuerte y sombras opcionales.
