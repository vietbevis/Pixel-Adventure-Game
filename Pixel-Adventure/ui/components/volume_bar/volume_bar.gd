## Một dòng chỉnh âm lượng cho 1 bus: tiêu đề + % ở trên, dưới là nút −, dãy ô, nút +.
## Tách thành component vì màn Cài đặt cần 2 dòng giống hệt nhau (Nhạc nền / Hiệu ứng),
## chỉ khác bus. Đọc/ghi qua AudioManager.get_volume / apply_volume / set_volume.
##
## Dùng dãy Ô VUÔNG 10 bậc + nút −/+ thay cho HSlider: HSlider cũ kéo giãn sai 9-patch
## (texture nguồn chỉ 55×15px) nên thanh bị rách, núm trôi khỏi rãnh và không có phần
## tô đầy — không nhìn ra đang ở mức nào. Ô vuông hợp chất liệu pixel, bấm được bằng
## tay cầm/cảm ứng, và luôn cho biết chính xác đang ở bậc mấy.
class_name VolumeBar
extends VBoxContainer

## Số bậc âm lượng. 10 bậc = mỗi bậc 10%, đủ mịn mà vẫn bấm trúng trên điện thoại.
const STEPS := 10
const BLOCK_SIZE := Vector2(16, 17)
const BLOCK_FILLED := Color(1.0, 0.85, 0.35)
const BLOCK_EMPTY := Color(0.24, 0.22, 0.28, 0.9)

@export var title: String = "Âm lượng"
## Tên bus trong audio/game_bus_layout.tres — phải có trong AudioManager.VOLUME_KEYS.
@export var bus_name: String = "Music"
## Tiếng phát khi chốt mức mới để nghe thử. "" = không phát (dòng Nhạc nền: nhạc
## menu đang chạy sẵn nên nghe được ngay, thêm tiếng "tách" chỉ gây nhiễu).
@export var preview_sfx: String = ""

@onready var title_label: Label = $Header/TitleLabel
@onready var value_label: Label = $Header/ValueLabel
@onready var blocks: HBoxContainer = $Control/Blocks
@onready var minus_button: Button = $Control/MinusButton
@onready var plus_button: Button = $Control/PlusButton

## Bậc hiện tại, 0..STEPS.
var _level: int = 8

func _ready() -> void:
	title_label.text = title
	_build_blocks()
	_level = roundi(AudioManager.get_volume(bus_name) * STEPS)
	_refresh()
	minus_button.pressed.connect(_on_step.bind(-1))
	plus_button.pressed.connect(_on_step.bind(1))
	# Bấm/kéo thẳng trên dãy ô để nhảy tới bậc đó, giống thanh trượt.
	blocks.gui_input.connect(_on_blocks_input)

## Dựng các ô trong code (giống cách hud.gd dựng icon tim) để số ô luôn khớp
## STEPS, không phải sửa scene mỗi lần đổi số bậc.
func _build_blocks() -> void:
	for i in STEPS:
		var block := ColorRect.new()
		block.custom_minimum_size = BLOCK_SIZE
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE  # để container nhận chuột
		# Không cho HBox kéo cao bằng hàng nút (34px) — giữ ô vuông, canh giữa.
		block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		blocks.add_child(block)

func _on_step(delta: int) -> void:
	_set_level(_level + delta, true)

## Vị trí chuột trên dãy ô → bậc tương ứng. Nhận cả lúc nhấn lẫn lúc kéo rê.
## Kéo thì chỉ áp âm lượng; nhấn mới ghi xuống đĩa (xem `_set_level`).
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
	var width := blocks.size.x
	if width <= 0.0:
		return
	var ratio := clampf(local_x / width, 0.0, 1.0)
	# ceil: bấm trúng ô thứ n thì ô thứ n sáng lên (bấm sát mép trái = tắt hẳn).
	_set_level(ceili(ratio * STEPS), commit)

## `commit` = đã chốt giá trị → ghi xuống đĩa. Lúc đang kéo thì chỉ áp, không ghi.
func _set_level(level: int, commit: bool) -> void:
	var clamped: int = clampi(level, 0, STEPS)
	var changed := clamped != _level
	_level = clamped
	if changed:
		_refresh()
	var value := float(_level) / float(STEPS)
	if commit:
		AudioManager.set_volume(bus_name, value)
		if preview_sfx != "" and _level > 0 and changed:
			AudioManager.play_sfx(preview_sfx)
	else:
		AudioManager.apply_volume(bus_name, value)

func _refresh() -> void:
	for i in blocks.get_child_count():
		var block: ColorRect = blocks.get_child(i)
		block.color = BLOCK_FILLED if i < _level else BLOCK_EMPTY
	value_label.text = "Tắt" if _level == 0 else "%d%%" % (_level * 100 / STEPS)
	minus_button.disabled = _level == 0
	plus_button.disabled = _level == STEPS
