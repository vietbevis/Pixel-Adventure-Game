extends CanvasLayer
## Autoload: hộp thoại tĩnh ở đáy màn hình. NPC (hoặc bất kỳ ai) gọi `Dialogue.open(lines)`,
## người chơi bấm `interact` (E / nút touch) để qua từng dòng. Không dừng game
## (get_tree().paused) và KHÔNG dùng `jump` để sang dòng — player poll `jump` trong
## _physics_process nên sẽ nhảy theo; chỉ nhận `interact` (player không dùng action này).

signal finished

## true ngay khi `open()` được gọi — mọi chỗ polling `interact` (portal, hub_sign, npc)
## phải kiểm tra cờ này để không kích hoạt trùng trong cùng frame mở thoại.
var is_open: bool = false

var _lines: PackedStringArray = []
var _index: int = 0

@onready var _panel: Control = $Panel
@onready var _speaker_label: Label = $Panel/Margin/VBox/Speaker
@onready var _body_label: Label = $Panel/Margin/VBox/Body

func _ready() -> void:
	layer = 90
	_panel.visible = false
	_panel.modulate.a = 0.0

## Bỏ qua nếu đang mở sẵn (một hộp thoại tại một thời điểm).
func open(lines: PackedStringArray, speaker: String = "") -> void:
	if is_open or lines.is_empty():
		return
	is_open = true
	_lines = lines
	_index = 0
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_body_label.text = _lines[0]
	_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.15)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	_body_label.text = _lines[_index]

func _close() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func() -> void: _panel.visible = false)
	finished.emit()
	# Giữ is_open thêm 1 frame: cú nhấn `interact` đóng thoại này KHÔNG được để NPC/portal
	# bắt lại trong cùng frame (polling is_action_just_pressed bỏ qua set_input_as_handled).
	await get_tree().process_frame
	is_open = false
