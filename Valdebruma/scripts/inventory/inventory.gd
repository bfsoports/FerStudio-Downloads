class_name Inventory
extends RefCounted
## Inventory — contenedor de pilas de objetos por huecos (jugador, cofres, muebles, arcones).
##
## Responsabilidad: reglas de apilado, capacidad y transferencias ATÓMICAS (o se completa
## la operación entera o no cambia nada), de modo que no haya duplicación ni pérdida.
## Datos: slots = Array de null | {"id": String, "n": int, "d": int (usos restantes, -1 si no aplica)}.
## Lo llaman: servidor (autoridad) y cliente (solo como espejo de lo recibido).
## Persistencia: to_data()/from_data(). Prueba: tests/test_inventory.gd.

var slots: Array = []

func _init(size := 12) -> void:
	slots.resize(size)

func size() -> int:
	return slots.size()

static func make_stack(id: String, n: int, d := -2) -> Dictionary:
	if d == -2:
		d = int(GameData.item(id).get("dur", -1))
	return {"id": id, "n": n, "d": d}

func count(id: String) -> int:
	var total := 0
	for s: Variant in slots:
		if s != null and String(s.id) == id:
			total += int(s.n)
	return total

func weight() -> float:
	var w := 0.0
	for s: Variant in slots:
		if s != null:
			w += GameData.item_weight(String(s.id)) * float(s.n)
	return w

func used() -> int:
	var n := 0
	for s: Variant in slots:
		if s != null:
			n += 1
	return n

func is_empty() -> bool:
	return used() == 0

## Cuántas unidades de 'id' caben (sin modificar nada).
func room_for(id: String) -> int:
	var mx := GameData.stack_max(id)
	var room := 0
	for s: Variant in slots:
		if s == null:
			room += mx
		elif String(s.id) == id and mx > 1:
			room += mx - int(s.n)
	return room

## Añade hasta n unidades. Devuelve las que NO cupieron.
func add(id: String, n: int, d := -2) -> int:
	if n <= 0 or not GameData.has_item(id):
		return n
	var mx := GameData.stack_max(id)
	if mx > 1:
		for i in slots.size():
			var s: Variant = slots[i]
			if s != null and String(s.id) == id and int(s.n) < mx:
				var put: int = mini(n, mx - int(s.n))
				s.n = int(s.n) + put
				n -= put
				if n == 0:
					return 0
	for i in slots.size():
		if slots[i] == null:
			var put: int = mini(n, mx)
			slots[i] = make_stack(id, put, d)
			n -= put
			if n == 0:
				return 0
	return n

## Añade todo o nada.
func add_all(id: String, n: int, d := -2) -> bool:
	if room_for(id) < n:
		return false
	add(id, n, d)
	return true

## Quita n unidades solo si las hay todas.
func remove(id: String, n: int) -> bool:
	if n <= 0:
		return true
	if count(id) < n:
		return false
	for i in range(slots.size() - 1, -1, -1):
		var s: Variant = slots[i]
		if s != null and String(s.id) == id:
			var take: int = mini(n, int(s.n))
			s.n = int(s.n) - take
			n -= take
			if int(s.n) <= 0:
				slots[i] = null
			if n == 0:
				break
	return true

## ¿Están todos los ingredientes? need = {id: cantidad}
func has_all(need: Dictionary) -> bool:
	for id: String in need.keys():
		if count(id) < int(need[id]):
			return false
	return true

func remove_all(need: Dictionary) -> bool:
	if not has_all(need):
		return false
	for id: String in need.keys():
		remove(id, int(need[id]))
	return true

func get_slot(i: int) -> Variant:
	if i < 0 or i >= slots.size():
		return null
	return slots[i]

## Mueve n unidades del hueco i de src al hueco j de dst (j = -1: donde quepa).
## Fusiona pilas iguales, intercambia si son distintas y n = pila completa. Atómico.
static func transfer(src: Inventory, i: int, dst: Inventory, j: int, n: int) -> bool:
	var s: Variant = src.get_slot(i)
	if s == null or n <= 0 or n > int(s.n):
		return false
	var id := String(s.id)
	var mx := GameData.stack_max(id)
	if j < 0:
		if src == dst:
			return false
		if dst.room_for(id) < n:
			return false
		dst.add(id, n, int(s.d))
		s.n = int(s.n) - n
		if int(s.n) <= 0:
			src.slots[i] = null
		return true
	if j >= dst.slots.size() or (src == dst and i == j):
		return false
	var t: Variant = dst.slots[j]
	if t == null:
		dst.slots[j] = {"id": id, "n": n, "d": int(s.d)}
		s.n = int(s.n) - n
		if int(s.n) <= 0:
			src.slots[i] = null
		return true
	if String(t.id) == id and mx > 1:
		var put: int = mini(n, mx - int(t.n))
		if put <= 0:
			return false
		t.n = int(t.n) + put
		s.n = int(s.n) - put
		if int(s.n) <= 0:
			src.slots[i] = null
		return true
	if n == int(s.n):          # intercambio de pilas completas
		dst.slots[j] = s
		src.slots[i] = t
		return true
	return false

## Divide una pila dejando n unidades en un hueco libre del mismo inventario.
func split(i: int, n: int) -> bool:
	var s: Variant = get_slot(i)
	if s == null or n <= 0 or n >= int(s.n):
		return false
	for k in slots.size():
		if slots[k] == null:
			slots[k] = {"id": String(s.id), "n": n, "d": int(s.d)}
			s.n = int(s.n) - n
			return true
	return false

## Cambia el número de huecos. Devuelve las pilas que ya no caben (para soltarlas al suelo).
func resize(new_size: int) -> Array:
	var overflow: Array = []
	if new_size < slots.size():
		for i in range(new_size, slots.size()):
			if slots[i] != null:
				overflow.append(slots[i])
		slots.resize(new_size)
		var rest: Array = []
		for st: Dictionary in overflow:
			var left := add(String(st.id), int(st.n), int(st.d))
			if left > 0:
				rest.append({"id": st.id, "n": left, "d": st.d})
		return rest
	slots.resize(new_size)
	return overflow

func to_data() -> Array:
	var out: Array = []
	for s: Variant in slots:
		out.append(null if s == null else [String(s.id), int(s.n), int(s.d)])
	return out

static func from_data(data: Variant, size_hint := 12) -> Inventory:
	var inv := Inventory.new(size_hint)
	if data is Array:
		var arr: Array = data
		if arr.size() > size_hint:
			inv.slots.resize(arr.size())
		for i in mini(arr.size(), inv.slots.size()):
			var e: Variant = arr[i]
			if e is Array and (e as Array).size() >= 2 and GameData.has_item(String(e[0])) and int(e[1]) > 0:
				inv.slots[i] = {"id": String(e[0]), "n": mini(int(e[1]), GameData.stack_max(String(e[0]))), "d": int(e[2]) if (e as Array).size() > 2 else -1}
	return inv
