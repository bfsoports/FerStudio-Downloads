class_name WeaponData
extends Resource
## Configurable weapon definition. Every number that affects balance lives here
## (resources/weapons/*.tres), never hard-coded in gameplay scripts.

enum Category { PISTOL, SHOTGUN, SMG, RIFLE, SNIPER, LMG }

@export var id: String = ""
@export var display_name: String = ""
@export var upgraded_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.PISTOL
@export var icon_name: String = ""
@export var model_path: String = ""

@export_group("Damage")
@export var damage: float = 30.0
@export var headshot_multiplier: float = 2.5
@export var pellets: int = 1
@export var max_range: float = 60.0
@export var falloff_start: float = 20.0
@export var min_damage_factor: float = 0.5
@export var penetration: int = 0

@export_group("Handling")
@export var fire_rate: float = 300.0        ## rounds per minute
@export var automatic: bool = false
@export var burst: int = 1
@export var mag_size: int = 8
@export var reserve_max: int = 80
@export var reload_time: float = 1.5
@export var reload_per_shell: bool = false
@export var spread_hip: float = 2.0          ## degrees
@export var spread_ads: float = 0.4
@export var spread_move_penalty: float = 1.5
@export var recoil_pitch: float = 1.2        ## degrees per shot
@export var recoil_yaw: float = 0.4
@export var recoil_recovery: float = 9.0
@export var ads_fov: float = 55.0
@export var move_speed_mult: float = 1.0
@export var switch_time: float = 0.45

@export_group("Viewmodel")
@export var view_offset: Vector3 = Vector3(0.18, -0.2, -0.38)
@export var ads_offset: Vector3 = Vector3(0.0, -0.11, -0.3)
@export var view_rotation: Vector3 = Vector3.ZERO
@export var kick_back: float = 0.05
@export var kick_up: float = 4.0

@export_group("Audio / FX")
@export var fire_sound: String = "shot_pistol"
@export var reload_sound: String = "reload_pistol"
@export var tracer_chance: float = 0.35
@export var muzzle_scale: float = 1.0

@export_group("Economy")
@export var wall_cost: int = 500
@export var ammo_cost: int = 250
@export var box_weight: float = 1.0
@export var in_box: bool = true

@export_group("Pack-a-Punch (Forja)")
@export var pap_damage_mult: float = 2.0
@export var pap_mag_mult: float = 1.5
@export var pap_reserve_mult: float = 1.5
@export var pap_fire_rate_mult: float = 1.15
@export var pap_effect: String = "incendiary"   ## incendiary | shock | explosive | piercing
@export var pap_tint: Color = Color(0.55, 1.0, 0.3)


func seconds_per_shot(upgraded: bool) -> float:
	var rpm := fire_rate * (pap_fire_rate_mult if upgraded else 1.0)
	return 60.0 / maxf(rpm, 1.0)


func get_damage(upgraded: bool) -> float:
	return damage * (pap_damage_mult if upgraded else 1.0)


func get_mag(upgraded: bool) -> int:
	return int(round(mag_size * (pap_mag_mult if upgraded else 1.0)))


func get_reserve(upgraded: bool) -> int:
	return int(round(reserve_max * (pap_reserve_mult if upgraded else 1.0)))


func title(upgraded: bool) -> String:
	return upgraded_name if upgraded else display_name
