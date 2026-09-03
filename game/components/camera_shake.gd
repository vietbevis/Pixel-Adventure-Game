class_name CameraShake
extends Node
## Gắn làm CON của Camera2D. Rung màn hình khi có va chạm mạnh — nghe `Events`,
## cộng offset ngẫu nhiên tắt dần (mô hình "trauma" bình phương của Squirrel Eiserloh).

@export var trauma_decay: float = 1.8      ## trauma tụt về 0 nhanh cỡ nào (1/giây)
@export var max_offset: float = 7.0        ## biên độ lệch tối đa (px) khi trauma = 1

var _trauma: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO

@onready var _camera: Camera2D = get_parent() as Camera2D

func _ready() -> void:
	if _camera == null:
		push_warning("CameraShake: node cha không phải Camera2D — tắt.")
		set_process(false)
		return
	_base_offset = _camera.offset
	Events.player_damaged.connect(func(_a: int) -> void: add_trauma(0.45))
	Events.enemy_died.connect(func(_n: Node, _p: Vector2) -> void: add_trauma(0.18))
	Events.boss_phase_changed.connect(func(_p: int) -> void: add_trauma(0.7))
	Events.boss_defeated.connect(func(_id: String) -> void: add_trauma(0.9))
	Events.max_hp_increased.connect(func(_m: int) -> void: add_trauma(0.35))

func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		if _camera.offset != _base_offset:
			_camera.offset = _base_offset
		return
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	var shake := _trauma * _trauma
	_camera.offset = _base_offset + Vector2(
		max_offset * shake * randf_range(-1.0, 1.0),
		max_offset * shake * randf_range(-1.0, 1.0))
