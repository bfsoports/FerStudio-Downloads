extends Node
## Ejecutor de pruebas automatizadas.
## Uso:  godot --headless --path . res://tests/test_runner.tscn      (o F6 desde el editor)
## Sale con código 1 si alguna prueba falla. Protege la partida real: guarda una copia del estado y la restaura al final.

const SUITES: Array = [
	"res://tests/unit/test_data.gd",
	"res://tests/unit/test_models.gd",
	"res://tests/unit/test_characters.gd",
	"res://tests/unit/test_ui.gd",
	"res://tests/unit/test_media.gd",
	"res://tests/unit/test_recipe_validator.gd",
	"res://tests/unit/test_cooking.gd",
	"res://tests/unit/test_rewards_rules.gd",
	"res://tests/unit/test_economy.gd",
	"res://tests/unit/test_missions.gd",
	"res://tests/unit/test_save.gd",
	"res://tests/unit/test_sink.gd",
	"res://tests/unit/test_tutorial.gd",
	"res://tests/unit/test_ads.gd",
	"res://tests/integration/test_delivery.gd",
]

var passed := 0
var failed := 0
var _current := ""

func _ready() -> void:
	# se ejecuta en diferido: durante _ready la raíz está ocupada y las pruebas no podrían añadir nodos al árbol
	_run_all.call_deferred()

func _run_all() -> void:
	SaveManager.set_process(false)
	var backup := GameState.to_dict()
	for path in SUITES:
		var script := load(path) as GDScript
		if script == null:
			failed += 1
			print("FALLO: no se pudo cargar ", path)
			continue
		_current = String(path).get_file()
		var suite: Object = script.new()
		suite.run(self)
	GameState.from_dict(backup)
	SaveManager._dirty = false
	SaveManager.set_process(true)
	print("\nResultado: %d correctas, %d fallidas" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("FALLO [%s]: %s" % [_current, what])

func eq(a: Variant, b: Variant, what: String) -> void:
	ok(a == b, "%s (esperado %s, obtenido %s)" % [what, str(b), str(a)])
