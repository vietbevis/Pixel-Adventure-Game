extends Area2D
## "Quái" gai di chuyển qua lại (hoặc lên xuống) trên một quãng đường cố định.
## Giết người chơi khi chạm vào, giống cưa/gai nhưng biết tuần tra (patrol).

## Quãng đường tuần tra tính từ vị trí đặt trong Inspector (px). Ví dụ Vector2(80, 0)
## nghĩa là đi qua lại 80px sang phải rồi quay về, theo trục ngang.
@export var patrol_distance: Vector2 = Vector2(80, 0)
## Tốc độ di chuyển (px/giây).
@export var patrol_speed: float = 40.0

var _start: Vector2
var _end: Vector2
var _moving_forward: bool = true

func _ready() -> void:
	_start = position
	_end = position + patrol_distance
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if patrol_distance == Vector2.ZERO:
		return
	var target := _end if _moving_forward else _start
	position = position.move_toward(target, patrol_speed * delta)
	if position.distance_to(target) < 0.5:
		_moving_forward = not _moving_forward

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("hit"):
		body.hit()
