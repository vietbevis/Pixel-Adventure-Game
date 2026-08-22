extends Area2D
## Collectible fruit. Visuals (sprite frames) are baked per fruit type in
## the editor — see fruit_apple.tscn, fruit_bananas.tscn, etc., which
## inherit this base scene and only override AnimatedSprite2D.sprite_frames.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var collected: bool = false

func _ready() -> void:
	sprite.play("idle")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	GameManager.score += 1
	collision.set_deferred("disabled", true)
	queue_free()
