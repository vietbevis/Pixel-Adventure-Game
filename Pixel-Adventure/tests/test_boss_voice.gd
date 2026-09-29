extends SceneTree
## Chạy: tests/run_tests.sh tests/test_boss_voice.gd
## Sao lưu + khôi phục user://save_data.json vì BossVoice ghi số lần đánh boss.

var _fails := 0
var calls := 0
var last_timeout := 0.0
var _save_backup := ""
var _had_save := false


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


const AI := "{\"intro\": \"AI intro\", \"phase_2\": \"AI giận\", \"player_died\": \"AI cười\", \"defeated\": \"AI thua\"}"


func _run() -> void:
	_had_save = FileAccess.file_exists("user://save_data.json")
	if _had_save:
		_save_backup = FileAccess.get_file_as_string("user://save_data.json")
	var gemini: Node = root.get_node("Gemini")
	var voice: Node = root.get_node("BossVoice")
	var events: Node = root.get_node("Events")
	var save: Node = root.get_node("SaveManager")
	var label: Label = voice._label

	var base: Dictionary = voice.fallback_lines("forest_boss")
	check(base.intro != "" and base.defeated != "", "fallback lines for King Pig")
	check(voice.fallback_lines("unknown").intro != "", "generic fallback for unknown boss")
	var merged: Dictionary = voice.merge(base, {"intro": "Mới", "phase_2": "x".repeat(120), "defeated": ""})
	check(merged.intro == "Mới" and merged.phase_2 == base.phase_2 and merged.defeated == base.defeated, "merge keeps valid AI lines only")
	check(voice.merge(base, "rác").intro == base.intro, "non-dict AI output -> fallback")

	var before: int = save.get_boss_attempts("forest_boss")
	gemini.configure("")
	events.boss_intro.emit("forest_boss", "VUA HEO")
	await wait_ms(100)
	check(label.text == base.intro, "AI off -> static intro right away")
	check(save.get_boss_attempts("forest_boss") == before + 1, "attempt counted")
	check(voice.build_prompt("forest_boss", "VUA HEO", 3).contains("lần thứ 3"), "prompt mentions attempt count")

	events.player_died.emit()
	await wait_ms(50)
	check(label.text == base.intro, "player_died with no boss in tree -> ignored")

	var boss := Node.new()
	boss.add_to_group("boss")
	root.add_child(boss)
	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	gemini.transport = fake(AI)
	events.boss_intro.emit("forest_boss", "VUA HEO")
	await wait_ms(200)
	check(label.text == "AI intro", "AI on -> AI intro")
	check(last_timeout >= 15.0, "boss request runs in background with 15s timeout")
	events.boss_phase_changed.emit(2)
	check(label.text == "AI giận", "phase 2 line")
	label.text = ""
	events.boss_phase_changed.emit(3)
	check(label.text == "", "phase line only once per fight")
	events.player_died.emit()
	check(label.text == "AI cười", "player died line during fight")
	events.boss_defeated.emit("forest_boss")
	check(label.text == "AI thua", "defeated line")

	# Trận trước về muộn không được ghi đè trận sau.
	gemini.transport = fake("{\"intro\": \"CŨ\", \"phase_2\": \"CŨ\", \"player_died\": \"CŨ\", \"defeated\": \"CŨ\"}", 400)
	events.boss_intro.emit("forest_boss", "VUA HEO")
	await wait_ms(50)
	gemini.transport = fake(AI)
	events.boss_intro.emit("dungeon_boss", "CAI NGỤC")
	await wait_ms(900)
	events.player_died.emit()
	check(label.text == "AI cười", "late reply of an older fight ignored")

	boss.queue_free()
	if _had_save:
		var f := FileAccess.open("user://save_data.json", FileAccess.WRITE)
		f.store_string(_save_backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_data.json"))
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
