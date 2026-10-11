# card_follow_camera.gd
# Child Camera2D of ProceduralFishCard. Keeps the fish centred in a card's
# SubViewport while it swims, so the card works like a portrait.
extends Camera2D

## How quickly the camera catches up with the fish (higher = snappier).
## 0 = locked exactly, so every card frames its fish in the same spot.
@export var follow_smoothing: float = 0.0

@onready var _fish: Node2D = get_parent()

var _snapped := false


func _process(delta: float) -> void:
	var body: Line2D = _fish.get_node("FishBody")
	var n := body.get_point_count()
	if n == 0:
		return

	# Centre on the middle of the body rather than the head, so turns look
	# like the fish pivoting in place instead of the whole frame lurching.
	var center := Vector2.ZERO
	for i in n:
		center += body.get_point_position(i)
	center /= n

	if not _snapped or follow_smoothing <= 0.0:
		position = center
		_snapped = true
	else:
		position = position.lerp(center, 1.0 - exp(-follow_smoothing * delta))
