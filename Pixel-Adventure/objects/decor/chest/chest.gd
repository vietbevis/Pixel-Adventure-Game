extends Node2D
## Rương trang trí. `opened` = trạng thái hình (đóng / đã mở hẳn). Chưa có phần thưởng
## (để v1.2). Không va chạm.

@export var opened: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if opened:
		_sprite.play("open")
		_sprite.frame = _sprite.sprite_frames.get_frame_count("open") - 1
		_sprite.pause()
	else:
		_sprite.play("closed")
