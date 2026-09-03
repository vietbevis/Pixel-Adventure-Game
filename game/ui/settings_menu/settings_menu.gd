## Màn hình Cài đặt: toàn màn hình, chế độ nút cảm ứng, âm lượng, giảm hiệu ứng.
## Lưu qua SaveManager.set_setting. Vào được từ Main Menu VÀ từ pause menu.
extends Control

const TOUCH_MODES: Array[String] = ["auto", "on", "off"]
const TOUCH_LABELS := {"auto": "Tự động", "on": "Bật", "off": "Tắt"}

## Nếu true khi thoát -> quay về scene trước (pause đang mở), thay vì về Main Menu.
var return_to_previous: bool = false

@onready var fullscreen_check: TextureButton = $CenterContainer/DialogPanel/VBoxContainer/FullscreenRow/FullscreenCheck
@onready var touch_button: Button = $CenterContainer/DialogPanel/VBoxContainer/TouchRow/TouchButton
@onready var volume_slider: HSlider = $CenterContainer/DialogPanel/VBoxContainer/VolumeRow/VolumeSlider
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

func _ready() -> void:
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_refresh_touch_label()
	touch_button.pressed.connect(_on_touch_pressed)

	volume_slider.editable = true
	volume_slider.modulate.a = 1.0
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = SaveManager.get_setting("volume", 0.8)
	# Áp NGAY khi kéo (không ghi đĩa), chỉ LƯU khi thả — tránh ghi file mỗi frame.
	volume_slider.value_changed.connect(AudioManager.apply_master_volume)
	volume_slider.drag_ended.connect(_on_volume_drag_ended)
	back_button.pressed.connect(_on_back)
	back_button.grab_focus()

func _on_volume_drag_ended(_value_changed: bool) -> void:
	AudioManager.set_master_volume(volume_slider.value)

func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	SaveManager.set_setting("fullscreen", enabled)

## Cuộn qua Tự động → Bật → Tắt. "Tự động" = hiện nút cảm ứng nếu thiết bị có cảm ứng.
func _on_touch_pressed() -> void:
	var current: String = SaveManager.get_setting("touch_controls", "auto")
	var next: String = TOUCH_MODES[(TOUCH_MODES.find(current) + 1) % TOUCH_MODES.size()]
	SaveManager.set_setting("touch_controls", next)
	_refresh_touch_label()

func _refresh_touch_label() -> void:
	var mode: String = SaveManager.get_setting("touch_controls", "auto")
	touch_button.text = TOUCH_LABELS.get(mode, "Tự động")

func _on_back() -> void:
	if return_to_previous:
		queue_free()  # settings được add làm con của pause menu -> chỉ cần huỷ
		return
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
