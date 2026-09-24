extends Node2D

@export var chain_length: float = 64.0
@export var swing_degrees: float = 60.0
@export var swing_speed: float = 2.0
@export var phase: float = 0.0

@onready var ball: Area2D = $Ball
@onready var chain: Line2D = $Chain

var _time_passed: float = 0.0

func _ready() -> void:
	_update_position(0.0)

func _process(delta: float) -> void:
	_time_passed += delta
	_update_position(_time_passed)

func _update_position(time: float) -> void:
	var a: float = deg_to_rad(swing_degrees) * sin(time * swing_speed + phase)
	ball.position = Vector2(sin(a), cos(a)) * chain_length
	chain.set_point_position(1, ball.position)
