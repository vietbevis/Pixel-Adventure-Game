extends "res://tools/level_builder/level_kit.gd"
## LÂU ĐÀI 1 · TƯỜNG THÀNH — màn đầu của Lâu Đài, dùng Lướt ngay từ cổng vào. Nhịp:
##   A  bãi trước thành: con Heo đầu tiên (biết vung búa đánh trả, không như opossum)
##   B  hào sâu không đáy — cưỡi bệ gỗ trôi qua
##   C  cổng gỗ mục (Lướt để phá) → hành lang 3 KHỐI NGHIỀN → bậc ván lên mái
##   D  tường thành: checkpoint, đoạn sập (ván sập), heo ném bom trên ụ, PHÁO bắn dọc
##   E  tháp canh: phá cửa, leo các tầng so le; chuỳ gai treo dưới sàn tầng trên, lỗ châu
##      mai bắn tên ngang, heo phục kích
##   F  cầu cao (checkpoint 2) → nhảy xuống sân trong: heo phục kích, khối nghiền chặn
##      cửa thành, cờ đích bên trong.

const W := 176
const H := 46

func define() -> void:
	id = "level_3"
	backdrop = "night_town"
	world = "castle"
	title = "LÂU ĐÀI THẤT THỦ"
	subtitle = "Tường Thành"
	extrude = 6
	legend = {
		"1": {"type": "sign", "speaker": "Khắc trên đá", "line_1": "TƯỜNG THÀNH. Lâu đài của ngài — giờ là ổ Heo.", "line_2": "Heo biết vung búa: thấy nó giơ tay thì lùi lại, rồi chém."},
		"2": {"type": "sign", "speaker": "Khắc trên đá", "line_1": "Cổng gỗ đã mục.", "line_2": "LƯỚT (L) thẳng vào để phá!"},
		"3": {"type": "sign", "speaker": "Khắc trên đá", "line_1": "Khối đá nghiền rơi khi có người đi bên dưới.", "line_2": "Nhử nó rơi, rồi chạy qua lúc nó đang được kéo lên."},
		"4": {"type": "sign", "speaker": "Khắc trên đá", "line_1": "Hào sâu không đáy.", "line_2": "Đợi bệ gỗ trôi tới rồi nhảy lên."},
		"M": {"type": "moving_platform", "move_distance": Vector2(240, 0), "move_speed": 46.0},
		"B": {"type": "spiked_ball", "chain_length": 32.0, "swing_speed": 2.2},
		"V": {"type": "spiked_ball", "chain_length": 32.0, "swing_speed": 2.2, "phase": 1.6},
	}
	canvas(W, H)
	# A — bãi trước thành --------------------------------------------------------------
	rect(0, 0, 25, 4)
	text(2, 5, "S..1.....p.......r...4")
	text(8, 8, "*.*.*")
	# B — hào: không có đất, bệ trôi ở mép trên --------------------------------------------
	at(27, 4, "M")
	text(30, 8, "*...*...*")
	# C — cổng + hành lang khối nghiền ----------------------------------------------------
	rect(46, 0, 75, 4)
	rect(48, 8, 49, 12)            # tường trái của nhà cổng (cửa ở dưới)
	rect(48, 13, 75, 14)           # mái
	rect(70, 13, 75, 14, ".")      # lỗ trên mái để leo ra (rộng 6 ô)
	at(46, 5, "2")
	at(49, 5, "W")
	text(51, 5, "3")
	at(54, 12, "X")
	at(60, 12, "X")
	at(66, 12, "X")
	text(52, 7, "..*.....*.....*")
	at(56, 10, "t")
	at(62, 10, "t")
	back(50, 5, 75, 12)
	rect(65, 7, 68, 7, "=")
	rect(72, 10, 75, 10, "=")
	# D — tường thành ------------------------------------------------------------------
	rect(76, 0, 119, 14)
	rect(92, 0, 97, 14, ".")       # đoạn tường sập
	at(94, 14, "P")
	text(79, 15, "C......p")
	rect(106, 15, 109, 17)         # ụ gác
	at(107, 18, "b")
	at(117, 15, "c")
	text(93, 18, "*.*.*")
	text(100, 16, "*..*")
	# E — tháp canh -------------------------------------------------------------------
	rect(120, 0, 135, 14)
	rect(120, 18, 121, 38)         # tường trái (cửa ở dưới)
	rect(134, 15, 135, 36)         # tường phải
	at(121, 15, "W")
	back(122, 15, 133, 36)
	# Gờ so le trái/phải cách nhau 4 cột: nhảy chéo lên không bao giờ cụng mép gờ trên.
	rect(130, 18, 133, 18)
	rect(122, 21, 125, 21)
	rect(130, 24, 133, 24)
	rect(122, 27, 125, 27)
	rect(130, 30, 133, 30)
	rect(122, 33, 125, 33)
	rect(120, 37, 125, 38)         # mái tháp (nửa phải để trống — lối ra)
	at(125, 20, "B")
	at(131, 23, "V")
	at(125, 32, "B")
	at(133, 22, "<")
	at(123, 28, "a")
	text(130, 19, "*..*")
	text(122, 22, "*..*")
	text(130, 25, "*..*")
	at(126, 34, "*")
	at(128, 15, "q")
	at(124, 35, "t")
	# F — cầu cao rồi sân trong -------------------------------------------------------------
	rect(134, 37, 152, 38)
	text(139, 39, "C.......*.*..b")
	rect(136, 0, 175, 4)
	rect(166, 12, 175, 45)         # tường thành chính (cửa bên dưới)
	text(154, 5, "q...a....a")
	back(166, 5, 175, 11)
	at(169, 11, "X")
	text(158, 8, "*.*.*")
	at(173, 5, "G")
	at(163, 5, "r")

func extra_nodes(_root: Node2D) -> void:
	pass
