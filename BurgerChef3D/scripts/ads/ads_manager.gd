extends Node
## Anuncios de AdMob: recompensados (revivir al perder, x2 monedas al terminar un turno, monedas gratis en el menú) e
## intersticiales (algunas veces al perder, con límites de frecuencia). Autoload «Ads».
##
## Usa el plugin «AdMob» de Poing Studios (v5, Godot 4.5+), que se instala desde la AssetLib del editor y exige exportar
## con «Use Gradle Build». Este script NO nombra ninguna clase del plugin en el código: las busca al arrancar por su
## nombre global (MobileAds, RewardedAdLoader...). Así el juego compila y funciona igual si el plugin no está instalado.
##
## Modos (backend):
## - PLUGIN: Android/iOS con el plugin instalado. Anuncios reales de AdMob (de PRUEBA mientras ads_config.json tenga
##   use_test_ids = true).
## - SIMULATED: solo en ejecuciones de depuración sin plugin (el editor, el ordenador). Muestra una ventana marcada
##   «ANUNCIO DE PRUEBA (simulado)» para probar el flujo de recompensas. Nunca aparece en una exportación de release.
## - NONE: sin anuncios (release sin plugin o anuncios desactivados): los botones de anuncio no se muestran.
##
## La configuración (IDs, frecuencias y recompensas) está en resources/data/ads_config.json.

signal rewarded_finished(placement: String, earned: bool)
signal interstitial_finished()
signal availability_changed()

enum Backend { NONE, PLUGIN, SIMULATED }

const CONFIG_PATH := "res://resources/data/ads_config.json"
const RETRY_S := 30.0                 # reintento de carga tras un fallo
const CONSENT_REQUIRED := 2           # ConsentStatus.REQUIRED de la UMP de Google
const PLUGIN_CLASSES: Array = ["RewardedAdLoader", "RewardedAdLoadCallback", "InterstitialAdLoader",
	"InterstitialAdLoadCallback", "FullScreenContentCallback", "OnUserEarnedRewardListener", "AdRequest"]

var backend: int = Backend.NONE
var cfg: Dictionary = {}
var showing: bool = false             # hay un anuncio a pantalla completa abierto (la partida no debe pausarse)

var _classes: Dictionary = {}
var _mobile_ads: Variant = null
var _started := false
var _rewarded: Variant = null
var _interstitial: Variant = null
var _loading_rewarded := false
var _loading_interstitial := false
var _retry_rewarded := 0.0
var _retry_interstitial := 0.0
var _placement := ""
var _earned := false
var _losses := 0
var _last_interstitial_ms := -10000000
var _was_muted := false
var _sim_layer: CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data: Variant = Util.load_json(CONFIG_PATH)
	cfg = data if data is Dictionary else {}
	if not bool(cfg.get("enabled", true)):
		return
	# se espera un fotograma para que los autoloads del plugin (si los añade) ya estén en el árbol
	_setup.call_deferred()

func _setup() -> void:
	if _plugin_present():
		backend = Backend.PLUGIN
		_request_consent_then_start()
	elif OS.is_debug_build() and bool(cfg.get("simulate_in_debug", true)):
		backend = Backend.SIMULATED

func _process(delta: float) -> void:
	if backend != Backend.PLUGIN or not _started:
		return
	if _retry_rewarded > 0.0:
		_retry_rewarded -= delta
		if _retry_rewarded <= 0.0:
			_load_rewarded()
	if _retry_interstitial > 0.0:
		_retry_interstitial -= delta
		if _retry_interstitial <= 0.0:
			_load_interstitial()

# ------------------------------------------------------------------ configuración
## ID del bloque de anuncios ("rewarded" o "interstitial"). Con use_test_ids (o si falta el ID propio) usa el de prueba.
func unit_id(kind: String) -> String:
	var own := str(cfg.get("%s_id" % kind, ""))
	if bool(cfg.get("use_test_ids", true)) or own == "":
		if own == "" and not bool(cfg.get("use_test_ids", true)):
			push_warning("Ads: falta %s_id en ads_config.json; se usa el ID de prueba" % kind)
		return str(cfg.get("test_%s_id" % kind, ""))
	return own

func is_test_mode() -> bool:
	return backend == Backend.SIMULATED or bool(cfg.get("use_test_ids", true))

func enabled() -> bool:
	return backend != Backend.NONE

## Hay un anuncio recompensado listo para mostrarse ahora mismo.
func rewarded_ready() -> bool:
	match backend:
		Backend.PLUGIN:
			return _rewarded != null and not showing
		Backend.SIMULATED:
			return not showing
	return false

func _cfg_int(key: String, fallback: int) -> int:
	return Util.to_int(cfg.get(key, fallback), fallback)

# ------------------------------------------------------------------ recompensas (las aplican los llamadores)
func revive_seconds() -> int:
	return _cfg_int("revive_seconds", 45)

## Monedas extra del botón «x2» de la pantalla de resultados: lo ganado en el turno, entre un mínimo y un máximo.
func double_amount(result: Dictionary) -> int:
	var earned := Util.to_int(result.get("net_income", 0)) + Util.to_int(result.get("coins_bonus", 0))
	return clampi(earned, _cfg_int("double_min_coins", 20), _cfg_int("double_max_coins", 400))

## Monedas del regalo del menú principal (crece con el nivel del chef).
func free_coins_amount() -> int:
	return _cfg_int("free_coins_base", 40) + _cfg_int("free_coins_per_level", 5) * (GameState.level - 1)

## Segundos que faltan para poder pedir otra vez las monedas gratis (0 = disponible).
func free_coins_wait() -> int:
	var cd := _cfg_int("free_coins_cooldown_min", 10) * 60
	var since := int(Time.get_unix_time_from_system()) - GameState.ad_coins_at
	return maxi(0, cd - since)

func claim_free_coins() -> int:
	var amount := free_coins_amount()
	GameState.ad_coins_at = int(Time.get_unix_time_from_system())
	EconomyManager.earn(amount, "ad_free_coins")
	SaveManager.request_save()
	return amount

# ------------------------------------------------------------------ intersticiales al perder
func register_loss() -> void:
	_losses += 1

## true si toca un intersticial: tras varias derrotas, con tiempo mínimo entre anuncios y nunca en los primeros turnos.
func interstitial_due() -> bool:
	if backend == Backend.NONE or showing:
		return false
	if GameState.stat("shifts_played") < _cfg_int("min_shifts_before_interstitial", 3):
		return false
	if _losses < _cfg_int("interstitial_every_losses", 2):
		return false
	if Time.get_ticks_msec() - _last_interstitial_ms < _cfg_int("interstitial_cooldown_s", 120) * 1000:
		return false
	return backend == Backend.SIMULATED or _interstitial != null

## Muestra el intersticial si está listo. Devuelve true si se mostró (espera a interstitial_finished).
func show_interstitial() -> bool:
	if showing:
		return false
	match backend:
		Backend.PLUGIN:
			if _interstitial == null:
				return false
			_begin_show()
			_interstitial.call("show")
		Backend.SIMULATED:
			_begin_show()
			_show_simulated(false)
		_:
			return false
	_losses = 0
	_last_interstitial_ms = Time.get_ticks_msec()
	return true

# ------------------------------------------------------------------ recompensados
## Muestra un anuncio recompensado. Siempre termina emitiendo rewarded_finished(placement, earned).
func show_rewarded(placement: String) -> void:
	if showing or not rewarded_ready():
		call_deferred("_emit_rewarded", placement, false)
		return
	_placement = placement
	_earned = false
	_begin_show()
	if backend == Backend.SIMULATED:
		_show_simulated(true)
		return
	var listener: Variant = _new("OnUserEarnedRewardListener")
	if listener == null:
		_end_show()
		call_deferred("_emit_rewarded", placement, false)
		return
	listener.set("on_user_earned_reward", _on_user_earned_reward)
	_rewarded.call("show", listener)

func _emit_rewarded(placement: String, earned: bool) -> void:
	rewarded_finished.emit(placement, earned)

func _on_user_earned_reward(_item: Variant = null) -> void:
	_earned = true

func _begin_show() -> void:
	showing = true
	_was_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)

func _end_show() -> void:
	showing = false
	AudioServer.set_bus_mute(0, _was_muted)

# ------------------------------------------------------------------ plugin de AdMob (acceso dinámico)
## Clase global del plugin por su nombre (o null si no está instalado).
func _cls(class_id: String) -> Variant:
	if _classes.has(class_id):
		return _classes[class_id]
	var found: Variant = null
	for d in ProjectSettings.get_global_class_list():
		var e: Dictionary = d
		if str(e.get("class", "")) == class_id:
			found = load(str(e.get("path", "")))
			break
	_classes[class_id] = found
	return found

func _new(class_id: String) -> Variant:
	var c: Variant = _cls(class_id)
	if c is GDScript:
		return (c as GDScript).new()
	return null

## Clase o autoload del plugin que expone métodos estáticos (MobileAds, UserMessagingPlatform).
func _static_api(api_name: String) -> Variant:
	var node := get_node_or_null("/root/" + api_name)
	if node != null:
		return node
	return _cls(api_name)

## ¿El objeto (instancia, nodo o script con funciones estáticas) tiene el método?
func _has(obj: Variant, method: String) -> bool:
	if obj == null:
		return false
	if obj is Script:
		for m in (obj as Script).get_script_method_list():
			if str((m as Dictionary).get("name", "")) == method:
				return true
		return false
	return (obj as Object).has_method(method)

func _plugin_present() -> bool:
	if not (OS.get_name() == "Android" or OS.get_name() == "iOS"):
		return false
	if _static_api("MobileAds") == null:
		return false
	for c in PLUGIN_CLASSES:
		if _cls(str(c)) == null:
			return false
	return true

## Consentimiento (UMP de Google, obligatorio para usuarios del EEE y Reino Unido): se pide si hace falta y después se
## inicializa AdMob. Si algo del flujo no existe en la versión instalada del plugin, se inicializa directamente.
func _request_consent_then_start() -> void:
	var ump: Variant = _static_api("UserMessagingPlatform")
	var params: Variant = _new("ConsentRequestParameters")
	if ump == null or params == null:
		_start_ads()
		return
	var info: Variant = (ump as Object).get("consent_information")
	if info == null or not _has(info, "update"):
		_start_ads()
		return
	info.call("update", params, _on_consent_info_updated.bind(ump, info), _on_consent_failed)

func _on_consent_info_updated(ump: Variant, info: Variant) -> void:
	var status := Util.to_int(info.call("get_consent_status"), 0) if _has(info, "get_consent_status") else 0
	var available := bool(info.call("get_is_consent_form_available")) if _has(info, "get_is_consent_form_available") else false
	if available and status == CONSENT_REQUIRED and _has(ump, "load_consent_form"):
		ump.call("load_consent_form", _on_consent_form_loaded, _on_consent_failed)
	else:
		_start_ads()

func _on_consent_form_loaded(form: Variant) -> void:
	if form != null and _has(form, "show"):
		form.call("show", _on_consent_failed)
	else:
		_start_ads()

## También se usa como «formulario cerrado»: en los dos casos se sigue con la inicialización.
func _on_consent_failed(_error: Variant = null) -> void:
	_start_ads()

func _start_ads() -> void:
	if _started:
		return
	_started = true
	_mobile_ads = _static_api("MobileAds")
	if _has(_mobile_ads, "initialize"):
		_mobile_ads.call("initialize")
	_load_rewarded()
	_load_interstitial()

func _load_rewarded() -> void:
	if _loading_rewarded or _rewarded != null:
		return
	var cb: Variant = _new("RewardedAdLoadCallback")
	var loader: Variant = _new("RewardedAdLoader")
	var req: Variant = _new("AdRequest")
	if cb == null or loader == null or req == null:
		return
	_loading_rewarded = true
	cb.set("on_ad_failed_to_load", _on_rewarded_failed)
	cb.set("on_ad_loaded", _on_rewarded_loaded)
	loader.call("load", unit_id("rewarded"), req, cb)

func _on_rewarded_loaded(ad: Variant) -> void:
	_loading_rewarded = false
	_rewarded = ad
	_attach_fullscreen(ad, "rewarded")
	availability_changed.emit()

func _on_rewarded_failed(_error: Variant = null) -> void:
	_loading_rewarded = false
	_rewarded = null
	_retry_rewarded = RETRY_S

func _load_interstitial() -> void:
	if _loading_interstitial or _interstitial != null:
		return
	var cb: Variant = _new("InterstitialAdLoadCallback")
	var loader: Variant = _new("InterstitialAdLoader")
	var req: Variant = _new("AdRequest")
	if cb == null or loader == null or req == null:
		return
	_loading_interstitial = true
	cb.set("on_ad_failed_to_load", _on_interstitial_failed)
	cb.set("on_ad_loaded", _on_interstitial_loaded)
	loader.call("load", unit_id("interstitial"), req, cb)

func _on_interstitial_loaded(ad: Variant) -> void:
	_loading_interstitial = false
	_interstitial = ad
	_attach_fullscreen(ad, "interstitial")

func _on_interstitial_failed(_error: Variant = null) -> void:
	_loading_interstitial = false
	_interstitial = null
	_retry_interstitial = RETRY_S

func _attach_fullscreen(ad: Variant, kind: String) -> void:
	var fs: Variant = _new("FullScreenContentCallback")
	if fs == null or ad == null:
		return
	fs.set("on_ad_dismissed_full_screen_content", _on_fullscreen_closed.bind(kind))
	fs.set("on_ad_failed_to_show_full_screen_content", _on_fullscreen_failed.bind(kind))
	(ad as Object).set("full_screen_content_callback", fs)

func _on_fullscreen_failed(_error: Variant, kind: String) -> void:
	_on_fullscreen_closed(kind)

## El anuncio se cerró (o no se pudo mostrar): se libera, se avisa y se carga el siguiente.
func _on_fullscreen_closed(kind: String) -> void:
	_end_show()
	if kind == "rewarded":
		_destroy(_rewarded)
		_rewarded = null
		# la recompensa puede llegar justo después del cierre: se espera un instante antes de avisar
		get_tree().create_timer(0.3, true).timeout.connect(func() -> void: rewarded_finished.emit(_placement, _earned))
		_load_rewarded()
	else:
		_destroy(_interstitial)
		_interstitial = null
		call_deferred("_emit_interstitial")
		_load_interstitial()
	availability_changed.emit()

func _destroy(ad: Variant) -> void:
	if ad != null and _has(ad, "destroy"):
		ad.call("destroy")

# ------------------------------------------------------------------ anuncio simulado (solo depuración sin plugin)
func _show_simulated(rewarded: bool) -> void:
	_sim_layer = CanvasLayer.new()
	_sim_layer.layer = 120
	_sim_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_sim_layer)
	var root := Control.new()
	root.theme = UITheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sim_layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := UIKit.card()
	panel.custom_minimum_size = Vector2(minf(620.0, UIKit.canvas_size(self).x - 40.0), 0)
	center.add_child(panel)
	var v := UIKit.vbox(12)
	panel.add_child(v)
	var title := UIKit.label(Loc.t("ads.sim_title"), "LabelHeader", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := UIKit.label(Loc.t("ads.sim_body"), "LabelMuted", 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var count := UIKit.label("3", "LabelGold", 44)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(count)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var close_btn := UIKit.icon_text_button("check" if rewarded else "close", Loc.t("ads.sim_claim") if rewarded else Loc.t("ads.sim_close"), "ButtonSuccess", UIKit.H_SMALL, 260, 30)
	close_btn.disabled = true
	close_btn.pressed.connect(_close_simulated.bind(rewarded, true))
	row.add_child(close_btn)
	if rewarded:
		var skip := UIKit.icon_text_button("close", Loc.t("ads.sim_skip"), "ButtonSecondary", UIKit.H_SMALL, 220, 30)
		skip.pressed.connect(_close_simulated.bind(true, false))
		row.add_child(skip)
	for i in [3, 2, 1]:
		count.text = str(i)
		await get_tree().create_timer(1.0, true).timeout
		if _sim_layer == null:
			return
	count.text = Loc.t("ads.sim_ready")
	close_btn.disabled = false

func _close_simulated(rewarded: bool, earned: bool) -> void:
	if _sim_layer != null:
		_sim_layer.queue_free()
		_sim_layer = null
	_end_show()
	if rewarded:
		_earned = earned
		call_deferred("_emit_rewarded", _placement, earned)
	else:
		call_deferred("_emit_interstitial")

func _emit_interstitial() -> void:
	interstitial_finished.emit()
