class_name WorldData
extends RefCounted
## Nhóm các màn thành "world" (Forest, Cave...). Trong 1 world, thắng màn → vào
## thẳng màn kế (nút "Next Level" ở end_screen); hết world (thắng boss) → về hub.
## Thứ tự + điều kiện mở world nằm ở đây (single source of truth).

const WORLDS: Array[Dictionary] = [
	{
		"id": "forest",
		"name": "Forest",
		"levels": ["level_1", "level_2", "level_3", "boss_forest"],
		"unlock_boss": "",  # "" = mở sẵn
	},
	{
		"id": "cave",
		"name": "Cave",
		"levels": ["level_4", "level_5"],
		"unlock_boss": "forest_boss",
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
	var req: String = w.get("unlock_boss", "")
	return req == "" or SaveManager.is_boss_defeated(req)
