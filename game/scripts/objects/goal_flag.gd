extends Area2D
## End-of-level goal. Touching it triggers the player's win state.

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered or not body.is_in_group("player"):
		return
	if body.has_method("win"):
		triggered = true
		body.win()
