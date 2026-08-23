extends Area2D
## Biến thể "quái đuổi theo" (chaser) lấy cảm hứng từ các mob truy đuổi trong
## nhiều game platformer khác: đứng yên canh gác, chỉ lao theo người chơi khi
## họ lại gần, rồi tự quay về vị trí gác nếu người chơi chạy đủ xa.
## Dùng chung hình quả gai chớp mắt (spike_head), khác ở chỗ hành vi là "phục kích".

## Bán kính (px) để phát hiện người chơi và bắt đầu đuổi theo.
@export var detect_radius: float = 90.0
## Đuổi theo xa quá khoảng này (px) tính từ vị trí gác thì bỏ cuộc, quay về.
@export var leash_radius: float = 160.0
@export var chase_speed: float = 70.0
@export var return_speed: float = 50.0

enum State { IDLE, CHASING, RETURNING }

var _origin: Vector2
var _state: State = State.IDLE
var _player: Node2D = null

func _ready() -> void:
	_origin = position
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			var player := _find_player()
			if player and position.distance_to(player.global_position) <= detect_radius:
				_player = player
				_state = State.CHASING
		State.CHASING:
			if not is_instance_valid(_player) or position.distance_to(_origin) > leash_radius:
				_state = State.RETURNING
				return
			position = position.move_toward(_player.global_position, chase_speed * delta)
		State.RETURNING:
			position = position.move_toward(_origin, return_speed * delta)
			if position.distance_to(_origin) < 1.0:
				_state = State.IDLE

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("hit"):
		body.hit()
