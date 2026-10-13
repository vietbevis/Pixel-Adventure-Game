extends SceneTree
## Chạy: tests/run_tests.sh tests/test_pause_settings.gd
## Nút "Cài đặt" trong menu pause mở màn Cài đặt dạng lớp phủ (game vẫn dừng),
## "Quay lại" đóng lớp phủ và trả về menu pause thay vì đổi sang main menu.

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
	paused = true
	var pause: CanvasLayer = load("res://ui/pause_menu/pause_menu.tscn").instantiate()
	root.add_child(pause)
	await process_frame
	var panel: Control = pause.get_node("Root/CenterContainer/Panel")
	var settings_button: Button = pause.get_node("Root/CenterContainer/Panel/VBoxContainer/SettingsButton")

	settings_button.pressed.emit()
	await process_frame
	var overlay: Control = pause.get_node_or_null("Root/SettingsMenu")
	check(overlay != null, "settings button -> settings overlay opens")
	check(not panel.visible, "pause panel hidden behind settings")
	check(paused, "game stays paused")
	check(overlay != null and not overlay.get_node("Background").visible, "overlay has no opaque background")
	check(overlay != null and overlay.can_process(), "overlay works while tree paused")

	if overlay:
		overlay.get_node("CenterContainer/DialogPanel/VBoxContainer/BackButton").pressed.emit()
	await process_frame
	check(pause.get_node_or_null("Root/SettingsMenu") == null, "back -> overlay closed")
	check(panel.visible, "back -> pause panel shows again")
	check(current_scene == null or current_scene.scene_file_path != "res://ui/main_menu/main_menu.tscn", "back does not leave the level")

	paused = false
	print("ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
