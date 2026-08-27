## Màn hình chính (Main Menu): màn chờ đầu tiên khi mở game.
## Continue (nếu có save) → thẳng vào màn chơi gần nhất. Play → chọn nhân vật.
extends Control

@onready var continue_button: Button = $CenterContainer/DialogPanel/VBoxContainer/ContinueButton
@onready var play_button: Button = $CenterContainer/DialogPanel/VBoxContainer/PlayButton
@onready var settings_button: Button = $CenterContainer/DialogPanel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/DialogPanel/VBoxContainer/QuitButton

func _ready() -> void:
	var continue_level := SaveManager.get_continue_level()
	continue_button.visible = continue_level != "" and LevelData.get_index(continue_level) != -1
	continue_button.pressed.connect(_on_continue.bind(continue_level))
	play_button.pressed.connect(_on_play)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	_apply_saved_fullscreen()

## Vào thẳng màn chơi gần nhất (giữ nhân vật đã chọn từ lần trước).
func _on_continue(level_id: String) -> void:
	GameManager.start_new_run(level_id)
	SceneTransition.goto(LevelData.get_scene_path(level_id))

## Áp lại chế độ toàn màn hình đã lưu (settings_menu chỉ đổi lúc đang ở đó).
func _apply_saved_fullscreen() -> void:
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var want: bool = SaveManager.get_setting("fullscreen", is_fullscreen)
	if want != is_fullscreen:
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if want else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)

## Sang màn chọn nhân vật để bắt đầu chơi
func _on_play() -> void:
	SceneTransition.goto("res://ui/character_select/character_select.tscn")

## Mở màn hình Cài đặt
func _on_settings() -> void:
	SceneTransition.goto("res://ui/settings_menu/settings_menu.tscn")

## Thoát game
func _on_quit() -> void:
	get_tree().quit()
