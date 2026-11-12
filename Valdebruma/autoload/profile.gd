extends Node
## Profile — perfil local del jugador (autoload).
##
## Datos: identificador de cuenta y secreto generados en el dispositivo (identidad estable
## de sesión, sin datos personales), nombre visible, cosméticos elegidos, servidores
## recientes y preferencias de privacidad. Persistencia: user://profile.json con escritura
## atómica y copia de seguridad; si el archivo falta o está dañado se crea uno nuevo.
## El secreto nunca se muestra ni se escribe en registros.

const PATH := "user://profile.json"

var account := ""
var token := ""
var player_name := "Superviviente"
var cosmetics: Dictionary = {"jacket": "chaqueta_oliva", "hat": "gorro_rojo"}
var servers: Array = []            # [{name, host, port}]
var hide_nearby := false
var tutorial_done := false
var muted: Dictionary = {}         # nombres silenciados en el chat
var ephemeral := false             # perfiles de prueba: no se guardan

func _ready() -> void:
	var d := ServerPersistence.read_safe(PATH)
	account = String(d.get("account", ""))
	token = String(d.get("token", ""))
	player_name = String(d.get("name", player_name))
	if d.get("cos") is Dictionary:
		cosmetics = d.cos
	if d.get("servers") is Array:
		servers = d.servers
	hide_nearby = bool(d.get("hide", false))
	tutorial_done = bool(d.get("tutorial", false))
	if d.get("muted") is Dictionary:
		muted = d.muted
	if account.length() < 16 or token.length() < 16:
		var c := Crypto.new()
		account = c.generate_random_bytes(16).hex_encode()
		token = c.generate_random_bytes(24).hex_encode()
		save()

func use_test_identity(seed_text: String, shown_name: String) -> void:
	ephemeral = true
	account = ("test" + seed_text).sha256_text().left(32)
	token = ("secret" + seed_text).sha256_text().left(48)
	player_name = shown_name

func save() -> void:
	if ephemeral:
		return
	ServerPersistence.write_atomic(PATH, {"account": account, "token": token, "name": player_name, "cos": cosmetics, "servers": servers,
		"hide": hide_nearby, "tutorial": tutorial_done, "muted": muted})

func remember_server(host: String, port: int, shown: String) -> void:
	for s: Dictionary in servers:
		if String(s.host) == host and int(s.port) == port:
			s.name = shown
			save()
			return
	servers.push_front({"name": shown, "host": host, "port": port})
	if servers.size() > 8:
		servers.resize(8)
	save()

func forget_server(index: int) -> void:
	if index >= 0 and index < servers.size():
		servers.remove_at(index)
		save()
