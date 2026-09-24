extends Area2D
## Khối đá nghiền (Rock Head) treo sát trần: player đi vào cột bên dưới → chớp mắt báo
## hiệu → rơi thẳng xuống tới khi chạm đất → nằm đó một nhịp → kéo lên chậm. Chỉ gây
## sát thương lúc đang rơi (và ngay khoảnh khắc chạm đất), nên cách vượt là: nhử cho nó
## rơi rồi chạy qua lúc nó đang được kéo lên.
## Dừng rơi bằng raycast ngắn mỗi khung từ đáy khối — đặt ở đâu cũng khớp mặt đất
## bên dưới (`max_fall` chỉ là chốt an toàn khi bên dưới là vực).

enum St { WAIT, WARN, FALL, LANDED, RISE }

@export var detect_width: float = 40.0
@export var warn_time: float = 0.35
@export var rest_time: float = 0.9
@export var rise_speed: float = 40.0
@export var max_fall: float = 240.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

var _st: St = St.WAIT
var _top_y: float
var _floor_y: float
var _vy: float = 0.0
var _timer: float = 0.0

const HALF := 21.0  # nửa chiều cao sprite 42px

func _ready() -> void:
	_top_y = position.y
	_floor_y = _top_y + max_fall
	_shape.disabled = true
	sprite.play(&"idle")

func _physics_process(delta: float) -> void:
	match _st:
		St.WAIT:
			var p := _player()
			if p and absf(p.global_position.x - global_position.x) < detect_width \
					and p.global_position.y > global_position.y \
					and p.global_position.y < global_position.y + max_fall:
				_st = St.WARN
				_timer = warn_time
				sprite.play(&"blink")
		St.WARN:
			_timer -= delta
			if _timer <= 0.0:
				_st = St.FALL
				_vy = 60.0
				_shape.disabled = false
		St.FALL:
			_vy = minf(_vy + 1400.0 * delta, 520.0)
			var step := _vy * delta
			var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, HALF - 1.0), global_position + Vector2(0, HALF + step + 1.0), 1)
			var hit := get_world_2d().direct_space_state.intersect_ray(q)
			if hit:
				step = hit.position.y - (global_position.y + HALF)
			position.y += step
			if hit or position.y >= _top_y + max_fall:
				_floor_y = position.y
				_st = St.LANDED
				_timer = rest_time
				sprite.play(&"slam")
				var p := _player()
				if p and p.global_position.distance_to(global_position) < 220.0:
					Events.camera_shake_requested.emit(0.35)
		St.LANDED:
			_timer -= delta
			if _timer < rest_time - 0.08:
				_shape.disabled = true
			if _timer <= 0.0:
				_st = St.RISE
				sprite.play(&"idle")
		St.RISE:
			position.y -= rise_speed * delta
			if position.y <= _top_y:
				position.y = _top_y
				_st = St.WAIT

func _player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
