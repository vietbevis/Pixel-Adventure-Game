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

	print("ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
