@tool
extends Area2D
## Vật phẩm bí mật (Diamond) — persist qua SaveManager: mỗi viên có `secret_id` duy nhất,
## nhặt 1 lần là biến mất vĩnh viễn (kể cả chơi lại màn). Thường giấu sau AbilityGate.
## Đủ trọn bộ Forest → thưởng heart container (xem core/progression.gd).

## ID duy nhất của viên này — PHẢI đặt riêng cho từng chỗ đặt (vd "diamond_forest_1").
@export var secret_id: String = ""

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

var _collected: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if SaveManager.is_secret_collected(secret_id):
		queue_free()
		return
	_sprite.play("idle")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	SaveManager.collect_secret(secret_id)
	Events.collectible_collected.emit(secret_id, "diamond")
	_collision.set_deferred("disabled", true)
	_sprite.play("hit")
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_sprite, "scale", Vector2(1.8, 1.8), 0.18)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.18)
	tween.tween_property(_sprite, "position:y", _sprite.position.y - 12.0, 0.18)
	await tween.finished
	queue_free()
