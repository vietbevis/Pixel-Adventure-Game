## Màn hình Cài đặt: fullscreen, chế độ nút cảm ứng, (tạm) thanh âm lượng.
## Các lựa chọn lưu qua SaveManager.set_setting; fullscreen được áp lại lúc mở game
## trong main_menu.gd. FullscreenCheck là component IconToggle tái sử dụng.
extends Control

const TOUCH_MODES: Array[String] = ["auto", "on", "off"]
const TOUCH_LABELS := {"auto": "Auto", "on": "On", "off": "Off"}

@onready var fullscreen_check: TextureButton = $CenterContainer/DialogPanel/VBoxContainer/FullscreenRow/FullscreenCheck
@onready var touch_button: Button = $CenterContainer/DialogPanel/VBoxContainer/TouchRow/TouchButton
@onready var volume_slider: HSlider = $CenterContainer/DialogPanel/VBoxContainer/VolumeRow/VolumeSlider
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

func _ready() -> void:
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_refresh_touch_label()
	touch_button.pressed.connect(_on_touch_pressed)

	# Chưa có audio bus trong bộ asset này, slider chỉ để placeholder cho tính năng sau (Phase 10)
	volume_slider.editable = false
	volume_slider.modulate.a = 0.5
	back_button.pressed.connect(_on_back)

func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	SaveManager.set_setting("fullscreen", enabled)

## Cuộn qua Auto → On → Off. "Auto" = hiện nút cảm ứng nếu thiết bị có cảm ứng.
func _on_touch_pressed() -> void:
	var current: String = SaveManager.get_setting("touch_controls", "auto")
	var next: String = TOUCH_MODES[(TOUCH_MODES.find(current) + 1) % TOUCH_MODES.size()]
	SaveManager.set_setting("touch_controls", next)
	_refresh_touch_label()

func _refresh_touch_label() -> void:
	var mode: String = SaveManager.get_setting("touch_controls", "auto")
	touch_button.text = TOUCH_LABELS.get(mode, "Auto")

func _on_back() -> void:
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
