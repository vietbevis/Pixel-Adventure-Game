extends Area2D

@export var speed: float = 120.0
@export var direction: Vector2 = Vector2.LEFT
@export var max_range: float = 320.0

@onready var sprite: Sprite2D = $Sprite2D

var _distance_traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Default cannonball sprite doesn't necessarily need rotation if it's a circle, 
	# but we set it just in case.
	rotation = direction.angle() - PI

func _physics_process(delta: float) -> void:
	var step: Vector2 = direction * speed * delta
	position += step
	_distance_traveled += step.length()
	
	if _distance_traveled >= max_range:
		queue_free()

func _on_body_entered(_body: Node2D) -> void:
	queue_free()
