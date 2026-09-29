extends SceneTree
## Chạy: tests/run_tests.sh tests/test_stuck_helper.gd

var _fails := 0
var calls := 0
var last_timeout := 0.0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS ", name)
	else:
		_fails += 1
		printerr("FAIL ", name)


static func ok_body(text: String) -> String:
	return JSON.stringify({"candidates": [{"content": {"parts": [{"text": text}]}, "finishReason": "STOP"}]})


func fake(text: String, delay_ms := 0) -> Callable:
	return func(_u: String, _h: PackedStringArray, _b: String, t: float) -> Dictionary:
		calls += 1
		last_timeout = t
		if delay_ms > 0:
			await wait_ms(delay_ms)
		return {"ok": true, "code": 200, "body": ok_body(text)}


func wait_ms(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame


func close_dialogue(dialogue: Node) -> void:
	if dialogue._open:
		dialogue._close()
	await wait_ms(250)


func _run() -> void:
	var gemini: Node = root.get_node("Gemini")
	var helper: Node = root.get_node("StuckHelper")
	var events: Node = root.get_node("Events")
	var gm: Node = root.get_node("GameManager")
	var dialogue: Node = root.get_node("Dialogue")
	var notes: GDScript = load("res://core/level_notes.gd")
	var levels: GDScript = load("res://core/levels.gd")

	for lv: Dictionary in levels.LEVELS:
		check(String(notes.tip(lv.id)) != "", "note for %s" % lv.id)

	gemini.configure("")
	gm.current_level_id = "hub"
	for i in 3:
		events.player_died.emit()
	check(helper._deaths == 0, "hub deaths ignored")

	gm.current_level_id = "level_3"
	gm.has_checkpoint = true
	events.player_died.emit()
	events.player_died.emit()
	check(helper._deaths == 2 and not dialogue._open, "two deaths -> no hint yet")
	events.player_died.emit()
	await wait_ms(1000)
	check(dialogue._open and dialogue._speaker_label.text == "Cố vấn", "3rd death + checkpoint -> advisor hint after respawn")
	check(dialogue._body_label.text == notes.tip("level_3"), "AI off -> hand-written level note")
	await close_dialogue(dialogue)

	gm.current_level_id = "level_4"
	events.player_died.emit()
	check(helper._deaths == 1 and helper._level == "level_4", "new level resets the count")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	gemini.transport = fake("Hãy nhảy ngay khi sóng lửa vừa tắt.")
	calls = 0
	events.player_died.emit()
	await wait_ms(100)
	check(calls == 1 and last_timeout >= 15.0 and helper._hint == "Hãy nhảy ngay khi sóng lửa vừa tắt.", "2nd death prefetches AI hint")
	check(helper.build_prompt("level_4", 2).contains(notes.tip("level_4")), "prompt includes level note")
	gm.has_checkpoint = false
	events.player_died.emit()
	await wait_ms(1000)
	check(not dialogue._open and helper._pending, "no checkpoint -> hint waits for the level to reload")
	helper.level_ready()
	await wait_ms(1500)
	check(dialogue._open and dialogue._body_label.text == "Hãy nhảy ngay khi sóng lửa vừa tắt.", "level reload shows the AI hint")
	await close_dialogue(dialogue)
	check(not helper._pending, "hint shown once")

	# Gợi ý của màn cũ về muộn không được gắn vào màn mới.
	gm.current_level_id = "level_5"
	gemini.transport = fake("CŨ", 400)
	events.player_died.emit()
	events.player_died.emit()
	gm.current_level_id = "level_6"
	helper.level_ready()
	await wait_ms(700)
	check(helper._level == "level_6" and helper._hint == "", "late hint of previous level dropped")

	await close_dialogue(dialogue)
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
