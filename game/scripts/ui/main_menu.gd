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

## Sang màn chọn nhân vật để bắt đầu chơi
func _on_play() -> void:
	SceneTransition.goto("res://scenes/ui/character_select.tscn")

## Mở màn hình Cài đặt
func _on_settings() -> void:
	SceneTransition.goto("res://scenes/ui/settings_menu.tscn")

## Thoát game
func _on_quit() -> void:
	get_tree().quit()
