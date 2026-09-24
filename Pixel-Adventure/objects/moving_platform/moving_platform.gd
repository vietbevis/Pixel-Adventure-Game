extends AnimatableBody2D
## Bệ di chuyển: người chơi đứng lên và bị mang theo khi bệ di chuyển qua lại.
## sync_to_physics phải = true (đặt trong .tscn) để CharacterBody2D của player
## bám theo đúng, không bị trượt/giật khi bệ chuyển hướng.

## Biên độ di chuyển (px) tính từ vị trí đặt trong Inspector.
@export var move_distance: Vector2 = Vector2(96, 0)
@export var move_speed: float = 40.0
## true = bắt đầu chờ ở vị trí gốc rồi mới di chuyển (lệch pha với các bệ khác).
@export var start_delay: float = 0.0

var _origin: Vector2
var _moving_forward: bool = true
var _delay_left: float = 0.0

func _ready() -> void:
	_origin = position
	_delay_left = start_delay

func _physics_process(delta: float) -> void:
	if move_distance == Vector2.ZERO:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	var target := _origin + move_distance if _moving_forward else _origin
	position = position.move_toward(target, move_speed * delta)
	if position.distance_to(target) < 0.5:
		_moving_forward = not _moving_forward
