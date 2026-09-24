extends StaticBody2D
## Rào metroidvania: chắn đường (layer `world`) tới khi người chơi CÓ `required_ability`.
## Mở VĨNH VIỄN (tắt collider + mờ dần visual). Kiểm lúc `_ready` và khi vừa unlock.
##
## "Có ability" = player's AbilitySystem.is_unlocked() (tôn trọng cả `dev_unlock_all`
## để test) — fallback về SaveManager nếu chưa tìm thấy player.

@export var required_ability: String = "dash"

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: CanvasItem = $Visual

func _ready() -> void:
	if _ability_available():
		_open(true)
	else:
		Events.ability_unlocked.connect(_on_ability_unlocked)

func _ability_available() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		var system := player.get_node_or_null(^"AbilitySystem")
		if system and system.has_method("is_unlocked"):
			return bool(system.call("is_unlocked", required_ability))
	return SaveManager.is_ability_unlocked(required_ability)

func _on_ability_unlocked(id: String) -> void:
	if id == required_ability:
		_open(false)

func _open(instant: bool) -> void:
	_shape.set_deferred("disabled", true)
	if instant:
		_visual.visible = false
		return
	var tween := create_tween()
	tween.tween_property(_visual, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_visual.hide)
