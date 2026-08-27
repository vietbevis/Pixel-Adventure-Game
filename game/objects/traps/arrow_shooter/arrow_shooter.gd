extends Node2D

@export var fire_interval: float = 2.2
@export var direction: Vector2 = Vector2.LEFT
@export var arrow_speed: float = 160.0
@export var start_delay: float = 0.0

var _timer: float = 0.0
var _arrow_scene: PackedScene = preload("res://objects/traps/arrow_shooter/arrow.tscn")

func _ready() -> void:
	_timer = -start_delay

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= fire_interval:
		_timer -= fire_interval
		_fire_arrow()

func _fire_arrow() -> void:
	var arrow: Area2D = _arrow_scene.instantiate() as Area2D
	if not arrow:
		return
	
	arrow.set("speed", arrow_speed)
	arrow.set("direction", direction.normalized())
	
	var parent: Node = get_parent()
	if parent:
		parent.add_child(arrow)
		arrow.global_position = global_position
