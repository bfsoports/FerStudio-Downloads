class_name ServerPersistence
extends RefCounted
## ServerPersistence — guardado atómico y versionado del estado del servidor.
##
## Responsabilidad: cuentas (identidad de sesión), perfiles de jugador y estado del mundo.
## Formato: primera línea = SHA-256 del cuerpo; resto = JSON con claves ordenadas.
## Escritura atómica: se escribe en .tmp, se rota la copia anterior a .bak1/.bak2 y se
## renombra. Lectura: si el archivo principal está dañado se prueban las copias y el
## dañado se aparta como .corrupt-<fecha> (nunca se borra progreso).
## Archivos (user://server/<mundo>/): accounts.json, world.json, players/<cuenta>.json, *.log
## Prueba: tests/unit_tests.gd (sección persistencia) y tests/net_session.sh (kill -KILL).

const WORLD_VERSION := 1
static var base_dir := "user://server"

var root := ""
var accounts: Dictionary = {}

func _init(world_name: String) -> void:
	root = "%s/%s" % [base_dir, world_name.validate_filename()]
	DirAccess.make_dir_recursive_absolute(root + "/players")
	accounts = read_safe(root + "/accounts.json")

# ---- cuentas: identidad estable con secreto generado en el dispositivo ---------------------------
## Devuelve "" si la identidad es válida (o nueva) o un código de rechazo de Protocol.
func authenticate(account: String, token: String, pname: String) -> String:
	var a: Variant = accounts.get(account)
	if a == null:
		var salt := Crypto.new().generate_random_bytes(12).hex_encode()
		accounts[account] = {"salt": salt, "hash": (salt + token).sha256_text(), "name": pname, "created": Time.get_unix_time_from_system(), "banned": false}
		write_atomic(root + "/accounts.json", accounts)
		return ""
	if bool(a.get("banned", false)):
		return Protocol.R_BANNED
	if (String(a.get("salt", "")) + token).sha256_text() != String(a.get("hash", "")):
		return Protocol.R_AUTH
	if String(a.get("name", "")) != pname:
		a["name"] = pname
		write_atomic(root + "/accounts.json", accounts)
	return ""

func player_path(account: String) -> String:
	return "%s/players/%s.json" % [root, account.validate_filename()]

func load_player(account: String) -> Dictionary:
	return read_safe(player_path(account))

func save_player(p: ServerPlayer) -> bool:
	return write_atomic(player_path(p.account), p.to_save())

func load_world() -> Dictionary:
	var d := read_safe(root + "/world.json")
	if d.is_empty():
		return {}
	if int(d.get("v", 0)) > WORLD_VERSION:
		push_error("world.json es de una versión más nueva (%s); se arranca sin tocarlo" % str(d.get("v")))
		return {}
	return _migrate_world(d)

func save_world(state: Dictionary) -> bool:
	state["v"] = WORLD_VERSION
	state["saved"] = Time.get_unix_time_from_system()
	return write_atomic(root + "/world.json", state)

func _migrate_world(d: Dictionary) -> Dictionary:
	# v0 -> v1: los objetos estaban en la raíz
	if int(d.get("v", 0)) < 1 and not d.has("objects"):
		d = {"objects": d, "env": {}, "social": {}, "v": 1}
	return d

func append_log(file_name: String, line: String) -> void:
	var path := root + "/" + file_name
	var f := FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()

# ---- E/S segura ---------------------------------------------------------------------------------------
static func write_atomic(path: String, data: Dictionary) -> bool:
	var body := JSON.stringify(data, "", true)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(body.sha256_text() + "\n" + body)
	f.flush()
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak1"):
			DirAccess.copy_absolute(path + ".bak1", path + ".bak2")
		DirAccess.copy_absolute(path, path + ".bak1")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("No se pudo sustituir %s (error %d)" % [path, err])
		return false
	return true

static func _parse(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var nl := text.find("\n")
	if nl != 64:
		return null
	var body := text.substr(nl + 1)
	if body.sha256_text() != text.left(64):
		return null
	var parser := JSON.new()
	if parser.parse(body) != OK or not (parser.data is Dictionary):
		return null
	return parser.data

## Lee el archivo; si está dañado recurre a .bak1/.bak2 y aparta el dañado.
static func read_safe(path: String) -> Dictionary:
	var d: Variant = _parse(path)
	if d != null:
		return d
	if FileAccess.file_exists(path):
		var aside := "%s.corrupt-%d" % [path, int(Time.get_unix_time_from_system())]
		DirAccess.copy_absolute(path, aside)
		push_warning("Archivo dañado apartado como %s; se intenta la copia de seguridad" % aside)
	for bak: String in [path + ".bak1", path + ".bak2"]:
		d = _parse(bak)
		if d != null:
			push_warning("Restaurado desde %s" % bak)
			return d
	return {}
