## Màn hình Cài đặt: toàn màn hình, nút cảm ứng, âm lượng Nhạc nền / Hiệu ứng.
## Các lựa chọn lưu qua SaveManager.set_setting; fullscreen được áp lại lúc mở game
## trong main_menu.gd. FullscreenCheck là component IconToggle, 2 dòng âm lượng là
## component VolumeBar (ui/components/volume_bar/) — mỗi dòng tự đọc/ghi bus của nó.
## Dòng "Tính năng AI" bật/tắt autoload Gemini (lưu trong prefs riêng của client, không qua SaveManager).
## Menu pause mở màn này dạng lớp phủ (`overlay = true`): không nền, "Quay lại" chỉ đóng lớp phủ.
extends Control

## Phát khi đóng lớp phủ (chỉ ở chế độ overlay).
signal closed

const TOUCH_MODES: Array[String] = ["auto", "on", "off"]
const TOUCH_LABELS := {"auto": "Tự động", "on": "Bật", "off": "Tắt"}

@onready var fullscreen_check: TextureButton = $CenterContainer/DialogPanel/VBoxContainer/Body/ColA/FullscreenRow/FullscreenCheck
@onready var touch_button: Button = $CenterContainer/DialogPanel/VBoxContainer/Body/ColA/TouchRow/TouchButton
@onready var ai_button: Button = $CenterContainer/DialogPanel/VBoxContainer/Body/ColA/AiRow/AiButton
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

## Đặt trước add_child: mở chồng lên game đang pause thay vì là một màn riêng.
var overlay := false

func _ready() -> void:
	# Lớp phủ: bỏ nền để thấy màn chơi mờ phía sau (menu pause đã phủ tối sẵn).
	$Background.visible = not overlay
	# Khối menu co giãn theo kích thước/tỉ lệ màn thật (xem ui/shared/screen_fit.gd).
	ScreenFit.attach($CenterContainer, [$CenterContainer/DialogPanel/VBoxContainer/Body])
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_refresh_touch_label()
	touch_button.pressed.connect(_on_touch_pressed)

	_refresh_ai()
	ai_button.pressed.connect(_on_ai_pressed)

	back_button.pressed.connect(_on_back)
	if overlay:
		back_button.grab_focus()

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
	touch_button.text = String(TOUCH_LABELS.get(mode, "Tự động"))

func _on_ai_pressed() -> void:
	Gemini.set_user_enabled(not Gemini.is_user_enabled())
	_refresh_ai()

## Không có key thì khoá nút — người chơi không bật được AI không chạy nổi.
func _refresh_ai() -> void:
	if not Gemini.has_key():
		ai_button.text = "Chưa có key"
		ai_button.disabled = true
		return
	ai_button.disabled = false
	ai_button.text = "Bật" if Gemini.is_user_enabled() else "Tắt"

func _on_back() -> void:
	if overlay:
		closed.emit()
		queue_free()
		return
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
