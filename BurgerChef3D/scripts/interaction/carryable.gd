class_name Carryable
extends Interactable
## Objeto que el jugador puede recoger, transportar y colocar en una estación (ingredientes y hamburguesas).

var station: Station = null

func display_name() -> String:
	return ""

## Escala con la que se lleva en la mano (los objetos grandes, como la bandeja sucia, la reducen).
func carry_scale() -> float:
	return Const.CARRY_SCALE
