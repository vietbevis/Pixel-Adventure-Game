extends Area2D
## Spinning saw trap. Kills the player on touch.
## Có thể cho cưa di chuyển qua lại (chuyển động) bằng cách đặt move_distance khác 0:
## cưa sẽ dao động qua lại quanh vị trí đặt trong Inspector theo trục move_axis.

## Biên độ di chuyển (px) tính từ vị trí gốc. Vector2.ZERO = cưa đứng yên (mặc định, giữ hành vi cũ).
@export var move_distance: Vector2 = Vector2.ZERO
## Tốc độ dao động (radian/giây). Càng lớn cưa di chuyển càng nhanh.
@export var move_speed: float = 1.5

var _origin: Vector2
var _time: float = 0.0

func _ready() -> void:
	_origin = position

func _process(delta: float) -> void:
	if move_distance == Vector2.ZERO:
		return
	_time += delta
	position = _origin + move_distance * sin(_time * move_speed)
