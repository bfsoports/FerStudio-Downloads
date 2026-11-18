extends Node
## Bus global de eventos: los sistemas emiten aquí y se suscriben sin conocerse entre sí.
@warning_ignore_start("unused_signal")

# --- economía y progresión
signal coins_changed(total: int, delta: int)
signal xp_changed(level: int, xp: int, needed: int)
signal level_up(new_level: int)
signal stat_changed(stat_key: String, value: int)
signal upgrade_changed(id: String, level: int)
signal item_equipped(category: String, item_id: String)
signal mission_completed(mission_id: String)

# --- sistema / interfaz
signal toast(text: String, kind: String)
signal language_changed(lang: String)
signal settings_changed()
signal ui_scale_changed()
signal back_requested()
signal app_backgrounded()
signal pause_requested()
signal pause_changed(paused: bool)
signal held_changed(label: String)
signal prompt_changed(prompt: Dictionary)
signal recipes_opened()
signal tutorial_step_changed(step: int)

# --- turno y pedidos
signal shift_started(config: Dictionary)
signal shift_tick(time_left: float)
signal shift_ended(result: Dictionary)
signal order_created(order: RefCounted)
signal order_changed(order: RefCounted)
signal order_closed(order: RefCounted, outcome: String)

# --- cocina
signal item_picked(ingredient_id: String)
signal item_placed(ingredient_id: String, station_kind: String)
signal item_cooked(ingredient_id: String)
signal item_burnt(ingredient_id: String)
signal burger_closed(layers: Array)
signal item_discarded(ingredient_id: String)
signal tray_dirtied(point_index: int)
signal tray_washed()
signal tray_restored(point_index: int)
