class_name Hitbox
extends Area2D
## Vùng GÂY sát thương (đòn đánh của player, đòn chạm của quái, bẫy).
##
## Bị động: chỉ chứa dữ liệu (damage, knockback). KHÔNG tự dò va chạm — Hurtbox
## là bên chủ động phát hiện và đọc `damage` từ đây. Xem hurtbox.gd.
##
## Mặc định tắt (CollisionShape2D.disabled = true) — bật bằng enable() trong khung
## hình tấn công (qua AnimationPlayer call track), tắt lại khi hết đòn. Với đòn
## "luôn bật" (bẫy gai, chạm quái) thì set shape không disabled sẵn trong .tscn.

## Sát thương gây ra cho HealthComponent của mục tiêu.
@export var damage: int = 1
## Lực đẩy lùi mục tiêu (px/giây). 0 = không đẩy.
@export var knockback_force: float = 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Bị động: không theo dõi ai, chỉ để Hurtbox nhìn thấy mình.
	monitoring = false
	monitorable = true

func enable() -> void:
	if _shape:
		_shape.set_deferred("disabled", false)

func disable() -> void:
	if _shape:
		_shape.set_deferred("disabled", true)
