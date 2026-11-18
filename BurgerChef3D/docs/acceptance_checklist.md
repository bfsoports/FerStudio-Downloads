# Lista de aceptación

Estados permitidos: Pendiente, Implementado, Verificado, Fallido, Bloqueado por dependencia externa.
**Verificado** solo significa comprobado de verdad. Lo escrito pero no ejecutado figura como **Implementado**.

| ID | Requisito | Estado | Método de verificación | Resultado observado | Problemas conocidos |
|---|---|---|---|---|---|
| R01 | El proyecto abre en Godot 4.7.2 | Implementado | Abrir `project.godot` en el editor | No probado (sin Godot en el entorno) | Primera apertura puede mostrar errores (known_issues 1) |
| R02 | Sin errores de sintaxis en los scripts | Implementado | `tools/static_check.py` + abrir en el editor | Comprobación estática: 0 errores en 91 scripts. No es un compilador de GDScript | known_issues 1 |
| R03 | Escenas y recursos referenciados correctamente | Verificado | `tools/static_check.py` (rutas res://, ExtResource, nodos `$`) | 0 errores, 0 avisos | La importación de assets ocurre al abrir en Godot |
| R04 | El juego inicia en el menú principal | Implementado | Ejecutar F5 | No probado | boot.tscn -> main_menu.tscn |
| R05 | El menú principal funciona (9 secciones con contenido) | Implementado | Recorrer cada botón | No probado | Sin botones decorativos: solo hay secciones implementadas |
| R06 | Orientación horizontal forzada | Implementado | Instalar en móvil | No probado | `display/window/handheld/orientation=4` (sensor horizontal) |
| R07 | La pantalla se adapta a distintos tamaños | Implementado | Probar 16:9, 18:9, 20:9, tablet | No probado | Stretch canvas_items + expand, contenedores y anclas, zona segura |
| R08 | Movimiento del jugador (aceleración, gravedad, colisiones) | Implementado | Jugar | No probado | PlayerController |
| R09 | Cámara independiente del joystick, límite vertical, inversión | Implementado | Jugar en móvil | No probado | TouchControls: un dedo = un control |
| R10 | Controles táctiles (joystick, cámara, botón) | Implementado | Móvil | No probado |  |
| R11 | Controles de escritorio (WASD, ratón, E, Esc) | Implementado | Escritorio | No probado |  |
| R12 | Las colisiones impiden atravesar paredes y mostradores | Implementado | Jugar | No probado |  |
| R13 | Los ingredientes pueden recogerse | Implementado | Jugar / test_delivery | No probado | Rayo físico con alcance 3,2 m; no atraviesa paredes |
| R14 | Los ingredientes pueden colocarse (ranuras) | Implementado | Jugar | No probado |  |
| R15 | La plancha y la freidora funcionan | Implementado | Jugar | No probado | Capacidad y velocidad dependen de mejoras |
| R16 | Estados de cocción crudo/cocinándose/cocinado/quemado | Implementado | tests/unit/test_cooking.gd | Prueba escrita, no ejecutada |  |
| R17 | Las recetas se validan | Implementado | tests/unit/test_recipe_validator.gd | Prueba escrita, no ejecutada | 8 estados de resultado |
| R18 | Los productos se construyen visualmente capa a capa | Implementado | Jugar | No probado | BurgerStack |
| R19 | Los clientes se mueven correctamente (rutas, cola) | Implementado | Jugar | No probado | Rutas de puntos sin NavMesh |
| R20 | Los pedidos se generan | Implementado | Jugar / test_delivery | No probado |  |
| R21 | Los pedidos pueden entregarse (campana) | Implementado | tests/integration/test_delivery.gd | Prueba escrita, no ejecutada |  |
| R22 | Los pedidos incorrectos se gestionan | Implementado | tests/integration/test_delivery.gd | Prueba escrita, no ejecutada |  |
| R23 | Las recompensas son correctas | Implementado | tests/unit/test_rewards_rules.gd | Prueba escrita, no ejecutada |  |
| R24 | Los niveles pueden completarse | Implementado | Jugar; coherencia de datos con `validate_data.py` | Datos: objetivos alcanzables en tiempo. Juego: no probado | Equilibrio sin jugar (known_issues 12) |
| R25 | Los niveles pueden repetirse sin duplicar recompensas únicas | Implementado | Jugar | No probado | Premio del nivel solo la primera vez; repetición da XP al 50 % |
| R26 | Existen al menos 30 niveles configurados por datos | Verificado | `tools/validate_data.py` | 30 niveles, 0 errores |  |
| R27 | Las misiones funcionan (20 + 10 desafíos) | Implementado | tests/unit/test_missions.gd | Datos verificados (20/10/10); prueba no ejecutada |  |
| R28 | Los logros funcionan (10) | Implementado | tests/unit/test_missions.gd | Datos verificados; prueba no ejecutada |  |
| R29 | Las monedas funcionan (transacciones validadas) | Implementado | tests/unit/test_economy.gd | Prueba escrita, no ejecutada |  |
| R30 | Las mejoras alteran el juego (12 mejoras) | Implementado | tests/unit/test_economy.gd, tests/unit/test_tutorial.gd | Pruebas escritas, no ejecutadas | Incluye «Recetas nuevas», «Catálogo de decoración» y «Fregadero rápido» (known_issues 53-55) |
| R31 | La personalización altera el escenario | Implementado | Comprar y entrar a un turno | No probado | 43 artículos (10 con el catálogo de decoración); se aplica al empezar el turno |
| R32 | El modo libre funciona | Implementado | Jugar | No probado | Economía al 50 %; récords persistentes |
| R33 | El tutorial es jugable | Implementado | Jugar JUGAR > Tutorial; tests/unit/test_tutorial.gd | No probado en el motor; la tarjeta cabe sobre el joystick en 9 tamaños de pantalla (`check_ui_layout.py`) | known_issues 5 y 56 |
| R34 | La pausa detiene los sistemas pertinentes | Implementado | Jugar | No probado | get_tree().paused + overlay always |
| R35 | Los ajustes funcionan y persisten | Implementado | tests/unit/test_save.gd | Prueba escrita, no ejecutada | Incluye el ajuste de vibración (solo en dispositivos táctiles) |
| R36 | El audio funciona (música, 17 efectos, volúmenes separados) | Implementado | Jugar; existencia de archivos | 19 WAV generados y presentes. Reproducción no probada |  |
| R37 | El guardado persiste entre sesiones | Implementado | tests/unit/test_save.gd | Prueba escrita, no ejecutada | Escritura atómica + copia de seguridad |
| R38 | La carga restaura el progreso y tolera datos corruptos | Implementado | tests/unit/test_save.gd | Prueba escrita, no ejecutada |  |
| R39 | No hay botones esenciales sin funcionalidad | Implementado | Revisión de código | Revisado: cada botón visible y cada estación ejecuta su acción | El fregadero lava las bandejas sucias (known_issues 6) |
| R40 | No existen referencias rotas a recursos | Verificado | `tools/static_check.py` | 0 errores |  |
| R41 | Se han ejecutado las pruebas disponibles | Pendiente | `godot --headless ... test_runner.tscn` | No ejecutadas | Bloqueado: requiere Godot |
| R42 | Se ha revisado el rendimiento | Pendiente | Perfilar en dispositivo | Sin mediciones | known_issues 3 |
| R43 | La exportación Android está configurada | Implementado | `export_presets.cfg` | Dos presets (Google Play AAB y Amazon APK), Gradle y AdMob; no exportada | docs/build_android.md, docs/amazon_appstore.md |
| R44 | Compilación instalada y probada en dispositivo real | Bloqueado por dependencia externa | adb install | — | Requiere Godot y un móvil |
| R45 | Requisitos vigentes de Google Play revisados | Bloqueado por dependencia externa | Consultar documentación oficial | — | Sin acceso a internet en el entorno |
| R46 | Documentación actualizada | Implementado | Revisión | 10 documentos en docs/ + README |  |
| R47 | Recursos y licencias documentados | Implementado | docs/licenses.md | Hecho: packs CC0, modelos de Tripo y música de uso libre según el usuario (7-11-2026), texto de la OFL en `assets/fonts/OFL.txt` y licencias de Godot en Créditos | known_issues 15 |
| R48 | No quedan errores críticos conocidos sin resolver | Pendiente | Ejecutar y probar | Desconocido hasta abrir en Godot | known_issues 1 |

Resumen: 3 verificados, 40 implementados sin verificar en el motor, 3 pendientes, 2 bloqueados por dependencia externa.
