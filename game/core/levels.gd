class_name LevelData
extends RefCounted
## Danh sách các màn chơi, xếp ĐÚNG thứ tự chơi thực tế (khớp WorldData.WORLDS: hết
## Forest — gồm cả boss — mới tới Cave). Chuỗi mở khoá tuyến tính của SaveManager
## (`is_level_unlocked` gate màn N vào màn N-1) dựa vào thứ tự này, nên phải khớp world.
## Thêm màn mới: thêm 1 dòng vào LEVELS (sau khi tạo scene) + cập nhật WorldData.WORLDS.

const LEVELS: Array[Dictionary] = [
	{"id": "level_1", "name": "Rừng 1 · Bìa Rừng", "scene": "res://levels/level_1/level_1.tscn"},
	{"id": "level_2", "name": "Rừng 2 · Tán Cây & Tiền Đồn", "scene": "res://levels/level_2/level_2.tscn"},
	{"id": "level_3", "name": "Lâu Đài 1 · Tường Thành", "scene": "res://levels/level_3/level_3.tscn"},
	{"id": "level_4", "name": "Lâu Đài 2 · Hành Lang Ngai", "scene": "res://levels/level_4/level_4.tscn"},
	{"id": "boss_forest", "name": "Trùm · Vua Heo", "scene": "res://levels/boss_forest/boss_forest.tscn"},
	{"id": "level_5", "name": "Hầm Ngục 1 · Lối Xuống", "scene": "res://levels/level_5/level_5.tscn"},
	{"id": "level_6", "name": "Hầm Ngục 2 · Hầm Vàng", "scene": "res://levels/level_6/level_6.tscn"},
]

static func get_index(level_id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == level_id:
			return i
	return -1

static func get_scene_path(level_id: String) -> String:
	var idx := get_index(level_id)
	return LEVELS[idx]["scene"] if idx != -1 else ""

## Định dạng số giây thành "m:ss" để hiện trên HUD/End Screen/Level Select.
static func format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]
