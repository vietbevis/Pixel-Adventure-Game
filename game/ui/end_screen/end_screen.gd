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
@onready var retry_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsBox/RetryButton
@onready var menu_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsBox/MenuButton

func _ready() -> void:
	var won := GameManager.last_result == "win"
	title_label.text = "YOU WIN!" if won else "GAME OVER"
	score_label.text = "Fruits collected: %d" % GameManager.score
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
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)

## Chơi lại: nếu vừa thắng thì phải bắt đầu lại từ đầu (bỏ checkpoint cũ).
## Tim (hearts) sẽ tự được làm đầy khi level_1.gd chạy lại (_enter_tree).
func _on_retry() -> void:
	if GameManager.last_result == "win":
		# Completed the level: a fresh retry starts over from the beginning.
		GameManager.has_checkpoint = false
	SceneTransition.goto("res://levels/level_1/level_1.tscn")

## Quay về màn hình chính, xoá checkpoint để lần chơi tiếp theo bắt đầu sạch
func _on_menu() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
