# Estado del proyecto — Valdebruma 0.1.0

Estados: **IMPLEMENTADO** (código hecho), **EJECUTADO** (se ha ejecutado de verdad), **PROBADO**
(una prueba automática lo comprueba y pasa), **PARCIAL** (funciona con límites indicados),
**PENDIENTE** (no hecho o depende de algo externo). Nada se marca como probado sin haberlo ejecutado.

Entorno de verificación: contenedor Linux x86_64 sin GPU ni dispositivos; Godot 4.7.2 estable
oficial; render por software (Vulkan lavapipe en Xvfb) para el cliente; GitHub Actions
(`ubuntu-24.04`) para la integración continua.

| Sistema | Estado | Evidencia | Pendiente |
|---|---|---|---|
| Proyecto Godot 4.7.2 + GDScript tipado | PROBADO | Las pruebas unitarias (843 comprobaciones) compilan los guiones del juego y cargan las escenas; también en GitHub Actions | — |
| Mundo abierto por sectores (1,28 km², 400 sectores, LOD 0/1/2, MultiMesh) | PROBADO | Capturas del juego real en 4 zonas (`tools/ci/live_test.sh`); `tools/world/build_world.py` | Oclusión por portales en interiores |
| Terreno, agua, río, carreteras, puentes | EJECUTADO | Capturas en El Collado, Sotoalto y La Fragua | — |
| 39 edificios (26 modelos) con interiores, puertas y contenedores | EJECUTADO | `data/buildings/*.json`, recorrido en el juego; prueba de red abre puertas y contenedores | — |
| Vegetación (11 especies con 3 LOD, matorral, hierba), recolección (445 nodos) | PROBADO | Prueba de red recolecta; capturas | — |
| Ciclo día/noche, clima (5 tipos), bruma por zona, tormenta con rayos | EJECUTADO | Capturas `tormenta_noche`; `scripts/world/sky_weather.gd` | Lluvia sobre superficies interiores |
| Superviviente, Brumal, Zarzo, vehículos (Hyper3D Rodin) | EJECUTADO | `tools/blender/import_rodin.py`; visor de arte; capturas | Retoque manual de pesos en hombros (artefactos leves en poses extremas) |
| Animaciones de personaje (24 clips), criaturas (11/11/6), brazos 1.ª persona (13) | PROBADO | Prueba unitaria «tiene animaciones»; hojas de contacto en el visor | Mezcla parcial superior/inferior (andar + acción) |
| Controlador 1.ª persona (andar, correr, agacharse, saltar, nadar, subir escalones) | EJECUTADO | Partida real; movimiento validado por servidor en la prueba de red | — |
| Controles táctiles multitáctiles (joystick flotante, cámara, botones, zurdo, escala, opacidad) | IMPLEMENTADO | `scripts/ui/touch_controls.gd`; capturas con `--touch` | PENDIENTE probar en un teléfono físico |
| Interacción contextual (puertas, contenedores, recogida, recolección, estaciones, documentos) | PROBADO | Prueba de red: carrera por el mismo objeto, permisos de contenedor | — |
| Necesidades y estados (salud, hambre, sed, energía, temperatura, cansancio, humedad, 16 efectos) | PROBADO | Servidor (`server_survival.gd`); prueba de red consume objetos | Equilibrado fino con jugadores |
| Inventario por huecos, peso, equipo (7 ranuras), dividir, soltar, accesos rápidos | PROBADO | 20 comprobaciones unitarias + prueba de red (transferencias sin duplicar) | — |
| Fabricación (20 recetas, estaciones hoguera/banco, herramientas, niveles) | PROBADO | Prueba de red fabrica; referencias de datos verificadas | — |
| Construcción modular (13 estructuras, armazón + obra, encaje, permisos, límites) | PROBADO | Prueba de red coloca y termina estructuras; vista previa en `build_mode.gd` | Pruebas de colocación en pendientes extremas |
| Criaturas con IA por estados (acecho, huida, enterrarse, esporas) | EJECUTADO | `server_creatures.gd`; 40 criaturas en el mundo; prueba de red sin errores | Ajuste de dificultad con jugadores reales |
| Multijugador autoritativo (servidor dedicado y anfitrión), validación, interés por sectores | PROBADO | `tests/net_session.sh`: **40/40** (sincronización, trampas rechazadas, reconexión, persistencia tras parada y tras `kill -KILL`) | Cifrado del transporte (DTLS) |
| Grupos, chat por canales, silencio, denuncia, intercambio, señales, gestos | PROBADO / IMPLEMENTADO | Grupos e intercambio en la prueba de red; chat/denuncia implementados con interfaz | Moderación automática del chat |
| Reconexión del cliente | PROBADO | Prueba de red (cliente «Carla» se desconecta y vuelve); interfaz con 5 reintentos | — |
| Persistencia (escritura atómica, SHA-256, copias, recuperación, cuentas) | PROBADO | 10 comprobaciones unitarias de corrupción/truncado + prueba de red | Migraciones reales (solo hay versión 1) |
| Progresión: niveles, ventajas, desafíos (15), logros (7), encargos (8), cosméticos (7) | EJECUTADO | Diario y tablón en el juego; servidor concede todo | — |
| Interfaz: menú 3D, jugar, perfil, ajustes, legal, HUD, inventario, fabricación, construcción, mapa, grupo, diario, pausa, carga, colapso | EJECUTADO | Capturas de las 17 pantallas en la prueba en vivo, sin errores de guion | — |
| Textos en español e inglés (456 claves de interfaz + datos bilingües) | PROBADO | Prueba unitaria: ninguna clave usada sin texto en es/en | Revisión de estilo del inglés por nativo |
| Ajustes y perfiles gráficos bajo/medio/alto, accesibilidad | IMPLEMENTADO | `autoload/config.gd`, pantalla de ajustes capturada | Medir el efecto en hardware real |
| Efectos visuales (llama, chispas, rayo, esporas, auras) | EJECUTADO | Efectos CC0 de Binbun3D adaptados; capturas | — |
| Audio: 8 ambientes en bucle por zona, hoguera, música del menú, pasos en 7 superficies, puertas, interfaz, criaturas, trueno | EJECUTADO | 51 archivos Vorbis sintetizados por `tools/audio/synth.py`; prueba unitaria «sonido» (todo sonido usado existe y los bucles lo son); espectrogramas revisados | Escucha humana y mezcla final (el entorno no tiene salida de audio) |
| Exportación Android APK (arm64, firmada con clave de depuración) | PROBADO | APK de 115 MB (109 MB antes del audio) verificado con `apksigner` y `aapt2`, en local y en Actions (artefacto `valdebruma-android-apk`) | PENDIENTE: instalar en un dispositivo real |
| Android App Bundle (Gradle) | PROBADO | AAB de 117 MB generado con Gradle 8.11.1 / AGP 8.6.1 en local y en Actions (artefacto `valdebruma-android-aab`) | Firma de publicación |
| Firma de publicación y Google Play | PENDIENTE | Pasos en `ANDROID_BUILD_GUIDE.md`; secretos `VALDEBRUMA_KEYSTORE_*` soportados en CI | Requiere almacén de claves y cuenta del titular |
| Servidor dedicado Linux exportado, lanzador, systemd, Docker, administración de cuentas | EJECUTADO | Binario exportado arrancado; `run_server.sh` con parada ordenada; `--admin=list/ban/unban` probado | Servidor público (no existe) |
| Integración continua (GitHub Actions) | PROBADO | Ejecución nº 1 en verde: https://github.com/bfsoports/FerStudio-Downloads/actions/runs/44307271230 — unitarias 781/781, red 40/40, prueba en vivo 21/21 capturas sin errores, APK, AAB y servidor publicados como artefactos | Firma de publicación con secretos del titular |
| Publicidad | PENDIENTE (deliberado) | No hay SDK ni cuenta: no se simula ningún anuncio | Decidir modelo; integrar SDK real si procede |
| Privacidad y términos | PARCIAL | Borradores en el juego (`data/legal.json`) | Revisión legal y datos del titular |
| Rendimiento en móvil | PENDIENTE | Métricas de primitivas y llamadas en `PERFORMANCE_REPORT.md` | Medir FPS, temperatura y batería en teléfonos reales |

## Dependencias externas

- **Dispositivo Android físico o emulador con aceleración**: necesario para instalar y medir. No
  disponible en el entorno de desarrollo.
- **Almacén de claves de publicación y cuenta de Google Play** del titular.
- **Servidor público** (máquina con IP pública y puerto UDP abierto) si se quiere jugar por Internet.
- **Revisión legal** de privacidad y términos.
- **Hyper3D Rodin**: los modelos ya generados están en el repositorio; regenerarlos requiere cuenta.
