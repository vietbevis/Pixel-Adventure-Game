extends "res://tools/level_builder/level_kit.gd"
## LÀNG — trại tị nạn của Đức Vua. Đi bộ ngang: 3 cổng thế giới xen giữa nhà cửa, 3 NPC
## có AI (Cố vấn Cua đứng gác chỉ cổng mục tiêu, Dân làng Sao Biển đi tuần + bám theo,
## Cá Mập đào ngũ bỏ chạy khi bị doạ), bia truyền thuyết và biển chọn màn. Không quái, không cờ.
## Cổng + NPC chung nhóm "Village": Cố vấn tìm cổng mục tiêu trong các node anh em.

const V := "res://shared/props/village/"
const F := "res://shared/props/forest/"
## NPC dùng bộ Crusty Crew (Treasure Hunters) — không trùng người chơi hay quái nào.
const NPC := "res://objects/npc/sprites/"

func define() -> void:
	id = "hub"
	world = "forest"
	script_path = "res://levels/hub/hub.gd"
	root_name = "Hub"
	needs_goal = false
	extrude = 6
	legend = {
		"A": {"type": "npc", "name": "Advisor", "speaker": "Cố vấn", "report_abilities": true, "dynamic_line": 1, "behavior": 0,
			"idle_frames": NPC + "crabby/crabby_frames.tres",
			"line_1": "Mừng ngài trở về, thưa Đức Vua. Trại nhỏ này là tất cả những gì còn lại.",
			"line_2": "Trước mặt là ba cánh cổng. Ngài cứ hỏi, ta sẽ nói cổng nào đang chờ ngài."},
		"V": {"type": "npc", "name": "Villager", "speaker": "Dân làng", "dynamic_line": 2, "behavior": 1,
			"wander_range": 60.0, "walk_speed": 24.0, "idle_frames": NPC + "pink_star/pink_star_frames.tres",
			"line_1": "Bọn Heo tràn qua trong một đêm. Nhà cửa, mùa màng... cháy sạch.",
			"line_2": "Ngài đi rồi bọn tôi mới hiểu: không có Vua, tường thành cũng chỉ là đá."},
		"D": {"type": "npc", "name": "Deserter", "speaker": "Cá Mập đào ngũ", "dynamic_line": 3, "behavior": 2,
			"flee_radius": 72.0, "calm_time": 1.2, "walk_speed": 22.0,
			"idle_frames": NPC + "fierce_tooth/fierce_tooth_frames.tres",
			"line_1": "Suỵt! Đừng hét. Tôi bỏ đám lính đánh thuê của Vua Heo rồi, thề đấy.",
			"line_2": "Lão ta phát bom cho cả lũ rồi bắt xông lên trước. Điên hết cả."},
		"1": {"type": "portal", "name": "ForestPortal", "world_id": "forest"},
		"2": {"type": "portal", "name": "CastlePortal", "world_id": "castle"},
		"3": {"type": "portal", "name": "DungeonPortal", "world_id": "dungeon"},
		"L": {"type": "sign", "name": "LoreSign", "speaker": "Bia gỗ",
			"line_1": "« Vương Ấn từng khắc trên Vương Miện, giữ cho ngai vàng bất khả xâm phạm. »",
			"line_2": "« Ấn vỡ làm ba mảnh trong đêm thất thủ, thất lạc giữa Rừng. »"},
		"M": {"type": "hub_sign", "name": "LevelsSign"},
		"h": {"type": "prop:" + V + "tree_house.png"},
		"s": {"type": "prop:" + V + "straw_house.png"},
		"k": {"type": "prop:" + V + "wooden_house.png"},
		"m": {"type": "prop:" + V + "plant_house.png"},
		"n": {"type": "prop:" + V + "house.png"},
	}
	var G := "##########################################################################"
	chunks = [[
		"",
		"...S.A...h......1.....s.V......2.......k...D..3.....L....m......M..n..l..q",
		G, G, G, G,
	]]
