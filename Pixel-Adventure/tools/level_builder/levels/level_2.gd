extends "res://tools/level_builder/level_kit.gd"
## RỪNG 2 · TÁN CỔ THỤ — màn leo DỌC lên ngọn cây. Rơi xuống = mất công leo lại chứ
## không chết (chỉ gai mới đau), nên màn này thử thách bằng độ chính xác:
##   A  gốc cây: khe hẹp dạy BẬT TƯỜNG; đường hầm dưới rễ bị cổng Lướt khoá (bí mật 3)
##   B  bậc ván một chiều dưới tán lá, đại bàng lượn → checkpoint 1
##   C  thềm gai + QUẠT GIÓ thổi lên tầng trên (nhảy đôi không tới)
##   D  ván sập bắc sang phải (bí mật 2: gờ nhỏ phía trên, phải nhảy đôi từ ván đang rung)
##   E  khe bật tường thứ hai → cành lớn có ếch, opossum, đại bàng → checkpoint 2
##   F  khe bật tường dài nhất → ngọn cây: DI VẬT LƯỚT → hành lang có 2 bức tường
##      nứt chỉ vỡ khi Lướt vào (dạy Dash ngay khi vừa nhặt) → cờ đích.

const W := 46
const H := 90

func define() -> void:
	id = "level_2"
	world = "forest"
	title = "RỪNG RANH GIỚI"
	subtitle = "Tán Cổ Thụ"
	extrude = 6
	legend = {
		"1": {"type": "sign", "speaker": "Biển gỗ", "line_1": "Ngọn Cổ Thụ ở tít trên cao — di vật LƯỚT được cất trên đó.", "line_2": "Rơi xuống thì leo lại. Cẩn thận gai."},
		"2": {"type": "sign", "speaker": "Biển gỗ", "line_1": "Khe hẹp giữa hai vách?", "line_2": "Nhảy vào vách, rồi nhấn Space lần nữa để BẬT TƯỜNG sang vách bên kia. Cứ thế leo lên."},
		"3": {"type": "sign", "speaker": "Biển gỗ", "line_1": "Luồng gió từ cái quạt thổi rất mạnh.", "line_2": "Đứng vào luồng gió để được đẩy lên tầng trên."},
		"4": {"type": "sign", "speaker": "Biển gỗ", "line_1": "Có di vật rồi: nhấn L (hoặc Shift) để LƯỚT.", "line_2": "Tường nứt phía trước chỉ vỡ khi bị LƯỚT đâm vào."},
		"5": {"type": "sign", "speaker": "Biển gỗ", "line_1": "Ván cũ mục — đứng lâu là sập.", "line_2": "Chạy liền một mạch!"},
		"D": {"type": "diamond", "secret_id": "diamond_forest_2"},
		"K": {"type": "diamond", "secret_id": "diamond_forest_3"},
		"R": {"type": "relic", "ability_id": "dash"},
		"E": {"type": "eagle", "patrol_distance": 56.0},
	}
	canvas(W, H)
	# --- nền đất -------------------------------------------------------------------
	rect(0, 0, W - 1, 3)
	# --- A: gốc cây -------------------------------------------------------------------
	rect(11, 7, 12, 12)            # cột trái của khe
	rect(16, 8, W - 1, 12)         # khối rễ (vách phải của khe), rỗng bên dưới = đường hầm
	rect(44, 4, W - 1, 7)          # cuối đường hầm
	at(16, 4, "Z")                 # cổng Lướt ở miệng hầm
	at(40, 5, "K")
	text(19, 4, ".*...*...*...*")
	text(2, 4, "S...1.q.l")
	at(14, 4, "2")
	at(14, 8, "*")
	at(14, 11, "*")
	# --- B: bậc ván dưới tán lá -------------------------------------------------------------
	text(20, 13, "*.*.*.....o......j")
	rect(17, 15, 21, 15, "=")
	rect(10, 18, 14, 18, "=")
	rect(3, 21, 7, 21, "=")
	at(19, 17, "*")
	at(12, 20, "*")
	at(5, 23, "*")
	at(36, 19, "E")
	# --- C: thềm gai + quạt ------------------------------------------------------------
	rect(9, 24, 30, 24)            # thềm (trái là chỗ đứng, phải là gai)
	text(10, 25, "3.C.....F^^^^^^^^^^^")
	rect(19, 33, 29, 33)           # tầng trên, quạt thổi tới
	at(25, 29, "E")
	at(19, 30, "*")
	at(19, 32, "*")
	# --- D: ván sập sang phải; bí mật 2 ở gờ phía trên --------------------------------------
	text(21, 34, "5..*....")
	at(33, 34, "P")
	at(37, 34, "P")
	rect(40, 34, W - 1, 34)        # chỗ đáp
	rect(41, 38, 42, 49)           # cột trái của khe bật tường thứ hai
	rect(31, 40, 32, 40)           # gờ bí mật
	at(31, 41, "D")
	at(44, 38, "*")
	at(44, 43, "*")
	# --- E: cành lớn ------------------------------------------------------------------------
	rect(20, 49, 40, 49)
	text(21, 50, "*.o...*...g..*")
	at(30, 56, "E")
	rect(12, 52, 16, 52)
	at(14, 53, "*")
	rect(4, 55, 8, 55, "=")
	rect(0, 58, 6, 58)
	text(1, 59, "C...*")
	# --- F: khe dài lên ngọn --------------------------------------------------------------
	rect(3, 62, 4, 76)             # cột phải của khe (vách trái = mép bản đồ)
	for b in [63, 67, 71]:
		at(1, b, "*")
	rect(3, 74, W - 1, 76)         # tán cây (sàn ngọn)
	text(8, 77, "q..g....^^..4.....")
	at(15, 82, "E")
	at(31, 78, "R")
	# Hành lang trần thấp chắn bởi 2 bức tường nứt — chỉ vỡ khi LƯỚT vào. Dạy Dash
	# ngay sau khi nhặt di vật; không có Dash thì không tới được cờ.
	rect(34, 80, W - 1, 82)
	text(37, 77, "W...W..G")
	text(40, 83, "*.*")

func extra_nodes(_root: Node2D) -> void:
	pass
