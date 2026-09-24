class_name EnemyHitReaction
extends Node
## Phản ứng hình ảnh khi quái trúng đòn / chết. Nghe `HealthComponent` anh em.
## Gắn vào scene quái cạnh HealthComponent — KHÔNG cần sửa script quái.
##
## Chết: dừng `_process`/`_physics_process` của quái, tắt mọi CollisionShape2D
## (hết gây contact damage + hết bị đánh), phát `Events.enemy_died`, rồi mờ dần
## + tự huỷ. Nếu sprite có animation "dead" thì để nó chạy (mờ chậm hơn, không
## phóng to); không thì "pop" phóng to nhanh (quái trừu tượng chưa có anim chết).

@export var health_component: HealthComponent
## Node để nháy / phóng to khi trúng (thường là AnimatedSprite2D của quái).
@export var sprite: CanvasItem

func _ready() -> void:
	if health_component == null:
		health_component = get_parent().get_node_or_null(^"HealthComponent")
	if sprite == null:
		sprite = get_parent().get_node_or_null(^"AnimatedSprite2D")
	if health_component == null:
		push_warning("EnemyHitReaction %s: không tìm thấy HealthComponent" % get_path())
		return
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func _on_damaged(_amount: int, _source: Node) -> void:
	# Đòn chí mạng (hp đã về 0) thì để _on_died lo hiệu ứng, không flash chồng lên.
	if sprite == null or health_component.hp <= 0:
		return
	# modulate > 1 kẹp về trắng → hiệu ứng "flash" khi trúng đòn.
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.04)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.14)

func _on_died() -> void:
	var enemy := get_parent()
	enemy.set_process(false)
	enemy.set_physics_process(false)
	for shape in enemy.find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred("disabled", true)
	Events.enemy_died.emit(enemy, enemy.global_position)

	var has_dead_anim: bool = sprite is AnimatedSprite2D \
		and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("dead")
	var dur := 0.5 if has_dead_anim else 0.18

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(enemy, "modulate:a", 0.0, dur).set_delay(dur * 0.4)
	if sprite and not has_dead_anim:
		tween.tween_property(sprite, "scale", sprite.scale * 1.4, dur)
	await tween.finished
	if is_instance_valid(enemy):
		enemy.queue_free()
