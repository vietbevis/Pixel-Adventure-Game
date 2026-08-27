class_name LevelData
extends RefCounted
## Danh sách các màn chơi trong game, theo đúng thứ tự chơi.
## Thêm màn mới: thêm 1 dòng vào LEVELS (sau khi đã tạo scene level_x.tscn bằng Godot editor).

const LEVELS: Array[Dictionary] = [
	{"id": "level_1", "name": "Level 1", "scene": "res://levels/level_1/level_1.tscn"},
	{"id": "level_2", "name": "Level 2", "scene": "res://levels/level_2/level_2.tscn"},
	{"id": "level_3", "name": "Level 3", "scene": "res://levels/level_3/level_3.tscn"},
	{"id": "level_4", "name": "Level 4", "scene": "res://levels/level_4/level_4.tscn"},
	{"id": "level_5", "name": "Level 5 - Tower", "scene": "res://levels/level_5/level_5.tscn"},
	{"id": "boss_forest", "name": "Forest Boss", "scene": "res://levels/boss_forest/boss_forest.tscn"},
]

static func get_index(level_id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == level_id:
			return i
	return -1

static func get_scene_path(level_id: String) -> String:
	var idx := get_index(level_id)
	return LEVELS[idx]["scene"] if idx != -1 else ""

static func get_next_id(level_id: String) -> String:
	var idx := get_index(level_id)
	if idx == -1 or idx + 1 >= LEVELS.size():
		return ""
	return LEVELS[idx + 1]["id"]

## Định dạng số giây thành "m:ss" để hiện trên HUD/End Screen/Level Select.
static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
