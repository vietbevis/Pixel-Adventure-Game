extends "res://tools/level_builder/level_kit.gd"
## LÂU ĐÀI 2 · HÀNH LANG NGAI — toàn bộ trong nhà, màn khó nhất trước trùm đầu tiên.
## Mỗi phòng là một "câu đố thời điểm" khác nhau:
##   A  đại sảnh: 2 Heo — bài kiểm tra chiến đấu thật sự đầu tiên
##   B  hành lang LỬA trần thấp (không nhảy qua lửa được): 7 bẫy tắt lần lượt theo
##      sóng, chạy bám sát đuôi sóng là qua
##   C  hố gai: 2 bệ trôi nối nhau, cưa quay vòng ngay chỗ đổi bệ → checkpoint
##   D  phòng pháo: pháo trên bậc cao + pháo sát sàn bắn lệch nhịp, heo phục kích;
##      đường vòng trên cao lấy trái cây
##   E  hành lang 4 CHUỲ GAI đung đưa lệch pha (lướt qua khe hở) → checkpoint 2
##   F  2 heo ném bom trên gờ canh cửa phòng ngai → cờ (sang trận Vua Heo)

const W := 170
const H := 34

func define() -> void:
	id = "level_4"
	world = "castle"
	title = "LÂU ĐÀI THẤT THỦ"
	subtitle = "Hành Lang Ngai"
	extrude = 6
	legend = {
		"1": {"type": "sign", "speaker": "Khắc trên đá", "line_1": "HÀNH LANG NGAI. Vua Heo ngồi ở cuối dãy phòng này.", "line_2": "Mỗi phòng một cái bẫy — quan sát nhịp trước khi lao vào."},
		"2": {"type": "sign", "speaker": "Khắc trên đá", "line_1": "Trần thấp, không nhảy qua lửa được.", "line_2": "Lửa tắt dần theo từng đợt — chạy bám theo đợt tắt."},
		"3": {"type": "sign", "speaker": "Khắc trên đá", "line_1": "Phía sau cánh cửa này: VUA HEO.", "line_2": "Hít một hơi thật sâu."},
	}
	canvas(W, H)
	rect(0, 0, W - 1, 3)                 # sàn
	rect(0, H - 3, W - 1, H - 1)         # trần
	# A — đại sảnh -------------------------------------------------------------------
	text(2, 4, "S.1....r.....p.......p")
	text(8, 9, "*.*.*...*.*.*")
	at(12, 12, "j")
	at(20, 14, "l")
	at(6, 12, "u")
	at(9, 7, "t")
	at(23, 7, "t")
	# B — hành lang lửa trần thấp (sàn b3, cao 3 ô) --------------------------------------------
	rect(31, 7, 60, H - 4)
	at(32, 4, "2")
	for k in 7:
		put(35 + 4 * k, 4, "fire_trap", {"start_delay": 0.4 * k, "off_time": 1.8, "warn_time": 0.45, "on_time": 1.3})
	text(37, 5, "*...*...*...*...*...*")
	# C — hố gai + 2 bệ trôi + cưa quay ---------------------------------------------------------
	rect(63, 0, 81, 3, ".")
	rect(63, 0, 81, 1)
	text(63, 2, "^^^^^^^^^^^^^^^^^^^")
	put(64, 3, "moving_platform", {"move_distance": Vector2(112, 0), "move_speed": 44.0})
	put(74, 6, "moving_platform", {"move_distance": Vector2(96, 0), "move_speed": 44.0, "start_delay": 1.2})
	put(73, 10, "orbit_saw", {"radius": 36.0, "angular_speed": 1.6})
	text(66, 9, "*.*.*")
	text(76, 11, "*.*")
	text(84, 4, "C")
	at(88, 12, "y")
	at(68, 18, "l")
	# D — phòng pháo -------------------------------------------------------------------------
	rect(114, 4, 120, 6)
	put(118, 7, "cannon", {"fire_interval": 2.6, "ball_speed": 130.0})
	put(111, 4, "cannon", {"fire_interval": 2.6, "ball_speed": 120.0, "start_delay": 1.3})
	text(94, 4, "a.......a")
	rect(92, 9, 97, 9)
	rect(101, 12, 106, 12)
	text(93, 10, "*.*.*")
	text(102, 13, "*.*.*")
	at(99, 16, "u")
	at(90, 7, "t")
	# E — hành lang chuỳ gai -----------------------------------------------------------------
	rect(121, 14, 150, H - 4)
	for k in 4:
		put(125 + 6 * k, 13, "spiked_ball", {"chain_length": 138.0, "swing_degrees": 55.0, "swing_speed": 1.8, "phase": 1.2 * k})
	text(122, 4, "q")
	text(127, 7, "*.....*.....*.....*")
	text(151, 4, "C")
	# F — cửa phòng ngai --------------------------------------------------------------------
	rect(153, 9, 157, 9)
	at(155, 10, "b")
	rect(161, 12, 165, 12)
	at(163, 13, "b")
	text(158, 4, "3.......G")
	at(160, 18, "j")
	at(166, 18, "j")
	at(163, 8, "t")
