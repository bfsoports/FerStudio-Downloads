# Guía visual y sistema de componentes

## Dirección de arte
Low poly 3D estilizado: geometría limpia, texturas pintadas, iluminación de atardecer cálido contra sombras frías, niebla verde-gris, acentos intensos (naranja de peligro, verde tóxico) en efectos, máquinas y UI.

## Paleta
| Token | Color | Uso |
|---|---|---|
| BG | `#0E0F0E` | fondos |
| PANEL | `#171915` (88 %) | placas de UI |
| BORDER | `#5C614D` | bordes de placa |
| ACCENT | `#FF8F1F` | acción principal, peligro, selección |
| TOXIC | `#94FF3D` | energía, Forja, caja misteriosa, salud |
| TEXT | `#F0EBDB` | texto e iconos |
| TEXT_DIM | `#A3A899` | texto secundario |
| DANGER | `#EB3829` | ronda, daño, munición baja |
| GOLD | `#FFD14D` | puntos, precios, récords |

Definida en código en `scripts/ui/ui_style.gd` (única fuente de verdad).

## Tipografía
- Títulos, números y botones: **Russo One** (OFL).
- Cuerpo, descripciones: **Teko SemiBold** (OFL).

## Componentes
- **Placa inclinada** (`UIStyle.plate`): StyleBox con sesgo de 0,18, borde de 2 px; estados normal / hover / pressed (naranja) / disabled.
- **Franja de peligro** (`hazard_strip.svg`): separador bajo títulos.
- **Botón táctil circular** (`TouchButton`): fondo translúcido según opacidad configurada, aro de acento, icono centrado, anillo de progreso para "mantener para comprar".
- **Insignia de ventaja**: círculo del color de la ventaja + glifo blanco.
- **Tarjeta de interacción**: icono + título + precio (dorado / rojo si no alcanza) + descripción + instrucción.
- **Banner**: título grande centrado con subtítulo, aparece y se desvanece.

## Iconografía
Set propio en SVG (`assets/ui/icons/*.svg`, 128×128): glifos color hueso, trazo de 10 px redondeado, sin texto. Las siluetas de armas (`w_*.png`) se renderizaron desde los modelos 3D reales con fondo transparente para que coincidan exactamente con el arma en juego.

## Recursos creados con Canva (integración real usada)
- **Logotipo** "SECTOR ABANDONADO" (IA generativa de Canva) → fondo eliminado con *Remove background* de Canva → exportado PNG → `assets/ui/logo/logo.png`.
- **Ilustración del menú principal** (IA generativa de Canva, 16:9) → colocada en un diseño Canva y exportada a 1920×1080 → `assets/ui/backgrounds/menu_keyart.jpg`.
- Derivados: `screen_bg.jpg` (fondo desenfocado para carga/derrota) y `app_icon.png` (icono de la app), generados a partir de esos dos recursos.

**No** se hicieron en Canva: los iconos del HUD/controles/ventajas (SVG propios del proyecto) ni los fondos de botones (StyleBox en código). Se priorizó un set vectorial nítido a cualquier resolución y coherente pieza a pieza; queda documentado aquí para no atribuir a Canva lo que no se hizo con Canva.
