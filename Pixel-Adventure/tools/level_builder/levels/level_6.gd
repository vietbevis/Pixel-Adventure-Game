extends "res://tools/level_builder/level_kit.gd"
## HẦM NGỤC 2 · HẦM VÀNG — màn thường cuối cùng: gộp mọi thứ đã học, nhịp dồn dập hơn.
##   A  tiền sảnh kho vàng: bộ xương trồi lên
##   B  sảnh CHÓ NGỤC: 2 con lao húc khi thấy ngài ngang tầm → leo ván tránh, đạp đầu
##   C  hành lang cưa: cưa chạy dọc sàn và dọc trần, gai rơi, tường nứt ở cuối
##   D  hố gai (checkpoint): bệ trôi dài qua 3 chuỳ gai đung đưa lệch pha
##   E  kim tự tháp bậc LỬA: mỗi bậc một bẫy lửa lệch nhịp, 2 hồn ma lượn quanh
##   F  vực không đáy (checkpoint 2): chuỗi VÁN SẬP, 2 cưa quay giữa đường
##   G  sảnh cổng: chó ngục + bộ xương canh cửa phòng Cai Ngục → cờ

const W := 190
const H := 36

func define() -> void:
	id = "level_6"
	world = "dungeon"
	title = "HẦM NGỤC CỔ"
	subtitle = "Hầm Vàng"
	extrude = 6
	legend = {
		"1": {"type": "sign", "speaker": "Bia mộ", "line_1": "HẦM VÀNG. Vương miện của ngài bị giấu ở tận cùng.", "line_2": "Tới đây rồi thì mọi bẫy đều thật."},
		"2": {"type": "sign", "speaker": "Bia mộ", "line_1": "Chó Ngục lao như tên bắn khi thấy ngài NGANG TẦM.", "line_2": "Leo lên cao mà tránh — rồi nhảy xuống đạp đầu nó."},
		"3": {"type": "sign", "speaker": "Bia mộ", "line_1": "Sau cánh cổng: CAI NGỤC.", "line_2": "Hắn giữ vương miện. Đòi lại đi."},
	}
	canvas(W, H)
	rect(0, 0, W - 1, 3)
	rect(0, H - 3, W - 1, H - 1)
	back(0, 4, W - 1, H - 4)
	# A — tiền sảnh -------------------------------------------------------------------
	text(2, 4, "S.1..$....k.....k....d")
	text(9, 8, "*.*.*...*.*.*")
	at(12, 16, "l")
	at(8, 32, "u")
	at(20, 32, "u")
	# B — sảnh chó ngục ----------------------------------------------------------------
	at(27, 4, "2")
	text(40, 4, "H...........H")
	rect(30, 8, 35, 8, "=")
	rect(42, 8, 47, 8, "=")
	rect(36, 12, 41, 12, "=")
	rect(49, 11, 53, 11, "=")
	text(31, 9, "*.*.*")
	text(37, 13, "*.*.*")
	text(50, 12, "*.*")
	at(33, 20, "l")
	at(46, 20, "l")
	# C — hành lang cưa (b4..b9) ---------------------------------------------------------
	rect(56, 10, 85, H - 4)
	put(61, 4, "saw", {"move_distance": Vector2(40, 0), "move_speed": 1.7})
	put(70, 4, "saw", {"move_distance": Vector2(40, 0), "move_speed": 1.2})
	put(66, 9, "saw", {"move_distance": Vector2(56, 0), "move_speed": 1.4})
	for x in [77, 80]:
		put(x, 9, "falling_spike", {"fall_distance": 70.0, "reset_delay": 1.0})
	rect(83, 7, 85, 9)
	at(84, 4, "W")
	text(58, 6, "*..*..*..*..*..*..*")
	# D — hố gai, bệ trôi, chuỳ gai -----------------------------------------------------------
	text(86, 4, "C")
	rect(88, 0, 108, 3, ".")
	rect(88, 0, 108, 1)
	text(88, 2, "^^^^^^^^^^^^^^^^^^^^^")
	rect(88, 14, 108, H - 4)
	put(89, 3, "moving_platform", {"move_distance": Vector2(256, 0), "move_speed": 48.0})
	for k in 3:
		put(94 + 6 * k, 13, "spiked_ball", {"chain_length": 132.0, "swing_degrees": 50.0, "swing_speed": 1.7, "phase": 1.4 * k})
	text(91, 7, "*.....*.....*.....*")
	# E — kim tự tháp bậc lửa ---------------------------------------------------------------
	rect(111, 4, 115, 5)
	rect(116, 4, 120, 7)
	rect(121, 4, 125, 9)
	rect(126, 4, 130, 11)
	rect(134, 4, 140, 8)
	var k2 := 0
	for p in [[113, 6], [118, 8], [123, 10], [128, 12]]:
		put(p[0], p[1], "fire_trap", {"start_delay": 0.6 * k2, "off_time": 1.7, "warn_time": 0.45, "on_time": 1.2})
		k2 += 1
	at(120, 18, "h")
	at(134, 17, "h")
	text(116, 14, "*....*....*....*")
	at(138, 9, "C")
	# F — vực không đáy + ván sập ------------------------------------------------------------
	rect(141, 0, 165, 3, ".")
	for p in [[143, 8], [147, 9], [151, 10], [155, 9], [159, 8], [163, 8]]:
		at(p[0], p[1], "P")
	put(149, 14, "orbit_saw", {"radius": 30.0, "angular_speed": 1.5})
	put(158, 13, "orbit_saw", {"radius": 30.0, "angular_speed": -1.5})
	text(145, 12, "*...*...*...*...*")
	# G — sảnh cổng -------------------------------------------------------------------------
	text(167, 4, "3..k.....H.....k....G")
	at(172, 12, "l")
	at(182, 12, "l")
	at(177, 32, "u")
	at(170, 7, "t")
	at(185, 7, "t")
