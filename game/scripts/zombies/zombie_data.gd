class_name ZombieData
extends Resource
## Configurable enemy archetype (resources/zombies/*.tres).

@export var id: String = ""
@export var display_name: String = ""
@export var model_path: String = ""
@export var scale: float = 1.0
@export var tint: Color = Color.WHITE
@export var emissive: Color = Color.BLACK

@export_group("Stats")
@export var base_health: float = 150.0
@export var health_per_round: float = 100.0      ## linear up to round 9
@export var health_mult_after_10: float = 1.1     ## compounding from round 10
@export var armor: float = 0.0                    ## 0..1 body damage reduction (head ignores)
@export var walk_speed: float = 1.2
@export var run_speed: float = 2.6
@export var run_from_round: int = 4
@export var sprint_chance_per_round: float = 0.07
@export var damage: float = 30.0
@export var attack_range: float = 1.3
@export var attack_cooldown: float = 1.2
@export var stagger_resist: float = 0.0
@export var attack_shockwave: bool = false
@export var is_boss: bool = false

@export_group("Body")
@export var head_height: float = 1.55
@export var radius: float = 0.35
@export var height: float = 1.75

@export_group("Rewards")
@export var points_hit: int = 10
@export var points_kill: int = 60
@export var points_headshot_bonus: int = 40

@export_group("Spawning")
@export var min_round: int = 1
@export var spawn_weight: float = 1.0
@export var spawn_weight_per_round: float = 0.0
@export var max_weight: float = 1.0
@export var max_alive: int = 99

@export_group("Animation")
@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_walk_alt: String = "walk2"
@export var anim_run: String = "run"
@export var anim_attack: String = "attack"
@export var anim_attack_alt: String = "attack2"
@export var anim_hit: String = "hit"
@export var anim_death: String = "death"
@export var anim_death_alt: String = "death2"
@export var anim_spawn: String = "rise"

@export_group("Audio")
@export var groan_sound: String = "zombie_groan"


func health_for_round(r: int) -> float:
	if r < 10:
		return base_health + health_per_round * float(r - 1)
	var h := base_health + health_per_round * 8.0
	return h * pow(health_mult_after_10, float(r - 9))


func weight_for_round(r: int) -> float:
	if r < min_round:
		return 0.0
	return minf(spawn_weight + spawn_weight_per_round * float(r - min_round), max_weight)
