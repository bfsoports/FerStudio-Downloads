class_name ZombiePool
extends Node3D
## Pre-instanced zombies per archetype. Spawning never instantiates scenes
## mid-round, which avoids hitches when hordes arrive.

signal zombie_released(z: Zombie)

static var instance: ZombiePool

var _free := {}     # id -> Array[Zombie]
var _all: Array[Zombie] = []
var _types := {}    # id -> ZombieData


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func prewarm(data: ZombieData, count: int) -> void:
	_types[data.id] = data
	if not _free.has(data.id):
		_free[data.id] = []
	for i in count:
		_free[data.id].append(_make(data))


func _make(data: ZombieData) -> Zombie:
	var z := Zombie.new()
	add_child(z)
	z.setup(data)
	_all.append(z)
	return z


func acquire(id: String) -> Zombie:
	var arr: Array = _free.get(id, [])
	if arr.is_empty():
		if not _types.has(id):
			return null
		return _make(_types[id])
	return arr.pop_back()


static func release(z: Zombie) -> void:
	if instance == null:
		z.queue_free()
		return
	z.deactivate()
	instance._free[z.data.id].append(z)
	instance.zombie_released.emit(z)


func active_zombies() -> Array[Zombie]:
	var out: Array[Zombie] = []
	for z in _all:
		if z.is_active():
			out.append(z)
	return out


func alive_count(id: String = "") -> int:
	var n := 0
	for z in _all:
		if z.is_alive() and (id == "" or z.data.id == id):
			n += 1
	return n


func kill_all() -> void:
	for z in _all:
		if z.is_alive():
			z.take_hit(1e9, z.global_position + Vector3.UP, Vector3.ZERO, false, null, true)
