# Informe de pruebas — SECTOR ABANDONADO v1.0.0

Fecha: 18-11-2026 · Godot 4.7.2 stable (oficial) · Entorno: contenedor Linux x86_64 en la nube, sin GPU (render por software Mesa llvmpipe, OpenGL 4.5 / renderizador *Compatibility*), sin dispositivo Android físico ni emulador.

## Qué se pudo probar y qué no

| Área | Estado | Cómo |
|---|---|---|
| Compilación de los 53 scripts | ✅ 53/53 | `tests/check_scripts.gd` |
| Escenas y referencias de recursos | ✅ | carga de menú, juego, test, arsenal, derrota sin errores |
| Modelos GLB, rig y animaciones | ✅ (visual) | capturas renderizadas de cada personaje y clip (`tests/visual_check.tscn`) |
| Colisiones y navegación | ✅ | navmesh 484 polígonos; zombies llegan al jugador a través de ventanas |
| Rondas, persecución, disparos, daño, muertes | ✅ | `tests/gameplay_test.tscn` (41 aserciones) |
| Compras, puertas, armas de pared, munición | ✅ | idem |
| Caja misteriosa, La Forja, ventajas, jefe | ✅ | idem |
| Muerte, pantalla de derrota, récords | ✅ | idem |
| UI en 16:9 y 20:9 | ✅ (visual) | `tests/ui_shots.tscn` a 1280×720 y 1600×720 |
| Exportación APK | ✅ | APK debug firmado, arm64-v8a, `userLandscape` |
| Renderizador **Mobile (Vulkan)** | ⚠️ no verificable aquí | no hay Vulkan en el contenedor; todas las pruebas visuales usan el respaldo OpenGL que el proyecto también activa en móviles sin Vulkan |
| FPS reales en teléfono, táctil real, modo inmersivo real | ⚠️ pendiente en dispositivo | sin hardware Android disponible |

## Pruebas de integración (`tests/gameplay_test.tscn`)
Resultado final: **41 superadas, 0 fallidas**.

Incluye: estado inicial (pistola, 500 pts, 42 puntos de aparición, 5 puertas, navmesh, solo zona inicial abierta); ronda 1 arranca y genera zombies solo en zonas abiertas y bajo el límite; zombies **rompen barricadas** (3 ventanas dañadas) y **alcanzan al jugador** (2,8 m); reparar tablón suma tablón y puntos; **disparo hitscan real mata** y da puntos y gasta munición; compra de puerta (resta precio, abre zona, activa enlace de navegación); arma de pared y recarga de munición; compra denegada sin puntos; caja misteriosa (gira → ofrece → entrega arma); Forja (cobra, procesa, devuelve arma mejorada con más daño y cargador); 5 ventajas con efectos (vida 200, recarga ×0,5, daño ×1,3); avance de ronda y escalado de vida/horda; el jefe aparece y recompensa 2500; muerte del jugador → pantalla de derrota → récords guardados.

## Prueba de estrés (`tests/perf_test.tscn`, ronda 15, horda al máximo, 25 s)

Coste de lógica de juego (CPU, ejecución sin render):

| Perfil | Zombies vivos | Proceso medio / máx | Física media / máx |
|---|---|---|---|
| BAJO | 14 | 1,10 / 3,84 ms | 1,76 / 4,68 ms |
| MEDIO | 20 | 1,30 / 3,54 ms | 3,31 / 7,40 ms |
| ALTO | 24 | 1,16 / 4,18 ms | 3,65 / 10,74 ms |

Coste de dibujo (render por software, solo útil para contar llamadas):

| Perfil | Draw calls medio / máx | Primitivas medias | Memoria de vídeo |
|---|---|---|---|
| BAJO | 163 / 192 | 62 k | 100 MB |
| MEDIO | 261 / 306 | 122 k | 105 MB |
| ALTO | 304 / 363 | 149 k | 123 MB |

Los FPS medidos aquí (4–17) corresponden a **llvmpipe** (GPU emulada por CPU) y **no** representan un teléfono. La lógica completa con 24 zombies cuesta < 5 ms de CPU de media, por lo que el presupuesto de 33 ms (30 FPS) / 16 ms (60 FPS) queda para el render. **No se afirma un FPS en Android sin medirlo en un dispositivo**: es la primera prueba a hacer con el APK.

Optimizaciones aplicadas y verificadas por los números de arriba: lotes de geometría (−30 % de draw calls en BAJO: 229 → 163), tablones en MultiMesh, escombros fusionados, material paleta, pools de zombies/efectos, LOD de animación, límite de zombies por perfil, sin sombras dinámicas en zombies, oclusores, resolución dinámica en móvil.

## Problemas encontrados y corregidos durante las pruebas
1. Deriva de cadera en el retargeting de animaciones → personajes desplazados (corregido en `bake_character.py`).
2. Deformación de brazos del Tanque con el auto-rig propio → pesos difundidos por superficie + exclusión del torso.
3. Viewmodel demasiado lejos y antebrazos que tapaban el arma → manos en escala del arma y offsets escalados.
4. Niebla excesiva y escena lavada → niebla/ambiente/contraste ajustados.
5. Icono de arma vacío al empezar → el HUD sincroniza el arma actual al enlazarse.
6. Menús con tamaño 0 (anclajes) → `set_anchors_and_offsets_preset`.
7. Emisión excesiva del jefe → tono y energía reducidos.
8. Exceso de draw calls → ver optimizaciones.

## Cómo repetir
```
godot --headless --path game -s tests/check_scripts.gd
godot --headless --path game res://tests/gameplay_test.tscn
godot --path game res://tests/perf_test.tscn -- 0   # 0=BAJO 1=MEDIO 2=ALTO
godot --path game res://tests/visual_check.tscn -- <carpeta_capturas>
godot --path game res://tests/ui_shots.tscn -- <carpeta_capturas> 16x9
```
