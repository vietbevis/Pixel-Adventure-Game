extends StaticBody2D
## Rào metroidvania: chắn đường (layer `world`) tới khi người chơi mở khoá
## `required_ability`. Mở VĨNH VIỄN (tắt collider + mờ dần visual). Kiểm lúc `_ready`
## và khi vừa unlock ability. Đặt trong level ở Phase 8.

@export var required_ability: String = "dash"

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: CanvasItem = $Visual

func _ready() -> void:
	if SaveManager.is_ability_unlocked(required_ability):
		_open(true)
	else:
		Events.ability_unlocked.connect(_on_ability_unlocked)

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
