## Màn hình Cài đặt (Settings): bật/tắt toàn màn hình và (tạm thời) thanh âm lượng.
## FullscreenCheck là component IconToggle tái sử dụng (res://scenes/ui/components/icon_toggle.tscn),
## tự đổi hình bật/tắt bằng TextureButton nên script này không cần tự tay đổi icon.
extends Control

@onready var fullscreen_check: TextureButton = $CenterContainer/DialogPanel/VBoxContainer/FullscreenRow/FullscreenCheck
@onready var volume_slider: HSlider = $CenterContainer/DialogPanel/VBoxContainer/VolumeRow/VolumeSlider
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

func _ready() -> void:
	# Khởi tạo trạng thái công tắc fullscreen theo chế độ cửa sổ hiện tại
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	# Chưa có audio bus trong bộ asset này, slider chỉ để placeholder cho tính năng sau
	volume_slider.editable = false
	volume_slider.modulate.a = 0.5
	back_button.pressed.connect(_on_back)

## Chuyển đổi cửa sổ giữa chế độ toàn màn hình và cửa sổ thường
func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## Quay lại màn hình chính (Main Menu)
func _on_back() -> void:
	SceneTransition.goto("res://scenes/ui/main_menu.tscn")
