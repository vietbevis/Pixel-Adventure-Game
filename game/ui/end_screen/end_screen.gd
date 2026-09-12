## Màn kết thúc lượt chơi: dùng chung cho cả "Game Over" (thua) và "You Win" (thắng).
## Trạng thái thắng/thua đọc từ GameManager.last_result, được set bởi màn chơi trước đó.
extends Control

## Ảnh nền lát nền (tile) cho từng trạng thái: xám trầm khi thua, vàng ấm khi thắng
const LOSE_BG_TEXTURE := preload("res://shared/backgrounds/Gray.png")
const WIN_BG_TEXTURE := preload("res://shared/backgrounds/Yellow.png")

@onready var background: TextureRect = $Background
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var fireworks_container: Node2D = $FireworksContainer
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $CenterContainer/Panel/VBoxContainer/ScoreLabel
@onready var next_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsVBox/NextButton
@onready var retry_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsVBox/SecondaryButtons/RetryButton
@onready var menu_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonsVBox/SecondaryButtons/MenuButton

func _ready() -> void:
	_play_intro()
	var won := GameManager.last_result == "win"
	var time_taken := GameManager.elapsed_time()
	var previous_best := SaveManager.get_best_time(GameManager.current_level_id)
	var is_new_best := won and (previous_best < 0.0 or time_taken < previous_best)
	SaveManager.record_result(GameManager.current_level_id, GameManager.score, won, time_taken)
	title_label.text = "YOU WIN!" if won else "GAME OVER"
	score_label.text = "Fruits: %d" % GameManager.score
	if won:
		score_label.text += "\nTime: %s%s" % [
			LevelData.format_time(time_taken),
			"  (New Best!)" if is_new_best else "",
		]
	# Đổi ảnh nền lát theo kết quả: vàng ấm áp khi thắng, xám trầm khi thua
	background.texture = WIN_BG_TEXTURE if won else LOSE_BG_TEXTURE
	if won:
		_spawn_fireworks()
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		# Khung vàng ấm khi thắng — dùng biến thể theme (khớp quy ước "không dựng
		# StyleBox trong code"; đổi stylebox lúc runtime từng làm panel co lại).
		panel.theme_type_variation = &"DialogPanelWin"
	# "Next Level" chỉ hiện khi vừa thắng và world này còn màn kế tiếp (không phải boss).
	var next_id := WorldData.next_in_world(GameManager.current_level_id) if won else ""
	next_button.visible = next_id != ""
	next_button.pressed.connect(_on_next.bind(next_id))
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)

var _is_fireworks_active := false

func _spawn_fireworks() -> void:
	_is_fireworks_active = true
	# Dùng mã màu thật sáng (neon/chói) để trông rực rỡ hơn
	var colors := [
		Color("#ff3333"), # Red
		Color("#33ff33"), # Green
		Color("#5555ff"), # Blue
		Color("#ffff33"), # Yellow
		Color("#ff33ff"), # Magenta
		Color("#33ffff"), # Cyan
		Color("#ff9933")  # Orange
	]
	
	while _is_fireworks_active:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.lifetime = 1.0
		p.amount = 100
		p.direction = Vector2.UP
		p.spread = 180.0
		p.gravity = Vector2(0, 150)
		p.initial_velocity_min = 150.0
		p.initial_velocity_max = 300.0
		p.scale_amount_min = 3.0
		p.scale_amount_max = 7.0
		p.color = colors.pick_random()
		
		p.position = Vector2(randf_range(200, 952), randf_range(100, 300))
		fireworks_container.add_child(p)
		p.emitting = true
		
		# Tự động hủy particle sau khi nổ xong để dọn dẹp bộ nhớ
		get_tree().create_timer(1.2).timeout.connect(p.queue_free)
		
		# Đợi 0.2 - 0.6 giây rồi bắn quả tiếp theo (bắn liên tục)
		await get_tree().create_timer(randf_range(0.2, 0.6)).timeout

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
## Tim (hearts) sẽ tự được làm đầy khi level_1.gd chạy lại (_enter_tree).
func _on_retry() -> void:
	# Completed or failed: either way retry starts this level over from the beginning.
	GameManager.start_new_run(GameManager.current_level_id)
	SceneTransition.goto(LevelData.get_scene_path(GameManager.current_level_id))

## Đi tiếp màn kế trong world (flow "chain trong world"): bắt đầu lượt mới cho màn đó.
func _on_next(next_id: String) -> void:
	next_button.disabled = true
	retry_button.disabled = true
	menu_button.disabled = true
	_is_fireworks_active = false
	
	if fireworks_container:
		var tween = create_tween()
		tween.tween_property(fireworks_container, "modulate:a", 0.0, 0.5)
		await tween.finished

	GameManager.has_checkpoint = false
	GameManager.start_new_run(next_id)
	SceneTransition.goto(LevelData.get_scene_path(next_id))

## Quay về hub, xoá checkpoint để lần chơi tiếp theo bắt đầu sạch
func _on_menu() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto("res://levels/hub/hub.tscn")
