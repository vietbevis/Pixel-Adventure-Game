extends Node
## Autoload: lưu và đọc tiến trình chơi (màn đã hoàn thành, điểm cao nhất) ra đĩa,
## để lần mở game sau vẫn còn nhớ. File lưu tại user://save_data.json
## (Windows: %APPDATA%/Godot/app_userdata/game/, macOS: ~/Library/Application Support/Godot/app_userdata/game/).

const SAVE_PATH := "user://save_data.json"

## level_id -> true nếu đã từng thắng (chạm cờ đích) màn đó
var completed_levels: Dictionary = {}
## level_id -> số quả (điểm) cao nhất từng đạt được ở màn đó
var high_scores: Dictionary = {}
## level_id -> thời gian (giây) hoàn thành nhanh nhất từng đạt được ở màn đó
var best_times: Dictionary = {}

func _ready() -> void:
	load_data()

## Level 1 luôn mở sẵn; các màn sau chỉ mở khi đã thắng màn ngay trước đó.
func is_level_unlocked(level_id: String) -> bool:
	var idx := LevelData.get_index(level_id)
	if idx <= 0:
		return true
	var previous_id: String = LevelData.LEVELS[idx - 1]["id"]
	return completed_levels.get(previous_id, false)

func get_high_score(level_id: String) -> int:
	return high_scores.get(level_id, 0)

## -1.0 nếu màn đó chưa có thời gian hoàn thành nào được lưu.
func get_best_time(level_id: String) -> float:
	return best_times.get(level_id, -1.0)

## Gọi khi 1 lượt chơi kết thúc (thắng hoặc thua), để cập nhật & lưu tiến trình.
## `time_taken` chỉ có ý nghĩa khi won = true (bỏ qua nếu < 0).
func record_result(level_id: String, score: int, won: bool, time_taken: float = -1.0) -> void:
	if won:
		completed_levels[level_id] = true
		var best := get_best_time(level_id)
		if time_taken >= 0.0 and (best < 0.0 or time_taken < best):
			best_times[level_id] = time_taken
	if score > get_high_score(level_id):
		high_scores[level_id] = score
	save_data()

func save_data() -> void:
	var data := {
		"completed_levels": completed_levels,
		"high_scores": high_scores,
		"best_times": best_times,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		completed_levels = parsed.get("completed_levels", {})
		high_scores = parsed.get("high_scores", {})
		best_times = parsed.get("best_times", {})
