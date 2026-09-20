## Màn kết thúc lượt chơi: dùng chung cho cả "Game Over" (thua) và "You Win" (thắng).
## Trạng thái thắng/thua đọc từ GameManager.last_result, được set bởi màn chơi trước đó.
##
## Luôn hiển thị 4 nút điều hướng (Chơi lại / Về Làng / Trang chủ / Tiến trình), kể cả
## khi thua — "Màn tiếp theo" là nút thứ 5 có điều kiện, nằm riêng phía trên.
## Hiệu ứng báo kết quả + âm thanh đã chơi TRƯỚC đó ngay trên màn chơi (ui/result_flash).
extends Control

## Ảnh nền lát nền (tile) cho từng trạng thái: xám trầm khi thua, vàng ấm khi thắng
const LOSE_BG_TEXTURE := preload("res://shared/backgrounds/Gray.png")
const WIN_BG_TEXTURE := preload("res://shared/backgrounds/Yellow.png")

const HUB_SCENE := "res://levels/hub/hub.tscn"
const MAIN_MENU_SCENE := "res://ui/main_menu/main_menu.tscn"
const PROGRESS_SCENE := "res://ui/progress_screen/progress_screen.tscn"

## Thắng ở màn này = thắng CẢ GAME (boss cuối), không phải chỉ thắng 1 màn.
const FINAL_LEVEL_ID := "boss_dungeon"
## Tổng số mảnh Vương Ấn (khớp Progression.FOREST_SECRETS).
const TOTAL_SECRETS := 3

@onready var background: TextureRect = $Background
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var confetti: CPUParticles2D = $Confetti
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $CenterContainer/Panel/VBoxContainer/ScoreLabel
@onready var summary_label: Label = $CenterContainer/Panel/VBoxContainer/SummaryLabel
@onready var next_button: Button = $CenterContainer/Panel/VBoxContainer/NextButton
@onready var retry_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsGrid/RetryButton
@onready var hub_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsGrid/HubButton
@onready var home_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsGrid/HomeButton
@onready var progress_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsGrid/ProgressButton

func _ready() -> void:
	_play_intro()
	var won := GameManager.last_result == "win"
	var is_final := won and GameManager.current_level_id == FINAL_LEVEL_ID
	var time_taken := GameManager.elapsed_time()
	var previous_best := SaveManager.get_best_time(GameManager.current_level_id)
	var is_new_best := won and (previous_best < 0.0 or time_taken < previous_best)
	# Chỉ ghi một lần cho mỗi lượt: quay lại từ màn Tiến trình sẽ chạy _ready lần nữa.
	if not GameManager.result_recorded:
		GameManager.result_recorded = true
		SaveManager.record_result(GameManager.current_level_id, GameManager.score, won, time_taken)
	else:
		is_new_best = false

	if is_final:
		title_label.text = "VƯƠNG MIỆN TRỞ VỀ!"
	elif won:
		title_label.text = "CHIẾN THẮNG!"
	else:
		title_label.text = "THẤT BẠI"

	score_label.text = "Quả đã ăn: %d" % GameManager.score
	if won:
		score_label.text += "\nThời gian: %s%s" % [
			LevelData.format_time(time_taken),
			"  (Kỷ lục mới!)" if is_new_best else "",
		]
	# Đổi ảnh nền lát theo kết quả: vàng ấm áp khi thắng, xám trầm khi thua
	background.texture = WIN_BG_TEXTURE if won else LOSE_BG_TEXTURE
	# Hiệu ứng confetti và khung nền vàng chỉ hiện khi thắng, tạo cảm giác ăn mừng
	confetti.emitting = won
	confetti.visible = won
	if won:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		# Khung vàng ấm khi thắng — dùng biến thể theme (khớp quy ước "không dựng
		# StyleBox trong code"; đổi stylebox lúc runtime từng làm panel co lại).
		panel.theme_type_variation = &"DialogPanelWin"

	# Thắng cả game: thêm khối tổng kết toàn bộ hành trình, không chỉ điểm của 1 màn.
	summary_label.visible = is_final
	if is_final:
		summary_label.text = _final_summary()

	# "Màn tiếp theo" chỉ hiện khi vừa thắng và world này còn màn kế (không phải boss).
	var next_id := WorldData.next_in_world(GameManager.current_level_id) if won else ""
	next_button.visible = next_id != ""
	next_button.pressed.connect(_on_next.bind(next_id))
	retry_button.pressed.connect(_on_retry)
	hub_button.pressed.connect(_on_hub)
	home_button.pressed.connect(_on_home)
	progress_button.pressed.connect(_on_progress)

## Tổng kết cả hành trình, hiện khi hạ boss cuối.
func _final_summary() -> String:
	var total := 0
	var done := 0
	for world: Dictionary in WorldData.WORLDS:
		for level_id: String in world["levels"]:
			total += 1
			if SaveManager.is_level_completed(level_id):
				done += 1
	return "Màn đã hoàn thành: %d/%d  ·  Mảnh Vương Ấn: %d/%d  ·  Thành tựu: %d/%d" % [
		done, total,
		SaveManager.collected_secrets.size(), TOTAL_SECRETS,
		SaveManager.achievements.size(), Achievements.ACHIEVEMENTS.size(),
	]

## Fade + pop nhẹ khi mở (thay cho AnimationPlayer cũ — animate scale trên
## PanelContainer từng làm khung co lại không bao hết nút).
func _play_intro() -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	await get_tree().process_frame
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Chơi lại: nếu vừa thắng thì phải bắt đầu lại từ đầu (bỏ checkpoint cũ).
## Tim (hearts) sẽ tự được làm đầy khi level_base chạy lại (_enter_tree).
func _on_retry() -> void:
	# Completed or failed: either way retry starts this level over from the beginning.
	GameManager.start_new_run(GameManager.current_level_id)
	SceneTransition.goto(LevelData.get_scene_path(GameManager.current_level_id))

## Đi tiếp màn kế trong world (flow "chain trong world"): bắt đầu lượt mới cho màn đó.
func _on_next(next_id: String) -> void:
	GameManager.has_checkpoint = false
	GameManager.start_new_run(next_id)
	SceneTransition.goto(LevelData.get_scene_path(next_id))

## Quay về hub, xoá checkpoint để lần chơi tiếp theo bắt đầu sạch
func _on_hub() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto(HUB_SCENE)

## Về màn hình chính. Cũng xoá checkpoint vì lượt chơi này đã kết thúc.
func _on_home() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto(MAIN_MENU_SCENE)

## Xem tiến trình đã lưu. Quay lại thì về đúng màn này (state còn nguyên trong GameManager).
func _on_progress() -> void:
	GameManager.progress_return_scene = "res://ui/end_screen/end_screen.tscn"
	SceneTransition.goto(PROGRESS_SCENE)
