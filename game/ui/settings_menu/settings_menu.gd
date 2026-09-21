## Màn hình Cài đặt: toàn màn hình, nút cảm ứng, âm lượng.
## Các lựa chọn lưu qua SaveManager.set_setting; fullscreen được áp lại lúc mở game
## trong main_menu.gd. FullscreenCheck là component IconToggle tái sử dụng.
##
## Âm lượng dùng thanh Ô VẬY 10 bậc + nút −/+ thay cho HSlider: HSlider cũ kéo giãn
## sai 9-patch (texture nguồn chỉ 55×15px) nên thanh bị rách, núm trôi khỏi rãnh và
## không có phần tô đầy — không nhìn ra đang ở mức nào. Ô vậy hợp chất liệu pixel,
## bấm được bằng tay cầm/cảm ứng, và luôn cho biết chính xác đang ở bậc mấy.
extends Control

const TOUCH_MODES: Array[String] = ["auto", "on", "off"]
const TOUCH_LABELS := {"auto": "Tự động", "on": "Bật", "off": "Tắt"}

## Số bậc âm lượng. 10 bậc = mỗi bậc 10%, đủ mịn mà vẫn bấm trúng trên điện thoại.
const VOLUME_STEPS := 10
const BLOCK_SIZE := Vector2(16, 17)
const BLOCK_FILLED := Color(1.0, 0.85, 0.35)
const BLOCK_EMPTY := Color(0.24, 0.22, 0.28, 0.9)

@onready var fullscreen_check: TextureButton = $CenterContainer/DialogPanel/VBoxContainer/FullscreenRow/FullscreenCheck
@onready var touch_button: Button = $CenterContainer/DialogPanel/VBoxContainer/TouchRow/TouchButton
@onready var volume_value: Label = $CenterContainer/DialogPanel/VBoxContainer/VolumeBox/VolumeHeader/VolumeValue
@onready var volume_blocks: HBoxContainer = $CenterContainer/DialogPanel/VBoxContainer/VolumeBox/VolumeControl/VolumeBlocks
@onready var minus_button: Button = $CenterContainer/DialogPanel/VBoxContainer/VolumeBox/VolumeControl/MinusButton
@onready var plus_button: Button = $CenterContainer/DialogPanel/VBoxContainer/VolumeBox/VolumeControl/PlusButton
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

## Bậc âm lượng hiện tại, 0..VOLUME_STEPS.
var _level: int = 8

func _ready() -> void:
	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	_refresh_touch_label()
	touch_button.pressed.connect(_on_touch_pressed)

	_build_blocks()
	_level = roundi(float(SaveManager.get_setting("volume", 0.8)) * VOLUME_STEPS)
	_refresh_volume()
	minus_button.pressed.connect(_on_volume_step.bind(-1))
	plus_button.pressed.connect(_on_volume_step.bind(1))
	# Bấm/kéo thẳng trên dãy ô để nhảy tới bậc đó, giống thanh trượt.
	volume_blocks.gui_input.connect(_on_blocks_input)

	back_button.pressed.connect(_on_back)

# --- Âm lượng -----------------------------------------------------------------

## Dựng các ô trong code (giống cách hud.gd dựng icon tim) để số ô luôn khớp
## VOLUME_STEPS, không phải sửa scene mỗi lần đổi số bậc.
func _build_blocks() -> void:
	for i in VOLUME_STEPS:
		var block := ColorRect.new()
		block.custom_minimum_size = BLOCK_SIZE
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE  # để container nhận chuột
		# Không cho HBox kéo cao bằng hàng nút (34px) — giữ ô vuông, canh giữa.
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		volume_blocks.add_child(block)

func _on_volume_step(delta: int) -> void:
	_set_level(_level + delta, true)

## Vị trí chuột trên dãy ô → bậc tương ứng. Nhận cả lúc nhấn lẫn lúc kéo rê.
## Kéo thì chỉ áp âm lượng; thả/nhấn mới ghi xuống đĩa (xem `_set_level`).
func _on_blocks_input(event: InputEvent) -> void:
	var local_x: float = -1.0
	var commit := false
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			local_x = click.position.x
			commit = true
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			local_x = motion.position.x
	if local_x < 0.0:
		return
	var width := volume_blocks.size.x
	if width <= 0.0:
		return
	var ratio := clampf(local_x / width, 0.0, 1.0)
	# ceil: bấm trúng ô thứ n thì ô thứ n sáng lên (bấm sát mép trái = tắt hẳn).
	_set_level(ceili(ratio * VOLUME_STEPS), commit)

## `commit` = đã chốt giá trị → ghi xuống đĩa. Lúc đang kéo thì chỉ áp, không ghi.
func _set_level(level: int, commit: bool) -> void:
	var clamped: int = clampi(level, 0, VOLUME_STEPS)
	var changed := clamped != _level
	_level = clamped
	if changed:
		_refresh_volume()
	var value := float(_level) / float(VOLUME_STEPS)
	if commit:
		AudioManager.set_master_volume(value)
		# Tiếng "tách" để nghe được mức mới ngay cả khi không có nhạc nền.
		if _level > 0 and changed:
			AudioManager.play_sfx("pickup")
	else:
		AudioManager.apply_master_volume(value)

func _refresh_volume() -> void:
	for i in volume_blocks.get_child_count():
		var block: ColorRect = volume_blocks.get_child(i)
		block.color = BLOCK_FILLED if i < _level else BLOCK_EMPTY
	volume_value.text = "Tắt" if _level == 0 else "%d%%" % (_level * 100 / VOLUME_STEPS)
	minus_button.disabled = _level == 0
	plus_button.disabled = _level == VOLUME_STEPS

# --- Các lựa chọn khác --------------------------------------------------------

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

func _on_back() -> void:
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
