extends Area2D
## Quái đi bộ tuần tra (kiểu "Goomba" cổ điển) — art từ bộ Kenney Abstract
## Platformer (CC0), khác hẳn phong cách các bẫy tĩnh (cưa/gai) trong game.
## Tự quay đầu khi đi hết quãng đường tuần tra, lật hình theo hướng đi.

@export var patrol_distance: Vector2 = Vector2(70, 0)
@export var patrol_speed: float = 30.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _start: Vector2
var _end: Vector2
var _moving_forward: bool = true

func _ready() -> void:
	_start = position
	_end = position + patrol_distance
	sprite.play("walk")

func _process(delta: float) -> void:
	if patrol_distance == Vector2.ZERO:
		return
	var target := _end if _moving_forward else _start
	position = position.move_toward(target, patrol_speed * delta)
	sprite.flip_h = target.x < position.x
	if position.distance_to(target) < 0.5:
		_moving_forward = not _moving_forward
