extends CanvasLayer
## Autoload `AiChat`: khung trò chuyện với NPC bằng Gemini. NPC gọi `AiChat.open(...)` khi
## có persona và `Gemini.enabled`; ngược lại NPC dùng `Dialogue` như cũ.
##
## Lúc mở: `get_tree().paused = true` — phím gõ vào ô chat vẫn cập nhật `Input`, nếu không
## pause thì player (poll Input trong _physics_process) sẽ chạy/nhảy theo. Node này và
## autoload Gemini đều `PROCESS_MODE_ALWAYS` nên nút bấm + HTTP vẫn chạy khi pause.
##
## UI dựng bằng code, neo ở nửa TRÊN màn hình để bàn phím ảo Android không che ô nhập.
## Lời chào của NPC không vào `_history` (Gemini cần lượt đầu là "user") — NPC đưa nó vào
## system prompt.

signal closed

## Giống Dialogue: sau khi đóng, chặn mở lại trong khoảng này để cú nhấn đóng không bị
## NPC/portal bên cạnh bắt lại.
const REOPEN_COOLDOWN_MS := 200
const MAX_INPUT := 120
## Số mục lịch sử gửi lên (6 cặp hỏi-đáp).
const MAX_HISTORY := 12
const PRESET_QUESTIONS: Array[String] = [
	"Tôi nên đi đâu tiếp?",
	"Kể về vùng đất này đi.",
	"Ở đây có bí mật gì không?",
]
const FALLBACK_REPLY := "…(gãi đầu) Ta không nhớ ra. Ngài hỏi lại sau nhé."
## Luật chung nối vào cuối system prompt của mọi NPC.
const RULES := "Luật: luôn nhập vai nhân vật trên và trả lời bằng tiếng Việt, tối đa 2 câu ngắn (dưới 200 ký tự). Chỉ nói về thế giới trong game; không bịa ra phần thưởng, vật phẩm, nhân vật hay cơ chế không có trong bối cảnh ở trên. Nếu bị hỏi chuyện ngoài thế giới game (đời thực, lập trình, chính trị...) thì từ chối khéo đúng giọng nhân vật. Không dùng markdown, không dùng emoji."

var is_open: bool:
	get:
		return _open or Time.get_ticks_msec() - _closed_at_ms < REOPEN_COOLDOWN_MS
## true trong lúc chờ Gemini trả lời — khoá nút gửi để không bắn nhiều request.
var is_waiting: bool = false

var _open := false
var _closed_at_ms := -REOPEN_COOLDOWN_MS
var _system := ""
var _history: Array = []
## Tăng mỗi lần mở/đóng; câu trả lời về muộn của phiên cũ bị bỏ.
var _session := 0

var _panel: PanelContainer
var _speaker_label: Label
var _body_label: Label
var _input: LineEdit
var _send_button: Button
var _preset_buttons: Array[Button] = []


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


## Trả về false nếu không mở được (AI tắt / đang có hộp thoại khác / vừa đóng).
func open(speaker: String, greeting: String, system: String) -> bool:
	if not Gemini.enabled or Dialogue.is_open:
		return false
	_open = true
	_session += 1
	_system = system
	_history = []
	_speaker_label.text = speaker
	_body_label.text = greeting
	_input.clear()
	_set_waiting(false)
	_panel.visible = true
	get_tree().paused = true
	# Trên điện thoại focus sẽ bật bàn phím che mất câu chào — để người chơi tự chạm.
	if not DisplayServer.is_touchscreen_available():
		_input.grab_focus()
	return true


## Gửi một câu hỏi. Bỏ qua nếu đang chờ, chưa mở, hoặc câu rỗng.
func ask(question: String) -> void:
	var q := question.strip_edges().left(MAX_INPUT)
	if not _open or is_waiting or q == "":
		return
	var session := _session
	_history.append({"role": "user", "text": q})
	_input.clear()
	_body_label.text = "…"
	_set_waiting(true)
	var reply: String = await Gemini.chat(_recent_history(), {"system": _system, "max_tokens": 150})
	if session != _session:
		return  # đã đóng (hoặc mở phiên mới) trong lúc chờ
	if reply == "":
		_history.pop_back()  # giữ lịch sử xen kẽ user/model
		reply = FALLBACK_REPLY
	else:
		_history.append({"role": "model", "text": reply})
	_body_label.text = reply
	_set_waiting(false)


func close() -> void:
	if not _open:
		return
	_open = false
	_session += 1
	_closed_at_ms = Time.get_ticks_msec()
	_set_waiting(false)
	_input.release_focus()
	_panel.visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _recent_history() -> Array:
	var h := _history.slice(-MAX_HISTORY)
	while not h.is_empty() and h[0].role != "user":
		h.pop_front()
	return h


func _set_waiting(waiting: bool) -> void:
	is_waiting = waiting
	_send_button.disabled = waiting
	_input.editable = not waiting
	for b in _preset_buttons:
		b.disabled = waiting


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.13, 0.96)
	style.border_color = Color(0.85, 0.78, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 40.0
	_panel.offset_right = -40.0
	_panel.offset_top = 20.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	_speaker_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(0, 48)
	_body_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_body_label)

	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	vbox.add_child(presets)
	for q in PRESET_QUESTIONS:
		var b := Button.new()
		b.text = q
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(ask.bind(q))
		presets.add_child(b)
		_preset_buttons.append(b)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Hỏi điều gì đó…"
	_input.max_length = MAX_INPUT
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(ask)
	row.add_child(_input)
	_send_button = Button.new()
	_send_button.text = "Gửi"
	_send_button.focus_mode = Control.FOCUS_NONE
	_send_button.pressed.connect(func() -> void: ask(_input.text))
	row.add_child(_send_button)

	var bye := Button.new()
	bye.text = "Tạm biệt"
	bye.focus_mode = Control.FOCUS_NONE
	bye.size_flags_horizontal = Control.SIZE_SHRINK_END
	bye.pressed.connect(close)
	vbox.add_child(bye)
