class_name ServerEnvironment
extends RefCounted
## ServerEnvironment — hora del día y clima oficiales del servidor.
##
## Datos: día, hora (0..24), estado de clima y sus intensidades (nubes, niebla, lluvia, viento)
## con transición gradual. Se replica con S.ENV (al cambiar y periódicamente).
## Lo llaman: GameServer (tick), ServerSurvival (temperatura), criaturas (noche), colectores.

const WEATHER := {
	"despejado": {"cloud": 0.15, "fog": 0.05, "rain": 0.0, "wind": 0.25, "next": {"despejado": 3, "nublado": 4, "niebla": 2}},
	"nublado": {"cloud": 0.75, "fog": 0.12, "rain": 0.0, "wind": 0.45, "next": {"despejado": 3, "nublado": 2, "lluvia": 3, "niebla": 2}},
	"niebla": {"cloud": 0.6, "fog": 0.85, "rain": 0.0, "wind": 0.1, "next": {"despejado": 2, "nublado": 3, "niebla": 2, "lluvia": 1}},
	"lluvia": {"cloud": 0.95, "fog": 0.3, "rain": 0.6, "wind": 0.55, "next": {"nublado": 4, "lluvia": 2, "tormenta": 2, "niebla": 1}},
	"tormenta": {"cloud": 1.0, "fog": 0.35, "rain": 1.0, "wind": 1.0, "next": {"lluvia": 4, "nublado": 2}},
}

var srv: GameServer
var day := 1
var hour := 8.5
var state := "despejado"
var cloud := 0.15
var fog := 0.05
var rain := 0.0
var wind := 0.25
var wind_dir := 0.9
var _change_in := 300.0
var _send_in := 0.0
var _rng := RandomNumberGenerator.new()

func _init(server: GameServer) -> void:
	srv = server
	_rng.randomize()

func is_night() -> bool:
	return hour < 6.2 or hour > 20.6

## Factor de luz diurna 0..1.
func daylight() -> float:
	return clampf(sin((hour - 6.0) / 14.6 * PI) * 1.6, 0.0, 1.0) if hour > 6.0 and hour < 20.6 else 0.0

func tick(dt: float) -> void:
	var len: float = maxf(120.0, float(srv.options.get("day_length", 2400.0)))
	hour += dt * 24.0 / len
	if hour >= 24.0:
		hour -= 24.0
		day += 1
	var w: Dictionary = WEATHER[state]
	var k := clampf(dt / 75.0, 0.0, 1.0)
	cloud = lerpf(cloud, float(w.cloud), k)
	fog = lerpf(fog, float(w.fog), k)
	rain = lerpf(rain, float(w.rain), k)
	wind = lerpf(wind, float(w.wind), k)
	_change_in -= dt
	if _change_in <= 0.0:
		_change_in = _rng.randf_range(240.0, 600.0)
		var nxt: Dictionary = w.next
		var total := 0.0
		for n: String in nxt.keys():
			total += float(nxt[n])
		var r := _rng.randf() * total
		for n: String in nxt.keys():
			r -= float(nxt[n])
			if r <= 0.0:
				set_weather(n)
				break
	_send_in -= dt
	if _send_in <= 0.0:
		_send_in = 6.0
		srv.broadcast(Protocol.S.ENV, packet())

func set_weather(name: String) -> void:
	if WEATHER.has(name) and name != state:
		state = name
		wind_dir = fposmod(wind_dir + _rng.randf_range(-0.8, 0.8), TAU)
		_send_in = 0.0

func packet() -> Dictionary:
	return {"day": day, "hour": snappedf(hour, 0.001), "len": float(srv.options.get("day_length", 2400.0)), "w": state, "cloud": snappedf(cloud, 0.01),
		"fog": snappedf(fog, 0.01), "rain": snappedf(rain, 0.01), "wind": snappedf(wind, 0.01), "dir": snappedf(wind_dir, 0.01)}

## Temperatura ambiente en °C en un punto del valle.
func ambient(pos: Vector3) -> float:
	var t := 12.5 + 7.0 * sin((hour - 9.0) / 24.0 * TAU)
	match srv.world.region_name(pos.x, pos.z):
		"robledal": t -= 1.0
		"marjal", "bruma": t -= 2.0
		"alto": t -= 1.5
		"sotoalto", "fragua": t += 0.5
	t -= maxf(0.0, pos.y - 20.0) * 0.06
	t -= rain * 4.0 + fog * 1.5 + cloud * 1.0
	return t

func save_state() -> Dictionary:
	return {"day": day, "hour": hour, "state": state, "cloud": cloud, "fog": fog, "rain": rain, "wind": wind}

func load_state(d: Dictionary) -> void:
	day = maxi(1, int(d.get("day", 1)))
	hour = clampf(float(d.get("hour", 8.5)), 0.0, 23.99)
	if WEATHER.has(String(d.get("state", ""))):
		state = String(d.state)
	cloud = clampf(float(d.get("cloud", 0.15)), 0.0, 1.0)
	fog = clampf(float(d.get("fog", 0.05)), 0.0, 1.0)
	rain = clampf(float(d.get("rain", 0.0)), 0.0, 1.0)
	wind = clampf(float(d.get("wind", 0.25)), 0.0, 1.0)
