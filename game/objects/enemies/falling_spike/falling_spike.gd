extends Area2D
## Bẫy gai treo trần: rơi xuống khi người chơi đi vào vùng bên dưới, rồi tự
## thu lại vị trí ban đầu sau vài giây để bẫy lại. Dùng chung hình gai (spikes).

## Tốc độ rơi (px/giây), tăng dần theo trọng lực giả (gravity_accel).
@export var fall_speed: float = 260.0
@export var gravity_accel: float = 900.0
## Khoảng cách rơi tối đa tính từ vị trí treo ban đầu (px).
@export var fall_distance: float = 140.0
## Thời gian đợi trước khi bẫy tự thu về vị trí treo ban đầu, sẵn sàng rơi lại.
@export var reset_delay: float = 1.5

@onready var detect_zone: Area2D = $DetectZone

enum State { HANGING, FALLING, RESETTING }

var _state: State = State.HANGING
var _origin: Vector2
var _fall_velocity: float = 0.0

func _ready() -> void:
	_origin = position
	body_entered.connect(_on_body_entered)
	detect_zone.body_entered.connect(_on_detect_entered)

func _process(delta: float) -> void:
	match _state:
		State.FALLING:
			_fall_velocity += gravity_accel * delta
			position.y += min(_fall_velocity, fall_speed * 3.0) * delta
			if position.y - _origin.y >= fall_distance:
				position.y = _origin.y + fall_distance
				_state = State.RESETTING
				await get_tree().create_timer(reset_delay).timeout
				position = _origin
				_fall_velocity = 0.0
				_state = State.HANGING

func _on_detect_entered(body: Node2D) -> void:
	if _state == State.HANGING and body.is_in_group("player"):
		_state = State.FALLING
		_fall_velocity = fall_speed * 0.3

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("hit"):
		body.hit()
