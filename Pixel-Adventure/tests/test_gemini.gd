extends SceneTree
## Test client Gemini không cần mạng: thay `transport` bằng hàm giả.
## Chạy: $GODOT --headless --path . --script res://tests/test_gemini.gd

const GeminiScript := preload("res://addons/gemini/gemini.gd")

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


static func ok_body(text: String, finish := "STOP") -> String:
	return JSON.stringify({"candidates": [{"content": {"role": "model", "parts": [{"text": text}]}, "finishReason": finish}]})


func fake(code: int, body: String, ok := true) -> Callable:
	return func(url: String, headers: PackedStringArray, body_json: String, timeout: float) -> Dictionary:
		calls.append({"url": url, "headers": headers, "body": body_json, "timeout": timeout})
		return {"ok": ok, "code": code, "body": body}


func slow_fake(text: String) -> Callable:
	return func(url: String, headers: PackedStringArray, body_json: String, timeout: float) -> Dictionary:
		calls.append({"url": url, "headers": headers, "body": body_json, "timeout": timeout})
		await create_timer(0.05).timeout
		return {"ok": true, "code": 200, "body": ok_body(text)}


## Client mới, tách khỏi autoload thật: key giả, bật sẵn, cache rỗng.
func make_client(key := "test-key") -> Node:
	var g: Node = GeminiScript.new()
	root.add_child(g)
	g.configure(key, "test-model")
	g._user_enabled = true
	g._refresh_enabled()
	g._cache = {}
	calls = []
	return g


func _run() -> void:
	await test_no_key()
	await test_text_ok_and_request_shape()
	await test_json_ok()
	await test_json_invalid()
	await test_quota_cooldown()
	await test_forbidden_disables_session()
	await test_network_failure()
	await test_safety_block()
	await test_cache()
	await test_chat_roles()
	await test_in_flight_limit()
	test_clean_text()
	test_process_always()
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


func test_no_key() -> void:
	var g := make_client("")
	g.transport = fake(200, ok_body("x"))
	check(not g.enabled, "no key -> disabled")
	check(await g.generate_text("hi") == "", "no key -> generate_text returns empty")
	check(await g.generate_json("hi", {"type": "OBJECT"}) == null, "no key -> generate_json returns null")
	check(calls.is_empty(), "no key -> transport never called")
	g.queue_free()


func test_text_ok_and_request_shape() -> void:
	var g := make_client()
	g.transport = fake(200, ok_body("**Chào** bạn\n\n  nhé"))
	var text: String = await g.generate_text("hello", {"system": "SYS", "max_tokens": 50, "timeout": 3.0})
	check(text == "Chào bạn nhé", "text parsed and cleaned (got '%s')" % text)
	check(calls.size() == 1, "one request sent")
	var c: Dictionary = calls[0]
	check(String(c.url).ends_with("/models/test-model:generateContent"), "url uses model")
	check(not String(c.url).contains("test-key"), "key not in url")
	check("x-goog-api-key: test-key" in c.headers, "key sent in header")
	check(is_equal_approx(c.timeout, 3.0), "timeout passed to transport")
	var body: Dictionary = JSON.parse_string(c.body)
	check(body.systemInstruction.parts[0].text == "SYS", "system instruction sent")
	check(int(body.generationConfig.maxOutputTokens) == 50, "max tokens sent")
	check(body.contents[0].role == "user" and body.contents[0].parts[0].text == "hello", "prompt sent as user turn")
	g.queue_free()


func test_json_ok() -> void:
	var g := make_client()
	g.transport = fake(200, ok_body("{\"a\": 1, \"b\": [\"x\"]}"))
	var schema := {"type": "OBJECT", "properties": {"a": {"type": "INTEGER"}}}
	var data: Variant = await g.generate_json("p", schema)
	check(data is Dictionary and int(data.a) == 1, "json parsed")
	var body: Dictionary = JSON.parse_string(calls[0].body)
	check(body.generationConfig.responseMimeType == "application/json", "json mime type sent")
	check(body.generationConfig.responseSchema.type == "OBJECT", "schema sent")
	g.queue_free()


func test_json_invalid() -> void:
	var g := make_client()
	g.transport = fake(200, ok_body("not json {"))
	check(await g.generate_json("p", {"type": "OBJECT"}) == null, "invalid json -> null")
	g.queue_free()


func test_quota_cooldown() -> void:
	var g := make_client()
	g.transport = fake(429, "{}")
	check(await g.generate_text("a") == "", "429 -> empty")
	g.transport = fake(200, ok_body("ok"))
	calls = []
	check(await g.generate_text("b") == "", "during cooldown -> empty")
	check(calls.is_empty(), "during cooldown -> no request")
	check(g.enabled, "429 keeps AI enabled")
	g.queue_free()


func test_forbidden_disables_session() -> void:
	var g := make_client()
	g.transport = fake(403, "{}")
	check(await g.generate_text("a") == "", "403 -> empty")
	check(not g.enabled, "403 -> disabled for session")
	g.queue_free()


func test_network_failure() -> void:
	var g := make_client()
	g.transport = fake(0, "", false)
	check(await g.generate_text("a") == "", "network failure/timeout -> empty")
	check(g.enabled, "network failure keeps AI enabled")
	g.queue_free()


func test_safety_block() -> void:
	var g := make_client()
	g.transport = fake(200, ok_body("bad", "SAFETY"))
	check(await g.generate_text("a") == "", "SAFETY finish -> empty")
	g.transport = fake(200, JSON.stringify({"promptFeedback": {"blockReason": "SAFETY"}}))
	check(await g.generate_text("a") == "", "no candidates -> empty")
	g.queue_free()


func test_cache() -> void:
	var g := make_client()
	g.transport = fake(200, ok_body("one"))
	check(await g.generate_text("a", {"cache_key": "k"}) == "one", "first call fills cache")
	g.transport = fake(200, ok_body("two"))
	calls = []
	check(await g.generate_text("a", {"cache_key": "k"}) == "one", "second call served from cache")
	check(calls.is_empty(), "cache hit -> no request")
	check(g.cache_age("k") < 5.0, "cache_age is recent")
	check(g.cache_age("missing") == INF, "cache_age missing -> INF")
	check(await g.generate_text("a", {"cache_key": "k", "refresh": true}) == "two", "refresh bypasses cache")
	g.queue_free()


func test_chat_roles() -> void:
	var g := make_client()
	g.transport = fake(200, ok_body("reply"))
	var history := [{"role": "user", "text": "q1"}, {"role": "model", "text": "a1"}, {"role": "user", "text": "q2"}]
	check(await g.chat(history, {"system": "S"}) == "reply", "chat returns text")
	var body: Dictionary = JSON.parse_string(calls[0].body)
	check(body.contents.size() == 3 and body.contents[1].role == "model", "chat roles kept")
	g.queue_free()


func test_in_flight_limit() -> void:
	var g := make_client()
	g.transport = slow_fake("slow")
	g.generate_text("1")
	g.generate_text("2")
	var third: String = await g.generate_text("3")
	check(third == "", "3rd concurrent request rejected")
	check(calls.size() == 2, "only 2 requests in flight")
	await create_timer(0.1).timeout
	g.queue_free()


func test_clean_text() -> void:
	check(GeminiScript.clean_text("  # Tiêu đề\n`code` **đậm**  ") == "Tiêu đề code đậm", "clean_text strips markdown")
	check(GeminiScript.clean_text("\"trích dẫn\"") == "trích dẫn", "clean_text strips wrapping quotes")


func test_process_always() -> void:
	var g := make_client()
	check(g.process_mode == Node.PROCESS_MODE_ALWAYS, "client runs while tree is paused")
	g.queue_free()
