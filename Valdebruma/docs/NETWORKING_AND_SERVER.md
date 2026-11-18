# Red y servidor

## Modelo

**Servidor autoritativo.** Puede ser dedicado (sin ventana) o alojado por un jugador (el servidor
corre en el mismo proceso que su cliente; el anfitrión es el par 1 y sus mensajes se entregan por
llamada directa). En ambos casos el código del servidor es el mismo.

Transporte: **ENet** (UDP) mediante el multijugador de alto nivel de Godot, con dos RPC genéricos
por sentido (fiable y no fiable). Puerto por defecto 24680. Hasta 24 jugadores.

## Protocolo (`scripts/multiplayer/protocol.gd`, versión 3)

Cada mensaje es `[id, datos]`, con tipos básicos. El servidor rechaza clientes de otra versión.

- **Cliente → servidor** (`Protocol.C`): HELLO, MOVE, INTERACT, INV_MOVE, INV_USE, INV_EQUIP,
  INV_UNEQUIP, INV_DROP, INV_SPLIT, QUICK_SET, HELD, CRAFT, BUILD_PLACE, BUILD_ADVANCE,
  BUILD_DISMANTLE, BUILD_PERM, GROUP, CHAT, EMOTE, MARK, REPORT, TRADE, CONTRACT, PRIVACY, RESPAWN,
  NET_PING, ACTION_CANCEL, CONTAINER_CLOSE, COSMETIC.
- **Servidor → cliente** (`Protocol.S`): WELCOME, REJECT, SNAPSHOT, PLAYER_JOIN/LEAVE/UPDATE,
  CORRECT, STATS, INV, CONTAINER, CONTAINER_CLOSED, OBJECTS, OBJ_EVENT, ENV, NOTIFY, PROGRESS, GROUP,
  CHAT, EMOTE, MARK, TRADE, ACTION, NET_PONG, DOWN, RESPAWNED, DOC, NEARBY.

## Entrada y autenticación

1. El cliente conecta (3 intentos, 7 s cada uno) y envía HELLO con versión, cuenta, secreto, nombre
   y cosméticos.
2. El servidor valida versión, aforo, nombre (3–16 caracteres permitidos) y la identidad: la primera
   vez guarda `sal + SHA-256(sal + secreto)`; después compara. Un nombre ya usado por otra cuenta se
   rechaza. Cuentas bloqueadas: `banned`.
3. WELCOME con estado completo; a partir de ahí, actualizaciones incrementales.

La identidad es aleatoria y local: no hay correo ni contraseña. Si el usuario borra los datos de la
app, el servidor lo verá como un jugador nuevo.

## Qué valida el servidor (nunca acepta resultados del cliente)

| Petición | Comprobaciones |
|---|---|
| Movimiento | Presupuesto de velocidad según estado (andar, esprintar, nadar, caer), altura frente al terreno, límites del valle, paso a través de paredes (segmento contra colisiones de edificios y puertas). Si falla, corrige; si se repite, lo anota en `anomalies.log` |
| Interacción | Alcance (3,2 m + tolerancia), línea de visión, estado del objeto, llave necesaria, permisos del dueño o del grupo, ocupado por otro |
| Inventario | Huecos válidos, cantidades, contenedor abierto por ese jugador, transferencia atómica (sin duplicar) |
| Fabricación | Nivel, estación cercana, herramienta, ingredientes, espacio para el resultado; acción con duración que se cancela si te mueves |
| Construcción | Límites por jugador y por mundo, distancia, solape, agua, pendiente, carretera, edificio, altura, línea de visión, materiales |
| Social | Frecuencia y longitud del chat, tamaño del grupo, distancia para intercambiar, existencia del objeto en el momento de aceptar |
| General | Cubo de fichas por jugador (40 fichas, 20/s) contra inundación de peticiones; expulsión tras 200 excesos; datos saneados con `Guard` (tipos, rangos, NaN/∞, longitudes) |

## Replicación e interés

- **Fotos de estado** a 12 Hz (no fiables) con jugadores en un radio de 170 m y criaturas en 130 m.
- **Objetos del mundo** por sectores: el cliente recibe los de su sector y los vecinos (radio 2) al
  entrar en ellos y eventos puntuales después (`OBJ_EVENT`).
- **Estadísticas, inventario, progreso, clima** solo cuando cambian.
- Posiciones de compañeros de grupo cada 2 s para mapa y HUD.

## Persistencia

`ServerPersistence`: archivos JSON con la suma SHA-256 del cuerpo en la primera línea. Escritura en
`.tmp` y renombrado; copias `.bak1` y `.bak2`; lectura con verificación y recurso a las copias; los
archivos dañados se apartan. El mundo se guarda cada 15 s si hay cambios, al salir el último
jugador y en la parada ordenada (archivo `stop`). Cada jugador se guarda al salir y periódicamente.

## Reconexión

Si se pierde la conexión estando dentro, la interfaz reintenta 5 veces (con pantalla de carga y
opción de cancelar). El servidor conserva el estado del jugador; al volver, recupera posición,
inventario y progreso. Probado en `tests/net_session.sh` (cliente «Carla»).

## Pruebas

`tests/net_session.sh` arranca un servidor dedicado real y varios clientes ENet automáticos
(`tests/bot_client.gd`) y comprueba 40 condiciones: sincronización entre jugadores, carrera por el
mismo objeto, permisos de contenedor, trampas rechazadas (teletransporte, peticiones inválidas),
fabricación, construcción, intercambio sin duplicar, reconexión y persistencia tras parada ordenada
y tras `kill -KILL`. Resultado actual: **40/40**, en local y en GitHub Actions.

## Limitaciones

- Sin cifrado (DTLS) ni NAT traversal: para jugar por Internet hace falta un servidor con puerto
  UDP abierto.
- Sin lista pública de servidores ni emparejamiento.
- Anticheat basado en validación del servidor; no hay detección en el cliente.
