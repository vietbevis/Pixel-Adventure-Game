extends Node2D

@export var lit: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var light: PointLight2D = $PointLight2D

func _ready() -> void:
	if lit:
		sprite.play("burn")
		light.visible = true
	else:
		sprite.play("off")
		light.visible = false
