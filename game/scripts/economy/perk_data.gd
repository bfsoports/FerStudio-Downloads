class_name PerkData
extends Resource
## Perk machine definition (resources/perks/*.tres). Effects are applied by
## PlayerPerks according to `id`.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var price: int = 2000
@export var icon_name: String = ""
@export var color: Color = Color.WHITE
