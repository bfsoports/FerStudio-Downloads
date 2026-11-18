class_name SpawnPoint
extends Marker3D
## Zombie spawn location. If linked to a Barricade, zombies must break through
## that window to reach the play area; otherwise they rise inside the zone.

@export var zone_id: String = "start"
var barricade: Barricade
