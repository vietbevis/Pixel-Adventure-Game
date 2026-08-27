## Màn kết thúc lượt chơi: dùng chung cho cả "Game Over" (thua) và "You Win" (thắng).
## Trạng thái thắng/thua đọc từ GameManager.last_result, được set bởi màn chơi trước đó.
extends Control

const WIN_PANEL_TEXTURE := preload("res://ui/theme/panels/dialog_tan.png")
## Ảnh nền lát nền (tile) cho từng trạng thái: xám trầm khi thua, vàng ấm khi thắng
const LOSE_BG_TEXTURE := preload("res://shared/backgrounds/Gray.png")
const WIN_BG_TEXTURE := preload("res://shared/backgrounds/Yellow.png")

@onready var background: TextureRect = $Background
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var confetti: CPUParticles2D = $Confetti
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $CenterContainer/Panel/VBoxContainer/ScoreLabel
@onready var next_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsBox/NextButton
@onready var retry_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsBox/RetryButton
@onready var menu_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsBox/MenuButton

func _ready() -> void:
	var won := GameManager.last_result == "win"
	var time_taken := GameManager.elapsed_time()
	var previous_best := SaveManager.get_best_time(GameManager.current_level_id)
	var is_new_best := won and (previous_best < 0.0 or time_taken < previous_best)
	SaveManager.record_result(GameManager.current_level_id, GameManager.score, won, time_taken)
	title_label.text = "YOU WIN!" if won else "GAME OVER"
	score_label.text = "Fruits collected: %d" % GameManager.score
	if won:
		score_label.text += "\nTime: %s%s" % [
			LevelData.format_time(time_taken),
			"  (New Best!)" if is_new_best else "",
		]
	# Đổi ảnh nền lát theo kết quả: vàng ấm áp khi thắng, xám trầm khi thua
	background.texture = WIN_BG_TEXTURE if won else LOSE_BG_TEXTURE
	# Hiệu ứng confetti và khung nền vàng chỉ hiện khi thắng, tạo cảm giác ăn mừng
	confetti.emitting = won
	confetti.visible = won
	if won:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		var win_style := StyleBoxTexture.new()
		win_style.texture = WIN_PANEL_TEXTURE
		win_style.texture_margin_left = 16.0
		win_style.texture_margin_top = 16.0
		win_style.texture_margin_right = 16.0
		win_style.texture_margin_bottom = 16.0
		win_style.content_margin_left = 24.0
		win_style.content_margin_top = 20.0
		win_style.content_margin_right = 24.0
		win_style.content_margin_bottom = 20.0
		panel.add_theme_stylebox_override("panel", win_style)
	# "Next Level" chỉ hiện khi vừa thắng và world này còn màn kế tiếp (không phải boss).
	var next_id := WorldData.next_in_world(GameManager.current_level_id) if won else ""
	next_button.visible = next_id != ""
	next_button.pressed.connect(_on_next.bind(next_id))
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)

## Chơi lại: nếu vừa thắng thì phải bắt đầu lại từ đầu (bỏ checkpoint cũ).
## Tim (hearts) sẽ tự được làm đầy khi level_1.gd chạy lại (_enter_tree).
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
func _on_menu() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto("res://levels/hub/hub.tscn")
