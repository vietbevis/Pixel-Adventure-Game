extends Area2D
## Static spikes trap. Kills the player on touch.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("hit"):
		# Gai là bẫy đứng yên: chỉ trừ 1 tim tại chỗ, không bung vị trí (force_reposition mặc định false)
		body.hit()
