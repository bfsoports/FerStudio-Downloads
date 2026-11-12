extends Node
## Net — transporte de red (ENet) y despacho de mensajes (autoload).
##
## Responsabilidad: abrir servidor (dedicado o anfitrión local), conectar como cliente con
## reintentos limitados, enviar/recibir mensajes del Protocol y exponer el estado de conexión.
## En modo anfitrión el jugador local usa el identificador 1 y sus mensajes se entregan por
## llamada directa diferida: el MISMO código de servidor valida al anfitrión y a los remotos.
## Datos: par ENet, latencia medida. Señales: state_changed, message, failed, dropped.
## Persistencia: ninguna. Autoridad: el servidor (peer 1). Prueba: tests/net_two_clients.sh.

signal state_changed(state: int)
signal message(id: int, data: Variant)            # mensajes S recibidos por el cliente
signal failed(reason: String)                     # no se pudo conectar
signal dropped(reason: String)                    # conexión perdida estando dentro

enum State { OFFLINE, CONNECTING, HANDSHAKE, ONLINE }

var state: int = State.OFFLINE
var is_server := false          # este proceso ejecuta el servidor
var is_dedicated := false
var server: Node = null         # GameServer
var latency_ms := 0.0
var address := ""
var port := Protocol.DEFAULT_PORT
var _peer: ENetMultiplayerPeer = null
var _attempt := 0
var _max_attempts := 3
var _timer := 0.0
var _ping_timer := 0.0
var bytes_out := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _set_state(s: int) -> void:
	if state != s:
		state = s
		state_changed.emit(s)

# ---- servidor --------------------------------------------------------------------------------
## Abre el servidor. dedicated = sin jugador local. world_name = carpeta de persistencia.
func host(listen_port: int, dedicated: bool, world_name := "valle", options := {}) -> Error:
	leave()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(listen_port, Protocol.MAX_PLAYERS)
	if err != OK:
		_peer = null
		push_error("Net: no se pudo abrir el puerto %d (error %d)" % [listen_port, err])
		return err
	multiplayer.multiplayer_peer = _peer
	is_server = true
	is_dedicated = dedicated
	port = listen_port
	var gs: Node = (load("res://scripts/multiplayer/server/game_server.gd") as GDScript).new()
	gs.name = "GameServer"
	add_child(gs)
	server = gs
	gs.call("start", world_name, options)
	_set_state(State.ONLINE if dedicated else State.HANDSHAKE)
	print("[net] servidor escuchando en el puerto %d (%s)" % [listen_port, "dedicado" if dedicated else "anfitrión"])
	return OK

# ---- cliente -----------------------------------------------------------------------------------
func join(addr: String, to_port: int) -> void:
	leave()
	address = addr
	port = to_port
	_attempt = 0
	_try_connect()

func _try_connect() -> void:
	_attempt += 1
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		_peer = null
		failed.emit("address")
		_set_state(State.OFFLINE)
		return
	multiplayer.multiplayer_peer = _peer
	_timer = 0.0
	_set_state(State.CONNECTING)

func leave() -> void:
	if server != null:
		server.call("shutdown")
		server.queue_free()
		server = null
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	is_server = false
	is_dedicated = false
	_set_state(State.OFFLINE)

func _process(delta: float) -> void:
	if state == State.CONNECTING:
		_timer += delta
		if _timer > 7.0:
			_retry_or_fail("timeout")
	elif state == State.ONLINE and not is_server:
		_ping_timer += delta
		if _ping_timer > 2.0:
			_ping_timer = 0.0
			send(Protocol.C.NET_PING, Time.get_ticks_msec(), false)

func _retry_or_fail(reason: String) -> void:
	if _peer != null:
		_peer.close()
	multiplayer.multiplayer_peer = null
	if _attempt < _max_attempts:
		await get_tree().create_timer(0.6 * float(_attempt)).timeout
		if state == State.CONNECTING:
			_try_connect()
	else:
		_peer = null
		_set_state(State.OFFLINE)
		failed.emit(reason)

func _on_connected() -> void:
	_set_state(State.HANDSHAKE)

func _on_connection_failed() -> void:
	if state == State.CONNECTING:
		_retry_or_fail("refused")

func _on_server_disconnected() -> void:
	var was := state
	_peer = null
	multiplayer.multiplayer_peer = null
	_set_state(State.OFFLINE)
	if was == State.ONLINE:
		dropped.emit("server")
	else:
		failed.emit("closed")

func _on_peer_connected(id: int) -> void:
	if is_server and server != null:
		server.call("peer_connected", id)

func _on_peer_disconnected(id: int) -> void:
	if is_server and server != null:
		server.call("peer_disconnected", id)

## El cliente confirma que recibió WELCOME.
func mark_online() -> void:
	_set_state(State.ONLINE)

# ---- envío ------------------------------------------------------------------------------------------
## Cliente -> servidor.
func send(id: int, data: Variant = null, reliable := true) -> void:
	if is_server:
		if server != null and not is_dedicated:
			server.call_deferred("handle_message", 1, id, data)
		return
	if _peer == null or state < State.HANDSHAKE:
		return
	if reliable:
		_c2s.rpc_id(1, id, data)
	else:
		_c2s_u.rpc_id(1, id, data)

## Servidor -> un cliente.
func send_to(peer_id: int, id: int, data: Variant = null, reliable := true) -> void:
	if not is_server:
		return
	if peer_id == 1:
		if not is_dedicated:
			_deliver.call_deferred(id, data)
		return
	if _peer == null or not (peer_id in multiplayer.get_peers()):
		return
	if reliable:
		_s2c.rpc_id(peer_id, id, data)
	else:
		_s2c_u.rpc_id(peer_id, id, data)

func kick(peer_id: int) -> void:
	if is_server and _peer != null and peer_id != 1:
		_peer.disconnect_peer(peer_id)

func _deliver(id: int, data: Variant) -> void:
	if id == Protocol.S.NET_PONG:
		latency_ms = lerpf(latency_ms, float(Time.get_ticks_msec() - int(data)), 0.4)
		return
	message.emit(id, data)

@rpc("any_peer", "call_remote", "reliable", 1)
func _c2s(id: int, data: Variant) -> void:
	if is_server and server != null:
		server.call("handle_message", multiplayer.get_remote_sender_id(), id, data)

@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _c2s_u(id: int, data: Variant) -> void:
	if is_server and server != null:
		server.call("handle_message", multiplayer.get_remote_sender_id(), id, data)

@rpc("authority", "call_remote", "reliable", 1)
func _s2c(id: int, data: Variant) -> void:
	_deliver(id, data)

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _s2c_u(id: int, data: Variant) -> void:
	_deliver(id, data)
