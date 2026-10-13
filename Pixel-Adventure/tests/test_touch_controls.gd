extends SceneTree
## Chạy: tests/run_tests.sh tests/test_touch_controls.gd
## Hồi quy: mở khoá Lướt giữa màn thì nút Dash phải hiện ngay, không đợi vào lại màn.

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS ", name)
	else:
		_fails += 1
		printerr("FAIL ", name)


func _touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	root.push_input(e, true)
	await process_frame


func _drag(pos: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	root.push_input(e, true)
	await process_frame


func _axis() -> float:
	return Input.get_axis("move_left", "move_right")


## Joystick thay 2 nút trái/phải: kéo ngang → chạy, kéo ít → đi chậm, nhả → dừng.
## (MobileScale = 1 khi chạy test nên toạ độ layer = toạ độ viewport.)
func _test_joystick(touch: CanvasLayer) -> void:
	check(not touch.has_node("BtnLeft") and not touch.has_node("BtnRight"), "left/right buttons replaced by the joystick")
	var stick = touch.get_node("Joystick")
	var start: Vector2 = stick.zone.get_center()
	check(stick.zone.has_area() and stick.zone.position.x == 0.0, "joystick zone sits on the left of the screen")

	await _touch(start, true)
	check(stick.is_active() and is_zero_approx(_axis()), "thumb down without dragging -> no movement")
	await _drag(start + Vector2(stick.radius * 0.9, 0))
	check(is_equal_approx(_axis(), 1.0), "drag right far -> full speed right (%.2f)" % _axis())
	await _drag(start + Vector2(-stick.radius * 3.0, 0))
	check(is_equal_approx(_axis(), -1.0), "drag left past the rim -> full speed left (%.2f)" % _axis())
	await _drag(start + Vector2(stick.radius * 0.3, 0))
	check(_axis() > 0.0 and _axis() < 1.0, "small drag -> slower walk (%.2f)" % _axis())
	await _drag(start + Vector2(stick.radius * 0.1, stick.radius * 0.8))
	check(is_zero_approx(_axis()), "dragging straight down -> no sideways movement")
	await _touch(start, false)
	check(not stick.is_active() and is_zero_approx(_axis()), "release -> stop")

	var right_side: Vector2 = Vector2(stick.zone.end.x + 50.0, start.y)
	await _touch(right_side, true, 1)
	await _drag(right_side + Vector2(stick.radius, 0), 1)
	check(not stick.is_active() and is_zero_approx(_axis()), "touch outside the zone (jump side) ignores the joystick")
	await _touch(right_side, false, 1)

	# Pause / chuyển màn khi đang giữ: lần nhả tay không tới được, phải tự nhả.
	await _touch(start, true)
	await _drag(start + Vector2(stick.radius, 0))
	stick.notification(Node.NOTIFICATION_PAUSED)
	check(not stick.is_active() and is_zero_approx(_axis()), "pausing while held releases the movement")
	await _touch(start, false)

	touch.visible = false
	await _touch(start, true)
	check(not stick.is_active(), "hidden touch controls ignore touches")
	await _touch(start, false)


func _run() -> void:
	var events: Node = root.get_node("Events")
	var touch: CanvasLayer = load("res://ui/touch_controls/touch_controls.tscn").instantiate()
	root.add_child(touch)
	await process_frame
	var dash: Node2D = touch.get_node("BtnDash")
	dash.visible = false  # như lúc vào màn khi chưa có Lướt (không đụng file save thật)

	events.ability_unlocked.emit("double_jump")
	check(not dash.visible, "other ability -> dash button stays hidden")
	events.ability_unlocked.emit("dash")
	check(dash.visible, "dash unlocked mid-level -> dash button shows at once")

	# Đổi "Nút cảm ứng" trong Cài đặt (mở từ menu pause) áp dụng ngay, không đợi vào lại màn.
	events.setting_changed.emit("touch_controls", "off")
	check(not touch.visible, "touch setting off mid-level -> controls hide at once")
	events.setting_changed.emit("touch_controls", "on")
	check(touch.visible, "touch setting on mid-level -> controls show at once")

	await _test_joystick(touch)

	print("ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
