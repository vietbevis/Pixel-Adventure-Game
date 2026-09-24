extends "res://tools/level_builder/level_kit.gd"
## TRÙM · PHÒNG NGAI — Vua Heo (King Pig). Phòng kín vừa khung hình để thấy trọn trận.
## 3 bệ ván một chiều: 2 bệ thấp hai bên để né cú dậm sóng xung kích (jump_slam) và
## cú húc (charge), 1 bệ cao giữa để né bom. Không có cờ — thắng khi trùm gục.

const W := 40
const H := 24

func define() -> void:
	id = "boss_forest"
	world = "castle"
	script_path = "res://levels/boss_forest/boss_arena.gd"
	root_name = "BossForest"
	title = "LÂU ĐÀI THẤT THỦ"
	subtitle = "Phòng Ngai — Vua Heo"
	needs_goal = false
	extrude = 4
	legend = {
		"K": {"type": "king_pig", "name": "KingPig"},
		"Q": {"type": "boss_gate"},
	}
	canvas(W, H)
	rect(0, 0, W - 1, 3)
	rect(0, H - 3, W - 1, H - 1)
	back(0, 4, W - 1, H - 4)
	rect(6, 8, 11, 8, "=")
	rect(28, 8, 33, 8, "=")
	rect(17, 12, 22, 12, "=")
	text(0, 4, "Q..S..................n.....n.....K")
	for x in [4, 14, 25, 35]:
		at(x, 7, "t")
	at(19, 15, "l")
	at(9, 13, "j")
	at(30, 13, "j")

func extra_nodes(root: Node2D) -> void:
	var boss: Node = root.get_node("Boss/KingPig")
	boss.set("arena_bounds", Vector2(2 * TILE + 14, (W + 1) * TILE - 14))
	var bar: Node = (load("res://ui/boss_health_bar/boss_health_bar.tscn") as PackedScene).instantiate()
	bar.name = "BossHealthBar"
	root.add_child(bar)
