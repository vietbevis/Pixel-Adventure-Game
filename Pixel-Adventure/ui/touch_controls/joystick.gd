class_name TouchJoystick
extends Node2D
## Joystick trái/phải cho mobile, thay 2 nút ◀ ▶. Joystick "nổi": đặt ngón cái xuống bất
## kỳ đâu trong `zone` (góc dưới-trái, do touch_controls._layout đặt) thì đế dời tới chỗ
## đó, kéo ngang để chạy — không phải nhìn xuống tìm đúng nút. Nhả tay → về chỗ nghỉ.
## Bấm `move_left`/`move_right` qua Input.action_press (có strength) nên player.gd đọc
## bằng get_axis như bàn phím, không cần biết gì về cảm ứng.

const LEFT := &"move_left"
const RIGHT := &"move_right"

## Bán kính đế và núm (px, cùng hệ toạ độ với các nút cảm ứng).
@export var radius := 90.0
@export var knob_radius := 40.0
## Lệch ngang dưới ngưỡng này (tỉ lệ bán kính) coi như đứng yên — tránh trôi khi chỉ
## đặt ngón cái lên mà chưa kéo.
@export var deadzone := 0.2
## Lệch tới mức này là chạy hết tốc; giữa deadzone và đây thì đi chậm dần (căn mép vực).
@export var full_at := 0.6
@export var min_strength := 0.35

## Vùng nhận chạm, toạ độ của node cha (CanvasLayer TouchControls).
var zone := Rect2()

var _finger := -1
var _base := Vector2.ZERO   # tâm đế, toạ độ local (ZERO = chỗ nghỉ)
var _knob := Vector2.ZERO   # độ lệch núm so với tâm đế, |_knob| <= radius


func _notification(what: int) -> void:
	# Chuyển màn / mở pause / ẩn nút khi đang giữ joystick: lần nhả tay sẽ không tới
	# (_input không chạy lúc pause), nên phải tự nhả, không thì nhân vật cứ chạy mãi.
	match what:
		NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE, NOTIFICATION_VISIBILITY_CHANGED:
			_reset()


func is_active() -> bool:
	return _finger != -1


func _input(event: InputEvent) -> void:
	var layer := get_parent() as CanvasLayer
	if not is_visible_in_tree() or (layer and not layer.visible):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1:
			var p := _parent_pos(touch)
			if not zone.has_point(p):
				return
			_finger = touch.index
			_base = p - position
			_move_to(p)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _finger:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _finger:
		_move_to(_parent_pos(event))
		get_viewport().set_input_as_handled()


## Toạ độ chạm trong hệ của node cha (layer đã bị scale theo MobileScale).
func _parent_pos(event: InputEvent) -> Vector2:
	return position + (make_input_local(event) as InputEventFromWindow).position


func _move_to(parent_pos: Vector2) -> void:
	_knob = (parent_pos - position - _base).limit_length(radius)
	_apply(_knob.x / radius)
	queue_redraw()


func _apply(x: float) -> void:
	var a := absf(x)
	if a < deadzone:
		Input.action_release(LEFT)
		Input.action_release(RIGHT)
		return
	var strength := clampf(remap(a, deadzone, full_at, min_strength, 1.0), min_strength, 1.0)
	Input.action_press(RIGHT if x > 0.0 else LEFT, strength)
	Input.action_release(LEFT if x > 0.0 else RIGHT)


func _reset() -> void:
	if _finger == -1 and _knob == Vector2.ZERO:
		return
	_finger = -1
	_base = Vector2.ZERO
	_knob = Vector2.ZERO
	Input.action_release(LEFT)
	Input.action_release(RIGHT)
	queue_redraw()


func _draw() -> void:
	# Cùng tông xám trong + viền trắng như các nút sprite bên phải.
	var a := 1.0 if is_active() else 0.6
	draw_circle(_base, radius, Color(0.55, 0.55, 0.55, 0.35 * a))
	draw_arc(_base, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.55 * a), 4.0, true)
	# Mũi tên gợi ý chỉ kéo ngang.
	var t := radius * 0.72
	for s: float in [-1.0, 1.0]:
		var tip := _base + Vector2(s * (t + 12.0), 0.0)
		draw_colored_polygon(PackedVector2Array([
			tip, _base + Vector2(s * t, -12.0), _base + Vector2(s * t, 12.0)]),
			Color(1, 1, 1, 0.7 * a))
	draw_circle(_base + _knob, knob_radius, Color(0.85, 0.85, 0.85, 0.85 * a))
	draw_arc(_base + _knob, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.9 * a), 3.0, true)
