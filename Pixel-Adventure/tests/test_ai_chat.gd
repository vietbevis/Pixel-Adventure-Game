extends SceneTree
## Chạy: $GODOT --headless --path . --script res://tests/test_ai_chat.gd

var _fails := 0
var calls: Array = []


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


func fake(code: int, text: String, delay := 0.0) -> Callable:
	return func(_u: String, _h: PackedStringArray, body: String, _t: float) -> Dictionary:
		calls.append(JSON.parse_string(body))
		if delay > 0.0:
			await create_timer(delay).timeout
		return {"ok": true, "code": code, "body": ok_body(text)}


## Chờ theo thời gian THỰC: cooldown của Dialogue/AiChat tính bằng Time.get_ticks_msec(), còn
## create_timer() đếm theo delta — frame đầu headless có delta lớn nên timer về sớm.
func wait_ms(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame


func _run() -> void:
	var gemini: Node = root.get_node("Gemini")
	var chat: Node = root.get_node("AiChat")
	var dialogue: Node = root.get_node("Dialogue")

	gemini.configure("")
	check(not chat.open("Cố vấn", "Xin chào", "SYS"), "AI off -> open refused")
	check(not paused, "AI off -> tree not paused")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	gemini.transport = fake(200, "Ngài hãy tới Rừng Ranh Giới.")
	calls = []

	check(chat.open("Cố vấn", "Xin chào ngài", "SYS"), "open ok")
	check(paused, "open pauses tree")
	check(chat.is_open and dialogue.is_open, "AiChat and Dialogue report open")
	check(not chat.open("Khác", "x", "y"), "second open refused")
	check(not dialogue.open(PackedStringArray(["x"]), "y"), "Dialogue refuses while AiChat open")
	check(chat._body_label.text == "Xin chào ngài", "greeting shown immediately")

	await chat.ask("   ")
	check(calls.is_empty(), "blank question ignored")

	await chat.ask("Tôi nên đi đâu?")
	check(calls.size() == 1, "one request")
	check(chat._body_label.text == "Ngài hãy tới Rừng Ranh Giới.", "reply shown")
	check(calls[0].systemInstruction.parts[0].text == "SYS", "system prompt sent")
	check(calls[0].contents[0].role == "user" and calls[0].contents[0].parts[0].text == "Tôi nên đi đâu?", "history starts with user question")
	check(chat._history.size() == 2, "history has question + reply")

	# Review Focus #3: bấm liên tục khi đang chờ -> một request.
	gemini.transport = fake(200, "Trả lời chậm", 0.1)
	calls = []
	chat.ask("Câu 1")
	chat.ask("Câu 2")
	check(chat.is_waiting, "waiting while request in flight")
	await create_timer(0.2).timeout
	check(calls.size() == 1, "spam while waiting -> single request")
	check(chat._history.size() == 4, "history alternates correctly")

	# Review Focus #4: lỗi server -> câu dự phòng, không thêm câu hỏi hỏng vào lịch sử.
	gemini.transport = fake(500, "x")
	await chat.ask("Câu 3")
	check(chat._body_label.text == chat.FALLBACK_REPLY, "error -> fallback reply")
	check(chat._history.size() == 4, "failed question dropped from history")
	check(not chat.is_waiting, "not waiting after error")

	# AI lỗi (mất mạng, 5xx, hết quota) -> nói lần lượt thoại tĩnh NPC truyền vào, để mất mạng
	# không làm mất thông tin (mục tiêu kế tiếp...) như khi chơi không có AI.
	chat.close()
	await wait_ms(250)
	check(chat.open("Cố vấn", "Chào", "SYS", PackedStringArray(["Dòng A", "Dòng B"])), "open with static fallback lines")
	await chat.ask("q1")
	check(chat._body_label.text == "Dòng A", "error -> first static line")
	await chat.ask("q2")
	check(chat._body_label.text == "Dòng B", "error again -> next static line")
	await chat.ask("q3")
	check(chat._body_label.text == "Dòng A", "static lines cycle")

	# Câu hỏi dài bị cắt.
	gemini.transport = fake(200, "ok")
	calls = []
	await chat.ask("a".repeat(300))
	check(String(calls[0].contents[-1].parts[0].text).length() == chat.MAX_INPUT, "question truncated to MAX_INPUT")

	# Review Focus #5: đóng -> bỏ pause, cooldown chặn mở lại ngay.
	var closed := [false]
	chat.closed.connect(func() -> void: closed[0] = true, CONNECT_ONE_SHOT)
	chat.close()
	check(closed[0], "closed emitted")
	check(not paused, "close unpauses tree")
	check(chat.is_open and dialogue.is_open, "cooldown right after close")
	await wait_ms(250)
	check(not chat.is_open and not dialogue.is_open, "cooldown over")

	# Đóng khi request đang bay -> trả lời về muộn bị bỏ qua.
	gemini.transport = fake(200, "muộn", 0.1)
	chat.open("Cố vấn", "Chào", "SYS")
	chat.ask("hỏi")
	chat.close()
	await create_timer(0.2).timeout
	check(not paused and not chat._open, "late reply after close ignored")

	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
