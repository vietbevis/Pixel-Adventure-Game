extends "res://tools/level_builder/level_kit.gd"
## HẦM NGỤC 1 · LỐI XUỐNG — màn đi XUỐNG (ngược với Tán Cổ Thụ). Rơi thì dễ; cái khó là
## rơi đúng chỗ: đáy mỗi tầng là gai, chỉ vài chỗ đáp an toàn.
##   Z1 nghĩa địa trên mặt đất: BỘ XƯƠNG trồi lên từ mộ khi lại gần → lỗ xuống hầm
##   Z2 hành lang trần thấp: GAI RƠI từ trần khi đi qua bên dưới
##   Z3 phòng sàn gai: chạy trên VÁN SẬP, cưa quay vòng giữa phòng, HỒN MA trôi xuyên tường
##   Z4 hầm mộ (checkpoint): cưa chạy dọc sàn, bộ xương gác, TƯỜNG NỨT chắn lối xuống
##   Z5 tháp đổ: gờ so le đi xuống, cưa quay giữa các gờ, đáy gai trừ một góc an toàn
##   Z6 phòng cổng (checkpoint 2): 3 bộ xương, cờ ở cuối phòng

const W := 48
const H := 100

func define() -> void:
	id = "level_5"
	world = "dungeon"
	title = "HẦM NGỤC CỔ"
	subtitle = "Lối Xuống"
	extrude = 4
	legend = {
		"1": {"type": "sign", "speaker": "Bia mộ", "line_1": "Hầm ngục nằm ngay dưới nghĩa địa này.", "line_2": "Người chết ở đây không nằm yên đâu."},
		"2": {"type": "sign", "speaker": "Bia mộ", "line_1": "Tiếng lách cách trên trần...", "line_2": "Đi qua thật nhanh."},
		"3": {"type": "sign", "speaker": "Bia mộ", "line_1": "Hồn ma trôi xuyên tường.", "line_2": "Lúc nó mờ đi thì không chém được — đợi nó hiện rõ."},
		"4": {"type": "sign", "speaker": "Bia mộ", "line_1": "Tường nứt. LƯỚT vào để mở lối xuống."},
	}
	canvas(W, H)
	# Z1 — nghĩa địa ----------------------------------------------------------------------
	rect(0, 78, W - 1, 87)
	rect(40, 78, 42, 87, ".")          # lỗ xuống hầm
	text(2, 88, "S.1.q..j.....k.Q.....U...k...z")
	text(8, 91, "*.*.*......*.*.*")
	at(44, 88, "y")
	# Z2 — hành lang gai rơi (cao 4 ô: b74..b77) -------------------------------------------------
	rect(4, 70, W - 1, 73)
	at(38, 74, "2")
	for x in [34, 28, 22, 16]:
		put(x, 77, "falling_spike", {"fall_distance": 50.0, "reset_delay": 1.2})
	at(10, 74, "k")
	text(13, 75, "*.....*.....*")
	at(25, 77, "u")
	# Z3 — phòng sàn gai + ván sập (b52..b69) -------------------------------------------------
	rect(0, 48, 5, 51)                  # chỗ đáp an toàn
	rect(6, 48, W - 1, 51)
	text(6, 52, "..^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
	for x in [9, 14, 19, 24, 29, 34]:
		at(x, 53, "P")
	rect(38, 52, W - 1, 53)
	rect(44, 48, 46, 53, ".")           # lỗ xuống Z4
	put(22, 60, "orbit_saw", {"radius": 40.0, "angular_speed": 1.3})
	at(30, 62, "h")
	at(2, 52, "3")
	text(10, 57, "*...*...*...*...*...*")
	at(12, 66, "l")
	at(36, 66, "l")
	# Z4 — hầm mộ (b40..b44) ---------------------------------------------------------------------
	rect(0, 36, W - 1, 39)
	rect(0, 45, W - 1, 47)
	rect(44, 45, 46, 47, ".")
	rect(1, 36, 3, 39, ".")             # lỗ xuống Z5
	rect(6, 43, 10, 44)                 # trần hạ thấp quanh tường nứt
	at(8, 40, "W")
	text(40, 40, "C..n")
	put(24, 40, "saw", {"move_distance": Vector2(64, 0), "move_speed": 1.1})
	text(12, 40, "4......k.........k")
	text(14, 42, "*...*...*...*...*")
	at(35, 44, "u")
	# Z5 — tháp đổ (b16..b35) ---------------------------------------------------------------------
	rect(0, 31, 9, 31)
	rect(14, 27, 23, 27)
	rect(28, 23, 37, 23)
	rect(40, 19, 43, 19)
	put(12, 30, "orbit_saw", {"radius": 26.0, "angular_speed": 1.8})
	put(26, 26, "orbit_saw", {"radius": 26.0, "angular_speed": -1.8})
	at(20, 33, "h")
	at(40, 27, "h")
	text(2, 32, "*.*.*")
	text(16, 28, "*.*.*")
	text(30, 24, "*.*.*")
	rect(0, 12, W - 1, 15)
	text(0, 16, "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
	rect(44, 12, 46, 15, ".")           # lỗ xuống Z6
	# Z6 — phòng cổng (b4..b11) -------------------------------------------------------------------
	rect(0, 0, W - 1, 3)
	text(2, 4, "G..d....k......k......k....d....C")
	text(8, 7, "*.*.*.......*.*.*")
	at(12, 11, "u")
	at(30, 11, "u")
