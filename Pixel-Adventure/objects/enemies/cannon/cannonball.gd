extends Area2D

@export var speed: float = 120.0
@export var direction: Vector2 = Vector2.LEFT
@export var max_range: float = 320.0

var _distance_traveled: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# cannonball.png là khung 44x28 dùng chung với sprite pháo, quả đạn nằm lệch
	# (+7, +5) so với tâm khung — Sprite2D.offset trong scene bù lại để quả đạn nằm
	# đúng gốc node (khớp CollisionShape2D + điểm đầu nòng). Không xoay node, không
	# flip_h: cả hai đều lật theo khung 44x28 → đảo offset → đạn lại lệch. Đạn tròn
	# nên không cần quay theo hướng bắn.

func _physics_process(delta: float) -> void:
	var step: Vector2 = direction * speed * delta
	position += step
	_distance_traveled += step.length()
	
	if _distance_traveled >= max_range:
		queue_free()

func _on_body_entered(_body: Node2D) -> void:
	queue_free()
