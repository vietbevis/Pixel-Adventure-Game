class_name Bomb
extends Area2D
## Bom boss ném: bay theo cung (trọng lực riêng), cháy ngòi, rồi NỔ — bật vùng sát
## thương tròn ~0.28s rồi tự huỷ. Chỉ vụ nổ gây damage, không phải lúc đang bay.
## Area2D trên layer `enemy_hitbox` (64) — Hurtbox của player tự phát hiện.

const GRAVITY := 520.0

## Thời gian cháy ngòi trước khi nổ (giây). Boss tính vận tốc ném theo con số này.
@export var fuse_time: float = 1.0
## Bán kính vùng nổ (px).
@export var blast_radius: float = 26.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _vel: Vector2 = Vector2.ZERO
var _fuse: float = 0.0
var _exploded: bool = false

## Boss gọi ngay sau instantiate. `fuse` > 0 thì ghi đè `fuse_time` (boss tính theo
## quãng đường ném — xa thì bay lâu hơn thành cung nhẹ, gần thì snap).
func launch(velocity: Vector2, fuse: float = -1.0) -> void:
	_vel = velocity
	if fuse > 0.0:
		fuse_time = fuse
		_fuse = fuse

func _ready() -> void:
	_shape.disabled = true
	_fuse = fuse_time
	sprite.play("fuse")

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_vel.y += GRAVITY * delta
	position += _vel * delta
	rotation += _vel.x * delta * 0.015
	_fuse -= delta
	if _fuse <= 0.0:
		_explode()

func _explode() -> void:
	_exploded = true
	rotation = 0.0
	_vel = Vector2.ZERO
	(_shape.shape as CircleShape2D).radius = blast_radius
	_shape.set_deferred("disabled", false)
	sprite.play("boom")
	sprite.animation_finished.connect(queue_free)
	# Tắt vùng nổ sớm hơn khi anim kết thúc để không "nổ dài".
	await get_tree().create_timer(0.28).timeout
	if is_instance_valid(self):
		_shape.set_deferred("disabled", true)
