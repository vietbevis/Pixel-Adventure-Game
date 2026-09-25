extends CanvasLayer
## Autoload: hộp thoại tĩnh ở đáy màn hình. NPC (hoặc bất kỳ ai) gọi `Dialogue.open(lines)`,
## người chơi bấm `interact` (E / nút touch) để qua từng dòng. Không dừng game
## (get_tree().paused) và KHÔNG dùng `jump` để sang dòng — player poll `jump` trong
## _physics_process nên sẽ nhảy theo; chỉ nhận `interact` (player không dùng action này).

signal finished

## Sau khi đóng, chặn mở lại trong khoảng này (ms). Cú nhấn `interact` đóng thoại vẫn còn
## `is_action_just_pressed` trong `_process` cùng frame, nên NPC/portal/biển bên cạnh sẽ bắt
## lại và mở hộp mới ngay lập tức — hộp đó nháy lên rồi biến mất. Chờ `process_frame` không
## đủ: signal đó phát TRƯỚC `_process` của các node trong cùng frame.
const REOPEN_COOLDOWN_MS := 200

## true khi đang mở VÀ trong lúc hồi sau khi đóng — mọi chỗ polling `interact` (portal,
## hub_sign, story_sign, npc) kiểm tra cờ này để không kích hoạt trùng.
var is_open: bool:
	get:
		return _open or Time.get_ticks_msec() - _closed_at_ms < REOPEN_COOLDOWN_MS

var _open: bool = false
var _closed_at_ms: int = -REOPEN_COOLDOWN_MS
var _lines: PackedStringArray = []
var _index: int = 0
## Tween fade hiện tại — phải kill trước khi tạo tween mới, nếu không tween đóng cũ
## (fade về 0 rồi ẩn panel) vẫn chạy song song và giấu mất hộp vừa mở.
var _tween: Tween

@onready var _panel: Control = $Panel
@onready var _speaker_label: Label = $Panel/Margin/VBox/Speaker
@onready var _body_label: Label = $Panel/Margin/VBox/Body

func _ready() -> void:
	layer = 90
	_panel.visible = false
	_panel.modulate.a = 0.0

## Trả về false nếu không mở được (đang mở sẵn / vừa đóng / không có dòng nào) — một hộp
## thoại tại một thời điểm, người gọi dựa vào đó để không tự coi mình là "đang nói".
func open(lines: PackedStringArray, speaker: String = "") -> bool:
	if is_open or lines.is_empty():
		return false
	_open = true
	_lines = lines
	_index = 0
	_speaker_label.text = speaker
	_speaker_label.visible = speaker != ""
	_body_label.text = _lines[0]
	_panel.visible = true
	_fade_to(1.0)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
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
	_open = false
	_closed_at_ms = Time.get_ticks_msec()
	_fade_to(0.0)
	finished.emit()

func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", alpha, 0.15)
	if alpha == 0.0:
		_tween.tween_callback(func() -> void: _panel.visible = false)
