## Màn hình chính (Main Menu): màn chờ đầu tiên khi mở game.
## Điều hướng tới chọn nhân vật (Play), Cài đặt (Settings), hoặc Thoát game (Quit).
extends Control

@onready var play_button: Button = $CenterContainer/DialogPanel/VBoxContainer/PlayButton
@onready var settings_button: Button = $CenterContainer/DialogPanel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/DialogPanel/VBoxContainer/QuitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	_apply_saved_fullscreen()

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
