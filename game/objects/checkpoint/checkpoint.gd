extends Area2D
## Mid-level checkpoint: raises its flag and updates the respawn position
## the first time the player touches it.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var activated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if activated or not body.is_in_group("player"):
		return
	activated = true
	GameManager.set_checkpoint(global_position)
	sprite.play("active")
