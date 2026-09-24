extends Area2D

enum State { OFF, WARN, ON }

@export var off_time: float = 1.6
@export var warn_time: float = 0.5
@export var on_time: float = 1.4
@export var start_delay: float = 0.0

var _state: State = State.OFF
var _timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_timer = -start_delay
	_set_state(State.OFF)

func _process(delta: float) -> void:
	_timer += delta
	
	match _state:
		State.OFF:
			if _timer >= off_time:
				_timer -= off_time
				_set_state(State.WARN)
		State.WARN:
			if _timer >= warn_time:
				_timer -= warn_time
				_set_state(State.ON)
		State.ON:
			if _timer >= on_time:
				_timer -= on_time
				_set_state(State.OFF)

func _set_state(new_state: State) -> void:
	_state = new_state
	match _state:
		State.OFF:
			sprite.play("off")
			collision_shape.set_deferred("disabled", true)
		State.WARN:
			sprite.play("warn")
			collision_shape.set_deferred("disabled", true)
		State.ON:
			sprite.play("on")
			collision_shape.set_deferred("disabled", false)
