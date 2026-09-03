## Màn hình chính (Main Menu): màn chờ đầu tiên khi mở game.
## Continue (nếu đã có tiến trình) → về hub để chọn world. Play → chọn nhân vật.
extends Control

const HUB_SCENE := "res://levels/hub/hub.tscn"

@onready var continue_button: Button = $CenterContainer/DialogPanel/VBoxContainer/ContinueButton
@onready var play_button: Button = $CenterContainer/DialogPanel/VBoxContainer/PlayButton
@onready var settings_button: Button = $CenterContainer/DialogPanel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/DialogPanel/VBoxContainer/QuitButton

func _ready() -> void:
	var continue_level := SaveManager.get_continue_level()
	continue_button.visible = continue_level != "" and LevelData.get_index(continue_level) != -1
	continue_button.pressed.connect(_on_continue)
	play_button.pressed.connect(_on_play)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	_apply_saved_fullscreen()
	(continue_button if continue_button.visible else play_button).grab_focus()

## Về hub: từ đây người chơi chọn world để chơi tiếp (world đã mở khoá vẫn giữ nguyên).
## Khôi phục nhân vật đã chọn lần trước để không bị reset về mặc định sau khi mở lại game.
func _on_continue() -> void:
	GameManager.selected_character = SaveManager.get_setting("character", GameManager.selected_character)
	GameManager.has_checkpoint = false
	SceneTransition.goto(HUB_SCENE)

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

## Thoát game (có xác nhận — tránh lỡ tay).
func _on_quit() -> void:
	var d := ConfirmDialog.show_confirm(self, "Thoát game?", "Thoát", "Ở lại")
	d.confirmed.connect(func() -> void: get_tree().quit())
