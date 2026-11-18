# Informe de QA

Solo se marca como superado lo que se ha ejecutado. Fecha de las ejecuciones: 18-11-2026.

## Entornos

| Entorno | Detalle |
|---|---|
| Local | Contenedor Linux x86_64, 4 núcleos, sin GPU; Godot 4.7.2 estable oficial; cliente con Vulkan por software (lavapipe) en Xvfb |
| CI | GitHub Actions `ubuntu-24.04`, ejecución nº 1 del flujo «Valdebruma CI» (commit `75285e4`): https://github.com/bfsoports/FerStudio-Downloads/actions/runs/44307271230 |
| Android | **No disponible** (sin dispositivo ni emulador con aceleración) |

## Resultados automáticos

| Prueba | Qué comprueba | Local | CI |
|---|---|---|---|
| Unitarias (`-- --unit-tests`) | Inventario (apilar, quitar, transferir sin duplicar, dividir, reducir), persistencia (escritura atómica, suma de control, corrupción, truncado, copias), saneado de red, mapa del mundo, referencias cruzadas de todos los datos, existencia de modelos/iconos/materiales/efectos, animaciones, textos es/en de cada clave usada, compilación de todos los guiones y escenas, sonidos (desde el commit siguiente) | **843/843** | **781/781** (antes de añadir la sección de sonido) |
| Sesión multijugador real (`tests/net_session.sh`) | Servidor dedicado + clientes ENet: sincronización, movimiento validado, teletransporte corregido, peticiones inválidas sin efecto, fabricación, construcción, permisos de arcón (privado/ocupado), desmontaje ajeno rechazado, intercambio sin duplicar, carrera por un objeto, reconexión, persistencia tras parada ordenada y tras `kill -KILL` | **40/40** | **40/40** |
| Prueba en vivo (`tools/ci/live_test.sh`) | Juego real con ventana: menú y 6 pantallas, crear partida como anfitrión, entrar al valle, 4 vistas (El Collado de día, Sotoalto al atardecer, La Fragua, tormenta de noche) con HUD táctil, 9 pantallas de partida | **21/21 capturas, 0 errores** | **21/21 capturas, 0 errores** |
| Exportación APK | Exportar, firmar (depuración), verificar firma y manifiesto | Correcto (111 MB con audio) | Correcto (109 MB, artefacto `valdebruma-android-apk`) |
| Exportación AAB (Gradle) | Plantilla Gradle, compilación con AGP | Correcto (117 MB) | Correcto (artefacto `valdebruma-android-aab`) |
| Servidor dedicado | Exportar, arrancar, escuchar, guardar y cerrar | Correcto | Correcto (artefacto `valdebruma-servidor-linux`) |
| Administración de cuentas | `--admin=list/ban/unban` sobre datos reales | Correcto | — |

Las capturas de CI se descargan como artefacto `valdebruma-prueba-en-vivo` (incluye `live.log` y
los registros de la sesión de red).

## Pruebas manuales realizadas (local, render por software)

| Área | Resultado |
|---|---|
| Recorrido por el valle en 8+ lugares, día/noche, lluvia y tormenta | Correcto. Corregido durante el desarrollo: follaje negro por `fog_aerial_perspective` en el renderizador Mobile |
| Personajes y criaturas de Hyper3D: 24 + 11 + 11 clips revisados en hoja de contacto | Correcto; leves deformaciones de hombro en poses extremas |
| Brazos en 1.ª persona con los 6 objetos de mano | Correcto tras ajustar giro de antebrazo y pulgar |
| Efectos: llama, chispas, impacto, rayo, nube, aura | Correcto en Vulkan móvil |
| Menú, ajustes (cambio de idioma en caliente, perfiles gráficos), legal | Correcto |
| Inventario, fabricación, construcción (vista previa y encaje), mapa, grupo, diario, pausa | Correcto visualmente; acciones verificadas por la prueba de red |
| Audio | Generado y revisado por espectrograma y niveles; **no escuchado** (el entorno no tiene salida de sonido) |

## Pendiente (no ejecutado)

- Instalación y partida en teléfonos Android reales (gama baja, media, alta): controles táctiles,
  rendimiento, temperatura, batería, pausa/reanudación de la app, cambios de red Wi-Fi/datos.
- Partida con más de 3 jugadores simultáneos y con latencia real de Internet.
- Escucha humana del audio y mezcla final.
- Pruebas de accesibilidad con usuarios (tamaño de texto, alto contraste, zurdos).
- Larga duración (servidor varios días; crecimiento de archivos de registro).

## Defectos encontrados por las pruebas y corregidos

| Defecto | Cómo se encontró | Corrección |
|---|---|---|
| Tras un salto largo (reaparecer lejos, corrección del servidor) el jugador podía caer bajo el terreno antes de que existiera la colisión del sector nuevo | Capturas de la prueba en vivo en GitHub Actions (Sotoalto y La Fragua mostraban la cara inferior del terreno); diagnóstico con la posición y el nivel del sector en la captura | `PlayerController`: nunca por debajo de la altura analítica del terreno |
| La hora y el lugar del HUD quedaban bajo la barra de menús táctil | Revisión de capturas con `--touch` | Bloque desplazado al hueco libre y texto con contorno |
| Falsos «correcto» en pruebas unitarias lanzadas con `-s` (guiones compilados antes de los autoloads) | Revisión del registro | Pruebas lanzadas desde `Boot` y cada sección debe terminar para contar |

## Defectos conocidos

| Nº | Descripción | Gravedad | Estado |
|---|---|---|---|
| 1 | Leves deformaciones en el hombro del superviviente en algunas poses de acción | Baja | Abierto |
| 2 | Aviso del empaquetado Android por icono monocromo vacío (`themed_icon`) | Muy baja | Abierto (añadir icono monocromo) |
| 3 | Las animaciones de acción del jugador remoto sustituyen a las de andar (sin mezcla superior/inferior) | Baja | Abierto |
| 4 | Tamaño del APK (111 MB) por texturas ETC2 sin comprimir en el paquete | Media | Mitigado en parte (−4 MB); ver `PERFORMANCE_REPORT.md` |
