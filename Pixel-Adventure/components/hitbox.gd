class_name Hitbox
extends Area2D
## Vùng GÂY sát thương (đòn đánh của player, đòn chạm của quái, bẫy).
##
## `monitorable = true` để Hurtbox địch nhìn thấy và TỰ áp sát thương (Hitbox không
## tự gọi damage). `monitoring = true` chỉ để Hitbox biết "đòn đã trúng" → phát
## `hit_landed` cho owner rung / hit-stop.
##
## Mặc định tắt (CollisionShape2D.disabled = true) — bật bằng enable() trong khung
## hình tấn công, tắt lại khi hết đòn. Đòn "luôn bật" (bẫy) thì để shape không disabled.

## Sát thương gây ra cho HealthComponent của mục tiêu.
@export var damage: int = 1
## Lực đẩy lùi mục tiêu (px/giây). 0 = không đẩy.
@export var knockback_force: float = 0.0

## Phát khi Hitbox này chạm Hurtbox địch — owner dùng cho hit-stop / screen shake.
signal hit_landed(target: Hurtbox)

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	monitorable = true
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		hit_landed.emit(area)

func enable() -> void:
	if _shape:
		_shape.set_deferred("disabled", false)

func disable() -> void:
	if _shape:
		_shape.set_deferred("disabled", true)
