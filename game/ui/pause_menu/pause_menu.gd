extends CanvasLayer
## Instanced by level_base.gd on top of the game when the player presses "pause".
## process_mode is ALWAYS so its buttons keep working while the tree is paused.

@onready var dim: ColorRect = $Root/DimBackground
@onready var panel: PanelContainer = $Root/CenterContainer/Panel
const SETTINGS_SCENE := preload("res://ui/settings_menu/settings_menu.tscn")

@onready var resume_button: Button = $Root/CenterContainer/Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Root/CenterContainer/Panel/VBoxContainer/RestartButton
@onready var settings_button: Button = $Root/CenterContainer/Panel/VBoxContainer/SettingsButton
@onready var menu_button: Button = $Root/CenterContainer/Panel/VBoxContainer/MenuButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	settings_button.pressed.connect(_on_settings)
	menu_button.pressed.connect(_on_menu)
	resume_button.grab_focus()
	_play_intro()

## Mở màn Cài đặt ngay trên pause menu (không đổi scene) — thoát Cài đặt thì tự huỷ.
func _on_settings() -> void:
	var s := SETTINGS_SCENE.instantiate()
	s.return_to_previous = true
	add_child(s)

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
	var d := ConfirmDialog.show_confirm(self, "Chơi lại màn này từ đầu?", "Chơi lại", "Không")
	d.confirmed.connect(func() -> void:
		GameManager.start_new_run(GameManager.current_level_id)
		SceneTransition.goto(LevelData.get_scene_path(GameManager.current_level_id)))

## "Về Hub": bỏ tiến trình màn hiện tại, về hub chọn world. Nếu vào từ Chọn màn lẻ
## (không thuộc world nào) thì về lại màn Chọn màn.
func _on_menu() -> void:
	var world := WorldData.world_of(GameManager.current_level_id)
	var dest := "res://levels/hub/hub.tscn" if world != "" else "res://ui/level_select/level_select.tscn"
	var d := ConfirmDialog.show_confirm(self, "Thoát màn và về Hub? Tiến trình màn này sẽ mất.", "Về Hub", "Ở lại")
	d.confirmed.connect(func() -> void:
		GameManager.has_checkpoint = false
		SceneTransition.goto(dest))
