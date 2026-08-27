extends Area2D

@export var fire_interval: float = 2.5
@export var direction: Vector2 = Vector2.LEFT
@export var ball_speed: float = 120.0
@export var start_delay: float = 0.0
@export var sprite_faces_right: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _timer: float = 0.0
var _ball_scene: PackedScene = preload("res://objects/enemies/cannon/cannonball.tscn")

func _ready() -> void:
	_timer = -start_delay
	sprite.animation_finished.connect(_on_animation_finished)
	_update_facing()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= fire_interval:
		_timer -= fire_interval
		_fire()

func _fire() -> void:
	sprite.play("shoot")

func _on_animation_finished() -> void:
	if sprite.animation == "shoot":
		_spawn_ball()
		sprite.play("idle")

func _spawn_ball() -> void:
	var ball: Area2D = _ball_scene.instantiate() as Area2D
	if not ball:
		return
	
	ball.set("speed", ball_speed)
	ball.set("direction", direction.normalized())
	
	var parent: Node = get_parent()
	if parent:
		parent.add_child(ball)
		ball.global_position = global_position

func _update_facing() -> void:
	# direction.x < 0 means facing left.
	# Kings and Pigs sprites face left by default (sprite_faces_right = false).
	# So if direction is RIGHT, we need to flip horizontally.
	var is_facing_right: bool = direction.x > 0
	if sprite_faces_right:
		sprite.flip_h = not is_facing_right
	else:
		sprite.flip_h = is_facing_right
