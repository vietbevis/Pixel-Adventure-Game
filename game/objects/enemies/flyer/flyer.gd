extends Area2D
## Quái bay tuần tra ngang, hơi nhấp nhô lên xuống — art từ bộ Kenney Abstract
## Platformer (CC0). Khác các quái mặt đất: bay tự do trong không trung nên
## có thể chặn cả đường bay của người chơi giữa các bệ.

@export var patrol_distance: Vector2 = Vector2(90, 0)
@export var patrol_speed: float = 45.0
## Biên độ nhấp nhô lên xuống trong lúc bay (px).
@export var bob_amount: float = 8.0
@export var bob_speed: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _start: Vector2
var _end: Vector2
var _moving_forward: bool = true
var _time: float = 0.0

func _ready() -> void:
	_start = position
	_end = position + patrol_distance
	sprite.play("fly")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	if patrol_distance != Vector2.ZERO:
		var target := _end if _moving_forward else _start
		position.x = move_toward(position.x, target.x, patrol_speed * delta)
		sprite.flip_h = target.x < position.x
		if abs(position.x - target.x) < 0.5:
			_moving_forward = not _moving_forward
	position.y = _start.y + sin(_time * bob_speed) * bob_amount

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("hit"):
		body.hit()
