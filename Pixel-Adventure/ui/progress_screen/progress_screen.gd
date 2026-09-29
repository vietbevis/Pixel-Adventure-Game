## Màn "Tiến trình": tổng hợp mọi thứ đã lưu trong SaveManager thành một trang đọc được —
## mục tiêu thắng game, tiến độ từng world/màn, sức mạnh, boss, mảnh Vương Ấn, thành tựu.
## Là đích đến của nút thứ 4 ở end_screen (và nút cùng tên ở main menu).
##
## Nội dung dựng bằng code từ SaveManager / WorldData / Achievements (giống level_select)
## vì số dòng phụ thuộc dữ liệu, không thể bake sẵn vào scene.
extends Control

## Mục tiêu thắng cả game — nêu rõ ở đây vì trong lúc chơi không chỗ nào nói.
const GOAL_LINE := "MỤC TIÊU: Đoạt lại Vương Miện — hạ Cai Ngục ở Hầm Ngục Cổ."
const GOAL_DONE_LINE := "Ngài đã đoạt lại Vương Miện. Vương quốc có Vua trở lại."
## Boss cuối — thắng ở đây là thắng cả game.
const FINAL_BOSS_ID := "dungeon_boss"
## Tổng số mảnh Vương Ấn giấu trong Rừng (khớp Progression.FOREST_SECRETS).
const TOTAL_SECRETS := 3

## Tên hiển thị tiếng Việt cho ability / boss (khớp Toast và npc.gd).
const ABILITY_NAMES := {"dash": "Lướt (Dash)"}
const BOSS_NAMES := {"forest_boss": "Vua Heo", "dungeon_boss": "Cai Ngục"}

const COLOR_HEADER := Color(1.0, 0.86, 0.5)
const COLOR_DONE := Color(0.62, 0.95, 0.58)
const COLOR_LOCKED := Color(0.8, 0.8, 0.86)
## Panel DialogPanel sáng màu: chữ nhạt đặt thẳng lên đó không đọc được, nên mọi dòng
## đều có viền tối dày (giống tiêu đề) thay vì đổi sang chữ tối, để màu trạng thái vẫn rõ.
const OUTLINE_COLOR := Color(0.08, 0.06, 0.1)
const HEADER_SIZE := 24
const LINE_SIZE := 20

@onready var goal_label: Label = $CenterContainer/DialogPanel/VBoxContainer/GoalLabel
## Hai cột để không phải cuộn: trái = thế giới + tổng kết, phải = sức mạnh / boss / Vương Ấn / thành tựu.
@onready var left_box: VBoxContainer = $CenterContainer/DialogPanel/VBoxContainer/BodyScroll/Columns/LeftBox
@onready var right_box: VBoxContainer = $CenterContainer/DialogPanel/VBoxContainer/BodyScroll/Columns/RightBox
## Cột mà `_header` / `_line` đang ghi vào.
var body_box: VBoxContainer
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_populate()

func _populate() -> void:
	for box: VBoxContainer in [left_box, right_box]:
		for child in box.get_children():
			child.queue_free()

	var beat_game := SaveManager.is_boss_defeated(FINAL_BOSS_ID)
	if beat_game:
		goal_label.text = GOAL_DONE_LINE
	else:
		# Mục tiêu cuối + bước kế tiếp. Bước kế tiếp lấy từ Progression để trùng khít
		# với điều NPC Cố vấn nói ở hub.
		goal_label.text = "%s\nBƯỚC KẾ TIẾP: %s" % [GOAL_LINE, Progression.next_objective()["text"]]
	goal_label.add_theme_color_override("font_color", COLOR_DONE if beat_game else COLOR_HEADER)

	body_box = left_box
	_add_worlds()
	_add_summary()
	body_box = right_box
	_add_abilities()
	_add_bosses()
	_add_secrets()
	_add_achievements()

func _add_worlds() -> void:
	_header("THẾ GIỚI")
	for world: Dictionary in WorldData.WORLDS:
		var world_id: String = world["id"]
		var world_name: String = world["name"]
		var unlocked := WorldData.is_world_unlocked(world_id)
		_line("  %s" % (world_name if unlocked else "🔒 %s" % world_name),
			COLOR_HEADER if unlocked else COLOR_LOCKED)
		for level_id: String in world["levels"]:
			_line("    %s" % _level_line(level_id),
				COLOR_DONE if SaveManager.is_level_completed(level_id) else COLOR_LOCKED)

## Một dòng màn: trạng thái + tên + điểm cao + thời gian tốt nhất.
func _level_line(level_id: String) -> String:
	var done := SaveManager.is_level_completed(level_id)
	var mark := "✓" if done else ("·" if SaveManager.is_level_unlocked(level_id) else "🔒")
	var text := "%s %s" % [mark, _level_name(level_id)]
	if done:
		var high_score := SaveManager.get_high_score(level_id)
		var best_time := SaveManager.get_best_time(level_id)
		if high_score > 0:
			text += "  ·  %d 🍎" % high_score
		if best_time >= 0.0:
			text += "  ·  ⏱ %s" % LevelData.format_time(best_time)
	return text

func _add_abilities() -> void:
	_header("SỨC MẠNH")
	var unlocked: Array = SaveManager.get_unlocked_abilities()
	if unlocked.is_empty():
		_line("    Chưa mở khoá sức mạnh nào.", COLOR_LOCKED)
		return
	for id: String in unlocked:
		_line("    ✓ %s" % String(ABILITY_NAMES.get(id, id.capitalize())), COLOR_DONE)

func _add_bosses() -> void:
	_header("BOSS ĐÃ HẠ")
	var any := false
	for boss_id: String in BOSS_NAMES.keys():
		if SaveManager.is_boss_defeated(boss_id):
			_line("    ✓ %s" % String(BOSS_NAMES[boss_id]), COLOR_DONE)
			any = true
	if not any:
		_line("    Chưa hạ được boss nào.", COLOR_LOCKED)

func _add_secrets() -> void:
	_header("MẢNH VƯƠNG ẤN")
	var found: int = SaveManager.collected_secrets.size()
	var bonus := SaveManager.get_max_hp_bonus()
	_line("    %d / %d mảnh đã tìm thấy" % [found, TOTAL_SECRETS],
		COLOR_DONE if found >= TOTAL_SECRETS else COLOR_LOCKED)
	if bonus > 0:
		_line("    +%d tim tối đa từ phần thưởng" % bonus, COLOR_DONE)

func _add_achievements() -> void:
	_header("THÀNH TỰU")
	for id: String in Achievements.ACHIEVEMENTS.keys():
		var got := SaveManager.has_achievement(id)
		_line("    %s %s" % ["🏆" if got else "🔒", String(Achievements.ACHIEVEMENTS[id])],
			COLOR_DONE if got else COLOR_LOCKED)

func _add_summary() -> void:
	_header("TỔNG KẾT")
	var total := 0
	var done := 0
	for world: Dictionary in WorldData.WORLDS:
		for level_id: String in world["levels"]:
			total += 1
			if SaveManager.is_level_completed(level_id):
				done += 1
	_line("    Màn đã hoàn thành: %d / %d" % [done, total], COLOR_HEADER)
	_line("    Thành tựu: %d / %d" % [SaveManager.achievements.size(), Achievements.ACHIEVEMENTS.size()],
		COLOR_HEADER)

func _header(text: String) -> void:
	if body_box.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		body_box.add_child(spacer)
	body_box.add_child(_make_label(text, COLOR_HEADER, HEADER_SIZE))

func _line(text: String, color: Color) -> void:
	body_box.add_child(_make_label(text, color, LINE_SIZE))

func _make_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 5)
	return label

## Tên hiển thị của từng màn — tra từ LevelData để không lặp chuỗi (giống level_select).
func _level_name(level_id: String) -> String:
	var idx := LevelData.get_index(level_id)
	return LevelData.LEVELS[idx]["name"] if idx != -1 else level_id

func _on_back() -> void:
	SceneTransition.goto(GameManager.progress_return_scene)
