extends Area2D

@export var bounce_velocity: float = -520.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	sprite.animation_finished.connect(_on_animation_finished)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var player := body as CharacterBody2D
	# Chỉ bật khi player đang đi xuống / đứng yên — không cắt ngang cú nhảy đang lên.
	if player and player.velocity.y >= -50.0:
		player.velocity.y = bounce_velocity
		sprite.play("jump")

func _on_animation_finished() -> void:
	if sprite.animation == "jump":
		sprite.play("idle")
