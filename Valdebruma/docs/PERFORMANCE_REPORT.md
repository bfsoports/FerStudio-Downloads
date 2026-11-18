# Informe de rendimiento

> Todas las cifras de fotogramas por segundo de este documento proceden de render **por software**
> (CPU) y **no** representan el rendimiento en un móvil. Lo medido con fiabilidad es la complejidad
> de escena (llamadas de dibujo, primitivas, nodos), el tamaño de los recursos y el coste del
> servidor. Medir FPS, temperatura y batería en teléfonos reales está **PENDIENTE**.

## Objetivos de diseño (perfil medio)

| Métrica | Objetivo gama media | Estado |
|---|---|---|
| Llamadas de dibujo por fotograma | < 500 | 252–429 medido |
| Primitivas por fotograma | < 250 000 | 99 000–174 000 medido |
| Personaje principal | ≤ 12 000 triángulos | 10 758 |
| Criaturas | ≤ 8 000 | Brumal 8 000 · Zarzo 4 000 · Farol 1 244 |
| Vehículos | ≤ 6 000 | 5 000 / 5 000 / 6 000 |
| Brazos 1.ª persona | ≤ 3 000 | 1 839 |
| Texturas de personaje | ≤ 1024² | 1024² (ORM y normales 512–1024²) |
| FPS | 30 estables (bajo), 60 (medio/alto) | PENDIENTE de hardware |

## Escena del juego real (distancia de visión 4 sectores, perfil medio)

Medido por `tools/ci/live_test.sh` dentro del juego real, idéntico en local y en GitHub Actions:

| Vista | Sectores cargados | Nodos | Llamadas de dibujo | Primitivas |
|---|---|---|---|---|
| El Collado (día) | 81 | 1 793 | 408 | 145 629 |
| Sotoalto (atardecer, pueblo) | 94 | 3 955 | 429 | 173 569 |
| La Fragua (industrial) | 95 | 3 649 | 298 | 144 991 |
| Tormenta de noche | 85 | 2 071 | 252 | 98 949 |

Técnicas aplicadas: MultiMesh por especie y nivel de detalle (3 LOD de árbol), terreno por sector
con bordes, hierba solo en el anillo cercano y con densidad ajustable, colisiones simples, luces sin
sombra con desvanecido por distancia, una sola luz direccional con sombras configurables, efectos
sin lectura del búfer de profundidad, construcción de sectores repartida entre fotogramas
(4–6 ms en juego).

## Perfiles gráficos

| Ajuste | Bajo | Medio | Alto |
|---|---|---|---|
| Escala de render 3D | 0,70 | 0,85 | 1,00 |
| Distancia de visión (sectores) | 3 | 4 | 5 |
| Sombras | No | Medias | Altas |
| Hierba | 0 % | 50 % | 100 % |
| Efectos | Bajo (sin luces de efectos) | Medio | Alto |
| Límite de FPS | 30 | 60 | 60 |
| Relieve (mapas normales) | No | Sí | Sí |

En Android se aplica el perfil medio la primera vez.

## Tamaño de la entrega

| Elemento | Tamaño |
|---|---|
| APK de depuración (arm64) | 109 MB |
| — texturas importadas (ETC2/ASTC) | 69 MB |
| — modelos importados | 7,7 MB |
| — bibliotecas nativas (motor) | 26 MB |
| — datos del mundo | 1,9 MB |
| AAB (armv7 + arm64) | 117 MB |
| Audio (51 archivos Vorbis) | ≈ 6 MB |

Mejoras previstas para bajar de 80 MB: normales de 1024 → 512 en vehículos y criaturas (−7 MB),
reutilizar ORM en tonos planos, comprimir el atlas de carteles, y en Play usar el AAB (cada
dispositivo descarga solo su arquitectura).

## Servidor dedicado

Medido con el binario exportado, 40 criaturas activas, mundo «perf», 4 núcleos:

| Situación | CPU (de un núcleo) | Memoria residente |
|---|---|---|
| Sin jugadores | 1,1 % | 117 MB |
| 2 jugadores reales jugando su guion | 1,6 % | 117 MB |
| Mundo guardado en disco | — | 60 KB |

Frecuencias: fotos de estado 12 Hz, acciones 20 Hz, criaturas 10 Hz, tarea lenta 1 Hz. Ancho de
banda por jugador estimado en decenas de kbit/s (fotos no fiables con jugadores en 170 m y
criaturas en 130 m); PENDIENTE de medir con 20+ jugadores.

## Próximos pasos de medición

1. Instalar el APK en un móvil de gama media (Vulkan 1.1) y medir FPS con el monitor de Godot
   (`Performance.TIME_FPS`) en las cuatro vistas de la prueba en vivo.
2. Medir temperatura y consumo durante 20 minutos en los perfiles bajo y medio.
3. Repetir en gama baja; si no alcanza 30 FPS, bajar distancia a 2 sectores y escala a 0,6.
