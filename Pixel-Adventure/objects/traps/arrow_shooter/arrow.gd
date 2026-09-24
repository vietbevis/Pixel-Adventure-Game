extends Area2D

@export var speed: float = 160.0
@export var direction: Vector2 = Vector2.LEFT
@export var max_range: float = 240.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _distance_traveled: float = 0.0
var _is_hit: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)
	
	# The default arrow sprite faces LEFT.
	# Vector2.LEFT.angle() is PI. We subtract PI so that Vector2.LEFT gives 0 rotation.
	# Vector2.RIGHT.angle() is 0. Subtracting PI gives -PI (180 degrees), making it face right.
	rotation = direction.angle() - PI

func _physics_process(delta: float) -> void:
	if _is_hit:
		return
		
	var step: Vector2 = direction * speed * delta
	position += step
	_distance_traveled += step.length()
	
	if _distance_traveled >= max_range:
		queue_free()

func _on_body_entered(_body: Node2D) -> void:
	if _is_hit:
		return
		
	_is_hit = true
	sprite.play("hit")
	# Mũi tên đã cắm tường: tắt hitbox (layer 0) để player đi qua không dính đòn.
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)

func _on_animation_finished() -> void:
	if sprite.animation == "hit":
		queue_free()
