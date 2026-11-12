class_name Protocol
extends RefCounted
## Protocol — protocolo de red versionado de Valdebruma (mensajes cliente↔servidor).
##
## Todos los mensajes viajan por dos RPC genéricos (fiable / no fiable) con un identificador
## numérico y una carga de tipos básicos. El servidor valida CADA campo y nunca acepta del
## cliente salud, inventario final, recompensas, propiedad ni resultados.
## Subir VERSION cuando cambie cualquier mensaje: el servidor rechaza versiones distintas.

const VERSION := 3
const DEFAULT_PORT := 24680
const MAX_PLAYERS := 24
const TICK_HZ := 20
const SNAPSHOT_HZ := 12
const MOVE_HZ := 15

# ---- cliente -> servidor ----
enum C {
	HELLO = 1, MOVE, INTERACT, INV_MOVE, INV_USE, INV_EQUIP, INV_UNEQUIP, INV_DROP, INV_SPLIT, QUICK_SET, HELD,
	CRAFT, BUILD_PLACE, BUILD_ADVANCE, BUILD_DISMANTLE, BUILD_PERM, GROUP, CHAT, EMOTE, MARK, REPORT, TRADE,
	CONTRACT, PRIVACY, RESPAWN, NET_PING, ACTION_CANCEL, CONTAINER_CLOSE, COSMETIC,
}
# ---- servidor -> cliente ----
enum S {
	WELCOME = 100, REJECT, SNAPSHOT, PLAYER_JOIN, PLAYER_LEAVE, PLAYER_UPDATE, CORRECT, STATS, INV, CONTAINER, CONTAINER_CLOSED,
	OBJECTS, OBJ_EVENT, ENV, NOTIFY, PROGRESS, GROUP, CHAT, EMOTE, MARK, TRADE, ACTION, NET_PONG, DOWN, RESPAWNED, DOC, NEARBY,
}

# ---- tipos de interacción (C.INTERACT) ----
enum I { DOOR = 1, PICKUP, HARVEST, CONTAINER, STATION, DOC, REST, WATER_DRINK, WATER_FILL, STRUCT_USE, CONTRACT_BOARD }

# ---- banderas de movimiento ----
const F_CROUCH := 1
const F_SPRINT := 2
const F_ON_FLOOR := 4
const F_LIGHT := 8
const F_SWIM := 16
const F_DOWN := 32

# ---- códigos de rechazo / aviso (S.REJECT y S.NOTIFY) ----
const R_VERSION := "version"
const R_FULL := "full"
const R_AUTH := "auth"
const R_BANNED := "banned"
const R_NAME := "name"
const R_DUPLICATE := "duplicate"

# ---- kinds de objeto del mundo ----
const O_DOOR := 1        # id = edificio * 64 + puerta
const O_CONTAINER := 2   # id = edificio * 64 + contenedor ; >= 1_000_000: de estructura / suelto
const O_PICKUP := 3
const O_HARVEST := 4
const O_STRUCT := 5

const REACH := 3.2            # alcance de interacción en metros (el servidor añade tolerancia)
const RELEVANCE := 170.0      # radio de relevancia de jugadores
const CREATURE_RELEVANCE := 130.0
const OBJECT_SECTORS := 2     # radio en sectores de objetos del mundo que recibe un cliente

static func door_key(building: int, door: int) -> int:
	return building * 64 + door

static func container_key(building: int, container: int) -> int:
	return building * 64 + container

static func name_ok(n: String) -> bool:
	var t := n.strip_edges()
	if t.length() < 3 or t.length() > 16:
		return false
	for ch in t:
		if not (ch.to_lower() in "abcdefghijklmnopqrstuvwxyzáéíóúüñ0123456789 _-"):
			return false
	return true
