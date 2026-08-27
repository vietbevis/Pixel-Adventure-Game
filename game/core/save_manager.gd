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
## Tuỳ chọn người dùng: touch_controls ("auto"/"on"/"off"), fullscreen (bool), volume (0..1)...
var settings: Dictionary = {}
## Danh sách id ability đã mở khoá ("dash"...). Xem core/progression.gd.
var unlocked_abilities: Array = []
## Danh sách boss_id đã hạ ("forest_boss"...).
var defeated_bosses: Array = []
## Danh sách id vật phẩm bí mật đã nhặt ("diamond_forest_1"...). Mỗi id chỉ nhặt 1 lần.
var collected_secrets: Array = []
## Số tim tối đa cộng thêm vĩnh viễn từ phần thưởng (heart container). Xem core/progression.gd.
var max_hp_bonus: int = 0
## Màn chơi gần nhất (cho nút Continue ở main menu). "" = chưa chơi lần nào.
var last_level: String = ""

func _ready() -> void:
	load_data()

func is_ability_unlocked(id: String) -> bool:
	return id in unlocked_abilities

## Bản sao danh sách ability đã mở (cho UI liệt kê — vd NPC cố vấn trong hub).
func get_unlocked_abilities() -> Array:
	return unlocked_abilities.duplicate()

func unlock_ability(id: String) -> void:
	if id in unlocked_abilities:
		return
	unlocked_abilities.append(id)
	save_data()

func is_secret_collected(id: String) -> bool:
	return id in collected_secrets

func collect_secret(id: String) -> void:
	if id == "" or id in collected_secrets:
		return
	collected_secrets.append(id)
	save_data()

func get_max_hp_bonus() -> int:
	return max_hp_bonus

func add_max_hp_bonus(amount: int) -> void:
	if amount <= 0:
		return
	max_hp_bonus += amount
	save_data()

func is_boss_defeated(id: String) -> bool:
	return id in defeated_bosses

## Đã từng thắng (chạm cờ đích) màn này chưa. Dùng cho WorldData.is_world_unlocked.
func is_level_completed(level_id: String) -> bool:
	return completed_levels.get(level_id, false)

func mark_boss_defeated(id: String) -> void:
	if id in defeated_bosses:
		return
	defeated_bosses.append(id)
	save_data()

func set_last_level(level_id: String) -> void:
	if level_id == last_level:
		return
	last_level = level_id
	save_data()

## "" nếu chưa từng chơi màn nào.
func get_continue_level() -> String:
	return last_level

## Đọc 1 tuỳ chọn (default nếu chưa từng lưu). Gameplay/UI chỉ query qua đây, không đọc file.
func get_setting(key: String, default: Variant) -> Variant:
	return settings.get(key, default)

func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_data()

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
		"settings": settings,
		"unlocked_abilities": unlocked_abilities,
		"defeated_bosses": defeated_bosses,
		"collected_secrets": collected_secrets,
		"max_hp_bonus": max_hp_bonus,
		"last_level": last_level,
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
		settings = parsed.get("settings", {})
		unlocked_abilities = parsed.get("unlocked_abilities", [])
		defeated_bosses = parsed.get("defeated_bosses", [])
		collected_secrets = parsed.get("collected_secrets", [])
		max_hp_bonus = int(parsed.get("max_hp_bonus", 0))
		last_level = parsed.get("last_level", "")
