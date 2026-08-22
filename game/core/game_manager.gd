extends Node
## Autoload: holds state that must survive scene changes
## (chosen character, score, checkpoint/respawn position, last result, số tim/máu).

## Số tim tối đa của player (đổi thành 5 nếu muốn dễ hơn)
const MAX_HEARTS := 3

var selected_character: String = "Ninja Frog"
var score: int = 0
var last_result: String = ""  # "win" or "lose"
var respawn_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
## Số tim hiện tại của player, hết tim mới thực sự tính là "chết"
var hearts: int = MAX_HEARTS

## Call when starting a brand new attempt (from Character Select).
func start_new_run() -> void:
	score = 0
	last_result = ""
	has_checkpoint = false
	respawn_position = Vector2.ZERO
	hearts = MAX_HEARTS

## Lưu vị trí checkpoint và bung lại đầy tim (checkpoint đóng vai trò "hồi máu")
func set_checkpoint(world_position: Vector2) -> void:
	has_checkpoint = true
	respawn_position = world_position
	hearts = MAX_HEARTS
