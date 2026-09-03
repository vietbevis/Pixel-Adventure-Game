@tool
extends Area2D
## Collectible fruit dùng chung 1 scene cho mọi loại quả. Mặc định hiện Táo
## (bake sẵn trong fruit.tscn); nơi đặt quả khác loại (level, object khác...)
## chỉ cần set `variant_frames` trên node instance đó (Inspector, hoặc property
## trong .tscn). @tool + setter bên dưới để đổi hình NGAY trong editor luôn,
## không phải bấm Play mới thấy đúng loại quả.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Đổi loại quả (Apple/Bananas/Cherries/...) — set file trong objects/fruit/sprites/.
## Để trống thì giữ nguyên hình mặc định đã bake sẵn trong fruit.tscn (Táo).
@export var variant_frames: SpriteFrames:
	set(value):
		variant_frames = value
		_apply_variant_frames()

var collected: bool = false

func _ready() -> void:
	_apply_variant_frames()
	if Engine.is_editor_hint():
		return
	sprite.play("idle")
	body_entered.connect(_on_body_entered)

func _apply_variant_frames() -> void:
	# get_node_or_null vì setter có thể chạy trước khi @onready var sprite
	# được gán (lúc editor nạp property từ scene, trước NOTIFICATION_READY).
	var s: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	if s and variant_frames:
		s.sprite_frames = variant_frames

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	GameManager.score += 1
	Events.fruit_collected.emit(GameManager.score)
	AudioManager.play_sfx("pickup")
	collision.set_deferred("disabled", true)
	# Hiệu ứng "collect" (phóng to + mờ dần) được dựng bằng AnimationPlayer trong
	# fruit.tscn (Godot editor), script chỉ phát rồi xoá node khi chạy xong.
	animation_player.animation_finished.connect(func(_name: StringName) -> void: queue_free())
	animation_player.play("collect")
