class_name WorldData
extends RefCounted
## Nhóm các màn thành "world" (Rừng, Lâu Đài, Hầm Ngục). Trong 1 world, thắng màn →
## vào thẳng màn kế (nút "Next Level" ở end_screen); hết world (thắng boss của world,
## hoặc màn cuối nếu world không có boss) → về hub.
## Thứ tự + điều kiện mở world nằm ở đây (single source of truth), phải khớp
## LevelData.LEVELS (chuỗi mở khoá tuyến tính của SaveManager).
##
## Điều kiện mở 1 world (cả hai đều phải thoả, "" = bỏ qua):
##   unlock_boss  — boss_id phải nằm trong SaveManager.defeated_bosses
##   unlock_level — level_id phải đã hoàn thành (SaveManager.is_level_completed)

const WORLDS: Array[Dictionary] = [
	{
		"id": "forest",
		"name": "Rừng Ranh Giới",
		"levels": ["level_1", "level_2"],
		"unlock_boss": "",
		"unlock_level": "",
	},
	{
		"id": "castle",
		"name": "Lâu Đài Thất Thủ",
		"levels": ["level_3", "level_4", "boss_forest"],
		"unlock_boss": "",
		"unlock_level": "level_2",
	},
	{
		"id": "dungeon",
		"name": "Hầm Ngục Cổ",
		"levels": ["level_5", "level_6", "boss_dungeon"],
		"unlock_boss": "forest_boss",
		"unlock_level": "",
	},
]

static func get_world(world_id: String) -> Dictionary:
	for w in WORLDS:
		if w["id"] == world_id:
			return w
	return {}

## world chứa level_id ("" nếu không thuộc world nào — vd hub).
static func world_of(level_id: String) -> String:
	for w in WORLDS:
		if level_id in w["levels"]:
			return w["id"]
	return ""

static func first_level(world_id: String) -> String:
	var w := get_world(world_id)
	return w["levels"][0] if not w.is_empty() else ""

## Màn kế tiếp trong CÙNG world; "" nếu level_id là màn cuối (boss) của world.
static func next_in_world(level_id: String) -> String:
	var w := get_world(world_of(level_id))
	if w.is_empty():
		return ""
	var levels: Array = w["levels"]
	var i := levels.find(level_id)
	return levels[i + 1] if i != -1 and i + 1 < levels.size() else ""

static func is_world_unlocked(world_id: String) -> bool:
	var w := get_world(world_id)
	if w.is_empty():
		return false
	var req_boss: String = w.get("unlock_boss", "")
	if req_boss != "" and not SaveManager.is_boss_defeated(req_boss):
		return false
	var req_level: String = w.get("unlock_level", "")
	if req_level != "" and not SaveManager.is_level_completed(req_level):
		return false
	return true
