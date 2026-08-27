extends AnimatableBody2D
## Bệ đứng lên là sập: người chơi đặt chân → rung `shake_time` giây → rơi thẳng →
## biến mất → sau `reset_time` giây quay lại vị trí cũ. FSM timer-driven (không await dài).

enum State { IDLE, SHAKING, FALLING, GONE }

@export var shake_time: float = 0.5
@export var fall_accel: float = 900.0
@export var fall_limit: float = 220.0
@export var reset_time: float = 2.5

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _stand_zone: Area2D = $StandZone

var _state: State = State.IDLE
var _origin: Vector2
var _timer: float = 0.0
var _fall_v: float = 0.0

func _ready() -> void:
	_origin = position
	_sprite.play("idle")
	_stand_zone.body_entered.connect(_on_stand)

func _physics_process(delta: float) -> void:
	match _state:
		State.SHAKING:
			_timer += delta
			if _timer >= shake_time:
				_state = State.FALLING
		State.FALLING:
			_fall_v += fall_accel * delta
			position.y += _fall_v * delta
			if position.y - _origin.y >= fall_limit:
				_enter_gone()
		State.GONE:
			_timer += delta
			if _timer >= reset_time:
				_reset()

func _on_stand(body: Node2D) -> void:
	if _state == State.IDLE and body.is_in_group("player"):
		_state = State.SHAKING
		_timer = 0.0
		_sprite.play("shake")

func _enter_gone() -> void:
	_state = State.GONE
	_timer = 0.0
	visible = false
	_shape.set_deferred("disabled", true)

func _reset() -> void:
	position = _origin
	_fall_v = 0.0
	visible = true
	_shape.set_deferred("disabled", false)
	_sprite.play("idle")
	_state = State.IDLE
