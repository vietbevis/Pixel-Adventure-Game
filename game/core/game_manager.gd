extends Node
## Autoload: holds state that must survive scene changes
## (chosen character, score, checkpoint/respawn position, last result, số tim/máu).

## Số tim tối đa của player. Đổi số này thì cũng phải thêm/bớt node icon Heart
## trong ui/hud/hud.tscn (HeartsRow) cho khớp — HUD không tự sinh icon bằng code.
const MAX_HEARTS := 3

var selected_character: String = "King"
## id của màn đang chơi/vừa chơi (xem core/levels.gd), dùng để lưu điểm cao nhất
## và trạng thái đã hoàn thành đúng màn đó.
var current_level_id: String = "level_1"
var score: int = 0
var last_result: String = ""  # "win" or "lose"
var respawn_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
## Mirror số tim của player. Từ Phase 1 nguồn thật là HealthComponent trên player;
## biến này được player cập nhật lại qua signal để HUD và code cũ chưa chuyển vẫn đọc
## được. `set_checkpoint` cũng set để khớp. Sẽ dọn ở Phase 6.
var hearts: int = MAX_HEARTS
## Tổng thời gian (giây) đã chơi trong lượt hiện tại, dùng để tính best time.
## Cộng dồn bằng delta thay vì đồng hồ hệ thống để lúc Pause không bị tính giờ oan.
var _elapsed: float = 0.0

## Call when starting a brand new attempt (from Level Select).
func start_new_run(level_id: String = current_level_id) -> void:
	current_level_id = level_id
	score = 0
	last_result = ""
	has_checkpoint = false
	respawn_position = Vector2.ZERO
	hearts = MAX_HEARTS
	_elapsed = 0.0

func _process(delta: float) -> void:
	if not get_tree().paused:
		_elapsed += delta

## Thời gian (giây) đã trôi qua kể từ khi bắt đầu lượt chơi hiện tại.
func elapsed_time() -> float:
	return _elapsed

## Lưu vị trí checkpoint và bung lại đầy tim (checkpoint đóng vai trò "hồi máu")
func set_checkpoint(world_position: Vector2) -> void:
	has_checkpoint = true
	respawn_position = world_position
	hearts = MAX_HEARTS
