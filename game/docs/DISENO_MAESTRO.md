# SECTOR ABANDONADO — Documento de diseño maestro

Shooter de supervivencia zombie por rondas, en primera persona, low poly 3D, para Android (horizontal, pantalla completa inmersiva). Motor: **Godot 4.7.2**, GDScript, renderizador **Mobile** (con respaldo automático a OpenGL/Compatibility en dispositivos sin Vulkan).

## 1. Pilares

1. **Divertido desde el segundo 10**: la ronda 1 empieza a los 2,5 s, con pistola, 500 puntos y barricadas que defender.
2. **Mapa pequeño pero denso**: 5 zonas compactas que se abren con puntos; siempre hay ruta de escape.
3. **Feedback contundente**: fogonazo, trazadoras, impactos, sangre estilizada, sacudida de cámara, marcadores de impacto, popups de puntos, sonidos propios por arma.
4. **Rendimiento primero**: pools, lotes de geometría, LOD de animación, perfiles BAJO/MEDIO/ALTO y resolución dinámica.

## 2. Bucle principal

Ronda → los zombies rompen barricadas o surgen del suelo → el jugador mata (+10 por impacto, +60/+80/+130/+400 por baja, bonus por disparo a la cabeza) → gasta puntos en puertas, armas de pared, munición, caja misteriosa, ventajas y La Forja → la siguiente ronda trae más zombies, más vida, más velocidad y más especiales. Sin límite de rondas; récords locales.

## 3. Mapa: SECTOR ABANDONADO

| Zona | Id | Acceso | Contenido |
|---|---|---|---|
| Patio de inicio ("Punto seguro") | `start` | inicio | 4 ventanas con barricadas, arma de pared AVISPA MK2 (1000) |
| Calle principal + zona de vehículos | `street` | escombros 750 | coches calcinados, contenedor, farolas, ROMPEPUERTAS 12 (750), CENTINELA AR (1400), ventaja CORAZA, caja misteriosa (posición inicial), 3 ventanas |
| Gasolinera | `gas` | escombros 1000 desde la calle | marquesina, surtidores, tienda, HALCÓN .50 (1500), ventaja MANO RÁPIDA, posición de caja, 3 ventanas |
| Almacén 7 | `warehouse` | portón 1250 desde la calle | estanterías, techo derruido, ventajas PASO LIGERO y BALA HUECA, posición de caja, 3 ventanas |
| Subestación 4 (zona especial) | `lab` | escombros 1000 (gasolinera) o compuerta 1500 (almacén) | **LA FORJA**, transformadores, ventaja SEGUNDO ALIENTO, 3 ventanas |

Rutas alternativas: la subestación conecta con gasolinera y almacén; calle, gasolinera y almacén forman un anillo cuando todo está abierto.

Navegación: un único navmesh pre-horneado (`resources/configuration/sector_navmesh.res`). Las puertas cerradas cortan el navmesh; al comprarlas se habilita un `NavigationLink3D`. Las ventanas cortan el navmesh: los zombies del exterior caminan hasta la ventana, rompen tablones y saltan dentro.

## 4. Rondas

- Tamaño de horda: 6, 9, 13, 17, 22 y luego `22 + 5·(r−5) + (r−5)^1.35` (máx. 220).
- Aparición escalonada: intervalo `max(0.3, 2.1 − 0.13·r)` s con variación ±30 %.
- Límite simultáneo configurable por perfil (14 / 20 / 24).
- Vida: lineal hasta ronda 9, ×1,1 compuesto desde la 10. Daño +4 % por ronda desde la 11.
- Velocidad: probabilidad de correr crece por ronda (por arquetipo).
- Especiales: probabilidades por ronda definidas en `resources/zombies/*.tres`.
- Jefe EL CAPATAZ cada 5 rondas. Intermedio de 9 s entre rondas, +2 granadas por ronda (máx. 4).

## 5. Enemigos (máquinas de estados, un script por estado)

`spawn → to_barrier → break_barrier → vault → chase ⇄ attack`, con `stagger` y `dead`.

| Arquetipo | Rasgos |
|---|---|
| Errante | velocidad media, resistencia media, cuerpo a cuerpo |
| Corredor | muy rápido, frágil, golpes rápidos (desde ronda 3) |
| Blindado | lento, −45 % de daño al cuerpo, la cabeza ignora el blindaje (desde ronda 6) |
| Tanque | ×1,45 de tamaño, vida enorme, golpe sísmico con onda expansiva (desde ronda 9, máx. 2) |
| EL CAPATAZ (jefe) | carga en línea recta, golpe sísmico de área, al 50 % de vida ruge y llama a 5 corredores; barra de vida; 2500 puntos |

## 6. Armas (datos en `resources/weapons/*.tres`)

| Arma | Tipo | Daño | Cadencia | Cargador | Efecto Forja |
|---|---|---|---|---|---|
| P-9 VIGÍA | pistola (inicial) | 34 | 380 rpm semi | 10 | P-9 ÚLTIMO ALIENTO: balas explosivas |
| ROMPEPUERTAS 12 | escopeta | 8×26 | 72 rpm | 6 (cartucho a cartucho) | ESCUPEFUEGO 12: incendiaria |
| AVISPA MK2 | subfusil | 24 | 820 rpm auto | 30 | ENJAMBRE: descarga en cadena |
| CENTINELA AR | fusil de asalto | 42 | 600 rpm auto | 30 | GUARDIÁN ETERNO: perforante |
| HALCÓN .50 | francotirador | 260 | 48 rpm | 5 | OJO DEL JUICIO: explosiva |
| TRITURADORA M60X | ametralladora | 40 | 700 rpm auto | 100 | APOCALIPSIS: incendiaria |

Disparo por raycast (hitscan), dispersión dinámica (cadera/ADS/movimiento/salto/floración), retroceso de cámara, caída de daño por distancia, penetración, perdigones agregados por objetivo (los puntos por impacto no se multiplican por perdigón).

## 7. Economía

Inicio 500. +10 por impacto, baja +60 a +2500 según arquetipo, +40/+60/+100 por disparo a la cabeza, +10 por tablón reparado (máx. 60/ronda). Precios: puertas 750–1500, armas de pared 750–1500, munición 200–750 (×4 si está mejorada), caja 950, ventajas 2000–3500, Forja 5000. Las compras con precio exigen mantener pulsado 0,35 s (configurable) para evitar compras accidentales.

## 8. Controles táctiles

Izquierda: joystick flotante (empujar al borde hacia delante = correr). Derecha: arrastre de cámara. Botones: disparo (mantener para automáticas), apuntar (alternar), recarga, salto, granada, interactuar (aparece solo con objetivo; mantener para comprar/reparar), cambio de arma, pausa. Cada dedo se enruta por índice: un dedo que empieza en un botón nunca gira la cámara.

## 9. Perfiles gráficos

| | BAJO | MEDIO | ALTO |
|---|---|---|---|
| Escala 3D | 0,70 | 0,85 | 1,0 |
| Sombras del sol | no | 22 m, ortogonal | 40 m, 2 cortes |
| Zombies simultáneos | 14 | 20 | 24 |
| Partículas | 45 % | 75 % | 100 % |
| Luces decorativas | 4 | 8 | 14 |
| Glow | no | sí | sí |
| Sombra falsa (blob) | no | sí | sí |
| Distancia de dibujo | 45 m | 65 m | 90 m |

Además: resolución dinámica en móvil (`PerfGovernor`), LOD de animación por distancia/visibilidad, pools de zombies y efectos, geometría estática fusionada por material y celda de 24 m, oclusores en muros grandes, materiales compartidos y una "paleta" con color por vértice.
