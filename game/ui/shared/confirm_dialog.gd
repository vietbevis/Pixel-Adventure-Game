class_name ConfirmDialog
extends CanvasLayer
## Hộp xác nhận dùng chung cho hành động khó hoàn tác (Thoát, Chơi lại, Về Hub...).
##   var d := ConfirmDialog.show_confirm(self, "Thoát game?", "Thoát", "Ở lại")
##   d.confirmed.connect(func() -> void: get_tree().quit())
## Tự huỷ khi chọn xong. process_mode = ALWAYS để dùng được cả khi cây bị pause.

signal confirmed
signal cancelled

const _PRIMARY := &"PrimaryButton"

static func show_confirm(parent: Node, message: String, ok_text := "Đồng ý", cancel_text := "Huỷ") -> ConfirmDialog:
	var d := ConfirmDialog.new()
	d._message = message
	d._ok_text = ok_text
	d._cancel_text = cancel_text
	parent.add_child(d)
	return d

var _message: String = ""
var _ok_text: String = "Đồng ý"
var _cancel_text: String = "Huỷ"

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DialogPanel"
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(320, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var label := Label.new()
	label.text = _message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var cancel_btn := Button.new()
	cancel_btn.text = _cancel_text
	cancel_btn.custom_minimum_size = Vector2(140, 44)
	cancel_btn.pressed.connect(_dismiss.bind(false))
	row.add_child(cancel_btn)

	var ok_btn := Button.new()
	ok_btn.theme_type_variation = _PRIMARY
	ok_btn.text = _ok_text
	ok_btn.custom_minimum_size = Vector2(140, 44)
	ok_btn.pressed.connect(_dismiss.bind(true))
	row.add_child(ok_btn)

	cancel_btn.grab_focus()

func _dismiss(ok: bool) -> void:
	if ok:
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss(false)
