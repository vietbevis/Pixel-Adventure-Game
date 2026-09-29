extends CanvasLayer
## Instanced by level_base.gd on top of the game when the player presses "pause".
## process_mode is ALWAYS so its buttons keep working while the tree is paused.

@onready var dim: ColorRect = $Root/DimBackground
@onready var panel: PanelContainer = $Root/CenterContainer/Panel
@onready var resume_button: Button = $Root/CenterContainer/Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Root/CenterContainer/Panel/VBoxContainer/RestartButton
@onready var hub_button: Button = $Root/CenterContainer/Panel/VBoxContainer/HubButton
@onready var menu_button: Button = $Root/CenterContainer/Panel/VBoxContainer/MenuButton
@onready var confirm_panel: PanelContainer = $Root/CenterContainer/ConfirmPanel
@onready var confirm_button: Button = $Root/CenterContainer/ConfirmPanel/VBoxContainer/ConfirmButton
@onready var cancel_button: Button = $Root/CenterContainer/ConfirmPanel/VBoxContainer/CancelButton

const HUB_SCENE := "res://levels/hub/hub.tscn"

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)
	confirm_button.pressed.connect(_start_new_game)
	cancel_button.pressed.connect(_show_confirm.bind(false))
	# Đang ở làng rồi thì "Về Làng" vô nghĩa — ô đó thành "Chơi mới".
	if _in_hub():
		hub_button.text = "Chơi mới"
		hub_button.theme_type_variation = &"DangerButton"
		hub_button.pressed.connect(_on_new_game)
	else:
		hub_button.pressed.connect(_on_hub)
	resume_button.grab_focus()
	_play_intro()

## Fade nhẹ khi mở (Tween chạy pause-aware nên đặt process ALWAYS).
func _play_intro() -> void:
	dim.color.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	await get_tree().process_frame  # chờ container lay out xong mới lấy được size thật
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(dim, "color:a", 0.55, 0.18)
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_resume() -> void:
	get_tree().paused = false
	queue_free()

func _on_restart() -> void:
	GameManager.start_new_run(GameManager.current_level_id)
	SceneTransition.goto(LevelData.get_scene_path(GameManager.current_level_id))

## Bỏ dở màn, về làng — xoá checkpoint để lần vào lại bắt đầu sạch (như nút ở end_screen).
func _on_hub() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto(HUB_SCENE)

func _in_hub() -> bool:
	return GameManager.current_level_id == "hub"

## Như nút "Chơi mới" ở main menu: save trống thì làm luôn, có tiến trình thì hỏi trước.
func _on_new_game() -> void:
	if SaveManager.has_progress():
		_show_confirm(true)
	else:
		_start_new_game()

func _show_confirm(open: bool) -> void:
	panel.visible = not open
	confirm_panel.visible = open
	(cancel_button if open else hub_button).grab_focus()

func _start_new_game() -> void:
	SaveManager.reset_progress()
	GameManager.reset_run_state()
	SceneTransition.goto("res://ui/character_select/character_select.tscn")

func _on_menu() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto("res://ui/level_select/level_select.tscn")
