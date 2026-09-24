extends StaticBody2D
## Tường nứt: chắn đường như đất thường, chỉ vỡ khi player LƯỚT (Dash) vào. Đây là cổng
## "phải có Dash" thật sự — khác AbilityGate (chỉ biến mất khi đã mở khoá), vì người chơi
## phải DÙNG kỹ năng. Vỡ một lần là xong trong lượt chơi đó (vào lại màn thì lành lại).
## Gốc = giữa đáy tường; cao `cells` ô 16px (collider + các khối sprite dựng sẵn trong scene).

const PART_TOP := preload("res://objects/dash_wall/sprites/part_top.png")
const PART_BOTTOM := preload("res://objects/dash_wall/sprites/part_bottom.png")

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _detector: Area2D = $Detector
@onready var _blocks: Node2D = $Blocks

var _broken: bool = false

func _physics_process(_delta: float) -> void:
	if _broken:
		return
	for body in _detector.get_overlapping_bodies():
		if body.is_in_group("player") and body.get("is_dashing"):
			_break(signf(body.global_position.x - global_position.x))
			return

func _break(from_side: float) -> void:
	_broken = true
	_shape.set_deferred("disabled", true)
	Events.camera_shake_requested.emit(0.3)
	AudioManager.play_sfx("attack")
	var dir := -from_side if from_side != 0.0 else 1.0
	for block: Node2D in _blocks.get_children():
		for i in 2:
			var piece := Sprite2D.new()
			piece.texture = PART_TOP if i == 0 else PART_BOTTOM
			piece.scale = block.scale
			get_parent().add_child(piece)
			piece.global_position = block.global_position + Vector2(0, -4 if i == 0 else 4)
			var target := piece.position + Vector2(dir * randf_range(20, 46), randf_range(-26, 10))
			var tw := piece.create_tween().set_parallel()
			tw.tween_property(piece, "position", target, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(piece, "rotation", dir * randf_range(1.5, 4.0), 0.45)
			tw.tween_property(piece, "modulate:a", 0.0, 0.45).set_delay(0.15)
			tw.chain().tween_callback(piece.queue_free)
	_blocks.visible = false
