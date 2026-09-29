extends SceneTree
## Chạy: $GODOT --headless --path . --script res://tests/test_npc_ai.gd

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS ", name)
	else:
		_fails += 1
		printerr("FAIL ", name)


func make_npc(persona: String) -> Node:
	var holder := Node2D.new()
	root.add_child(holder)
	var npc: Node = load("res://objects/npc/npc.tscn").instantiate()
	npc.speaker = "Cố vấn"
	npc.line_1 = "Mừng ngài trở về."
	npc.ai_persona = persona
	npc.process_mode = Node.PROCESS_MODE_DISABLED  # không có player trong test
	holder.add_child(npc)
	return npc


func reset_dialogs(chat: Node, dialogue: Node) -> void:
	chat.close()
	if dialogue._open:
		dialogue._close()
	await wait_ms(250)


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

	var npc := make_npc("Cố vấn già trung thành.")

	gemini.configure("")
	check(npc._open_conversation(), "AI off -> conversation opens")
	check(dialogue._open and not chat._open, "AI off -> static Dialogue used (no regression)")
	await reset_dialogs(chat, dialogue)

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	check(npc._open_conversation(), "AI on -> conversation opens")
	check(chat._open and not dialogue._open, "AI on + persona -> AiChat used")
	check(chat._body_label.text == "Mừng ngài trở về.", "greeting = line_1")
	var sys: String = chat._system
	check(sys.contains("Cố vấn già trung thành."), "system prompt has persona")
	check(sys.contains(String(root.get_node("Progression").next_objective()["text"])), "system prompt has objective")
	check(sys.contains(chat.RULES), "system prompt has shared rules")
	await reset_dialogs(chat, dialogue)

	var plain := make_npc("")
	check(plain._open_conversation() and dialogue._open and not chat._open, "no persona -> Dialogue even with AI on")
	await reset_dialogs(chat, dialogue)

	# Bong bóng thu về + lòng tin khi đóng chat: NPC phải nghe AiChat.closed.
	npc._talking = true
	chat.open("Cố vấn", "x", "y")
	chat.close()
	check(not npc._talking, "AiChat.closed ends NPC talking state")

	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
