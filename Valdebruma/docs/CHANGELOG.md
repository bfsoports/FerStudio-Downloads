# Registro de cambios

## 0.1.0 — primera versión jugable

### Mundo y arte
- Valle de 1,28 km² generado por `tools/world/build_world.py`: relieve, río, marjal, caminos, puentes,
  pasarela, 10 regiones, 29 lugares, 39 edificios, 1 020 objetos de escenario, 17 345 plantas, 445 nodos de recolección.
- 26 edificios con interiores, 129 objetos de escenario, 50 objetos, 13 estructuras y 39 modelos de vegetación con LOD generados en Blender.
- Superviviente, Brumal, Zarzo, turismo, furgoneta y tractor generados con Hyper3D Rodin, con esqueleto y animaciones, optimizados para móvil.
- Brazos en primera persona a partir del superviviente, con dedos y agarres por objeto.
- 149 materiales PBR (texturas CC0 de Poly Haven), sombreadores de terreno, agua, follaje con viento y personaje teñible.
- Efectos CC0 de Binbun3D adaptados: llama de hoguera, chispas, rayos de tormenta, esporas, auras.

### Juego
- Supervivencia: salud, hambre, sed, energía, temperatura, cansancio, humedad y 16 estados.
- Inventario por huecos con peso, equipo, contenedores, botín por tablas, fabricación (20 recetas), construcción modular (13 piezas).
- Criaturas con IA por estados: Brumal (acecho), Zarzo (huidizo, se entierra), Farol (esporas).
- Día/noche, clima con 5 estados, bruma por zonas, tormentas con rayos y trueno.
- Progresión: niveles con ventajas, 15 desafíos, 7 logros, 8 encargos, 7 cosméticos, 9 documentos.

### Multijugador
- Servidor autoritativo (dedicado o en el dispositivo anfitrión), protocolo versionado (v3), validación de todas las acciones, interés por sectores, grupos, chat por canales, intercambio, señales, gestos, denuncias, reconexión.
- Persistencia atómica con suma SHA-256, copias rotatorias y recuperación; orden `--admin` para bloquear cuentas.

### Interfaz
- Menú con escena 3D, crear/unirse, perfil y cosméticos, ajustes (control, sonido, gráficos, juego, accesibilidad), créditos y legal.
- HUD, controles táctiles multitáctiles, chat, inventario, fabricación, construcción con vista previa, mapa con señales, grupo, diario, pausa, carga, colapso y tutorial.
- Español e inglés (456 claves de interfaz).

### Herramientas y entrega
- Exportación Android (APK arm64 y AAB), servidor Linux, lanzador, unidad systemd y Dockerfile.
- Pruebas: 781 comprobaciones unitarias, sesión multijugador real (40/40), prueba en vivo con capturas.
- GitHub Actions: pruebas, APK, AAB, servidor y capturas como artefactos.
