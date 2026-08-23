extends Area2D
## Biến thể của Saw: quay tròn quanh 1 tâm cố định thay vì đung đưa theo 1 trục.
## Dùng chung sprite/collision với saw.tscn, chỉ khác cách di chuyển.

## Bán kính quỹ đạo (px).
@export var radius: float = 40.0
## Tốc độ quay (radian/giây). Số âm = quay ngược chiều kim đồng hồ.
@export var angular_speed: float = 1.5

var _center: Vector2
var _angle: float = 0.0

func _ready() -> void:
	_center = position
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_angle += angular_speed * delta
	position = _center + Vector2(cos(_angle), sin(_angle)) * radius

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("hit"):
		body.hit()
