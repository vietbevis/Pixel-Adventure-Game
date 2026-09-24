extends "res://tools/level_builder/level_kit.gd"
## TRÙM CUỐI · CAI NGỤC — Hồn Ma Cai Ngục (trùm bay). Phòng rộng hơn phòng Vua Heo để
## đòn lao chéo có chỗ né; 3 bệ ván một chiều cho người chơi với lên chém khi nó bay cao
## và để né mưa cầu hồn. Không có cờ — thắng khi trùm tan biến (= thắng cả game).

const W := 44
const H := 26

func define() -> void:
	id = "boss_dungeon"
	world = "dungeon"
	script_path = "res://levels/boss_dungeon/boss_dungeon.gd"
	root_name = "BossDungeon"
	title = "HẦM NGỤC CỔ"
	subtitle = "Cai Ngục"
	needs_goal = false
	extrude = 4
	legend = {"Q": {"type": "boss_gate"}}
	canvas(W, H)
	rect(0, 0, W - 1, 3)
	rect(0, H - 3, W - 1, H - 1)
	back(0, 4, W - 1, H - 4)
	rect(5, 8, 11, 8, "=")
	rect(32, 8, 38, 8, "=")
	rect(18, 12, 25, 12, "=")
	text(0, 4, "Q..S.....d...........r...........d")
	at(12, 16, "l")
	at(31, 16, "l")
	at(8, 22, "u")
	at(22, 22, "u")
	at(36, 22, "u")
	put(22, 18, "ghost_warden", {"name": "GhostWarden"})

func extra_nodes(root: Node2D) -> void:
	# Vùng bay của trùm (px global): từ trong tường trái tới trong tường phải,
	# trần bay ở hàng b17, đáy = mặt sàn (đỉnh hàng b3).
	var floor_y := float((H - 1 - 3) * TILE)
	var top_y := float((H - 1 - 17) * TILE)
	var boss: Node = root.get_node("Boss/GhostWarden")
	boss.set("arena", Rect2(2 * TILE + 8, top_y, (W - 1) * TILE - 16, floor_y - top_y))
	var bar: Node = (load("res://ui/boss_health_bar/boss_health_bar.tscn") as PackedScene).instantiate()
	bar.name = "BossHealthBar"
	root.add_child(bar)
