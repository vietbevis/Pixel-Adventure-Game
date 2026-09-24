extends Area2D
## Quả cầu hồn của Cai Ngục (đòn "rain"): hiện vệt đỏ trên sàn báo chỗ rơi trong
## `warn_time` giây — lúc đó chưa gây sát thương — rồi rơi thẳng xuống, chạm sàn thì tan.
## Layer enemy_hitbox: Hurtbox của player tự trừ 1 tim khi chạm.

@export var floor_y: float = 300.0
@export var warn_time: float = 0.55
@export var speed: float = 240.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _mark: Node2D = $Mark
@onready var _orb: Node2D = $Orb

var _t: float = 0.0

func _ready() -> void:
	_shape.disabled = true
	_mark.top_level = true
	_mark.global_position = Vector2(global_position.x, floor_y - 1.0)
	_orb.modulate.a = 0.35

func _physics_process(delta: float) -> void:
	_t += delta
	if _t < warn_time:
		_mark.modulate.a = 0.4 + 0.6 * absf(sin(_t * 18.0))
		return
	if _shape.disabled:
		_shape.disabled = false
		_orb.modulate.a = 1.0
	position.y += speed * delta
	if global_position.y >= floor_y - 5.0:
		set_physics_process(false)
		_shape.set_deferred("disabled", true)
		_mark.queue_free()
		var tw := create_tween().set_parallel()
		tw.tween_property(_orb, "scale", Vector2(2.2, 0.4), 0.18)
		tw.tween_property(_orb, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(queue_free)
