extends Node
## Autoload: state THUẦN RUNTIME sống xuyên scene change (nhân vật đã chọn, id màn
## đang chơi, điểm, kết quả vừa rồi, vị trí checkpoint, thời gian chơi).
## Tiến trình lưu ra đĩa → SaveManager. Máu → HealthComponent trên player.

var selected_character: String = "King"
## id màn đang chơi/vừa chơi (xem core/levels.gd) — để lưu điểm cao/best time đúng màn.
var current_level_id: String = "level_1"
## id world đang chơi (xem core/world_data.gd) — Portal ở hub set khi vào 1 world.
var current_world: String = ""
var score: int = 0
var last_result: String = ""  # "win" or "lose"
var respawn_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
## Tổng thời gian (giây) đã chơi trong lượt hiện tại (cộng dồn delta, dừng khi Pause).
var _elapsed: float = 0.0
## Chỉ đếm giờ khi đang thực sự chơi trong 1 màn — không tính thời gian ở menu,
## hub, end_screen hay lúc fade chuyển scene. level_base bật; win/thua tắt.
var _timer_running: bool = false

## Gọi khi bắt đầu 1 lượt chơi mới (từ Level Select / Continue).
func start_new_run(level_id: String = current_level_id) -> void:
	current_level_id = level_id
	score = 0
	last_result = ""
	has_checkpoint = false
	respawn_position = Vector2.ZERO
	_elapsed = 0.0
	_timer_running = false
	SaveManager.set_last_level(level_id)

func set_timer_running(value: bool) -> void:
	_timer_running = value

func _process(delta: float) -> void:
	if _timer_running and not get_tree().paused:
		_elapsed += delta

func elapsed_time() -> float:
	return _elapsed

## Lưu vị trí checkpoint. Việc hồi đầy tim do player xử lý qua Events.checkpoint_activated.
func set_checkpoint(world_position: Vector2) -> void:
	has_checkpoint = true
	respawn_position = world_position
