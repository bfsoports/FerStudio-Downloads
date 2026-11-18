extends Node
## Guardado robusto en JSON: escritura atómica (archivo temporal + renombrado), copia de seguridad,
## validación al cargar, conservación de archivos corruptos y guardado diferido (nunca cada fotograma).

const SAVE_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak.json"
const TMP_PATH := "user://savegame.tmp"
const CORRUPT_PATH := "user://savegame.corrupt.json"
const AUTOSAVE_DELAY := 1.0

var last_error: String = ""
var _dirty := false
var _timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

func _process(delta: float) -> void:
	if _dirty:
		_timer += delta
		if _timer >= AUTOSAVE_DELAY:
			save_now()

## Marca los datos como modificados; se guardarán en breve (agrupa varios cambios seguidos).
func request_save() -> void:
	_dirty = true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_now() -> bool:
	_dirty = false
	_timer = 0.0
	if not GameState.initialized:
		last_error = "estado no inicializado"
		return false
	var text := JSON.stringify(GameState.to_dict(), "\t")
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		last_error = "no se pudo abrir el archivo temporal"
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if DirAccess.rename_absolute(TMP_PATH, SAVE_PATH) != OK:
		var f2 := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f2 == null:
			last_error = "no se pudo escribir la partida"
			return false
		f2.store_string(text)
		f2.close()
	last_error = ""
	return true

## Carga la partida. Devuelve true si se restauró un guardado válido; si no, deja valores por defecto seguros.
func load_game() -> bool:
	var data: Variant = _read_json(SAVE_PATH)
	if data == null and FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, CORRUPT_PATH)
		data = _read_json(BACKUP_PATH)
	if data is Dictionary and _is_valid(data):
		GameState.from_dict(_migrate(data))
		return true
	GameState.reset_to_defaults()
	return false

func reset_save() -> void:
	for p in [SAVE_PATH, BACKUP_PATH, TMP_PATH, CORRUPT_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	GameState.reset_to_defaults()
	Events.coins_changed.emit(GameState.coins, 0)

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	return JSON.parse_string(text)

func _is_valid(d: Dictionary) -> bool:
	var v := Util.to_int(d.get("version", 0))
	return v >= 1 and v <= Const.SAVE_VERSION and d.has("coins")

## Punto de migración entre versiones del formato. Todavía solo existe la versión 1.
func _migrate(d: Dictionary) -> Dictionary:
	return d
