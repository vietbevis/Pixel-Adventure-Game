extends SceneTree
## Chạy: $GODOT --headless --path . --script res://tests/test_settings_ai.gd

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
	var gemini: Node = root.get_node("Gemini")
	gemini.configure("")
	var menu: Control = load("res://ui/settings_menu/settings_menu.tscn").instantiate()
	root.add_child(menu)
	var button: Button = menu.get_node("CenterContainer/DialogPanel/VBoxContainer/AiRow/AiButton")
	check(button.disabled and button.text == "Chưa có key", "no key -> disabled")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	menu._refresh_ai()
	check(not button.disabled and button.text == "Bật", "key + on -> Bật")
	gemini._user_enabled = false
	gemini._refresh_enabled()
	menu._refresh_ai()
	check(button.text == "Tắt", "user off -> Tắt")

	menu.queue_free()
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
