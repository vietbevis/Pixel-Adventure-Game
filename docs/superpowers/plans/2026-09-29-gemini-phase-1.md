# Gemini AI — Đợt 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm client Gemini dùng chung cho hai game, công tắc AI trong Cài đặt, "Bình luận viên cuối lượt" cho Temple Run Pro Max (3D) và "NPC trò chuyện AI" cho Pixel Adventure (2D) — mọi thứ tự lùi về hành vi hiện tại khi không có AI.

**Architecture:** Một autoload `Gemini` (`addons/gemini/gemini.gd`, file giống hệt ở hai project) gọi REST `generateContent` qua `HTTPRequest`, có `transport` thay được để test không cần mạng. Tính năng của mỗi game là script riêng gọi `await Gemini...` và luôn có nội dung dự phòng tĩnh. 2D thêm autoload `AiChat` (khung chat dựng bằng code, pause cây scene lúc mở).

**Tech Stack:** Godot 4.7.2 (GDScript, renderer Mobile), Gemini API REST `v1beta`, test headless bằng script `extends SceneTree`.

**Spec:** `docs/superpowers/specs/2026-09-29-gemini-ai-integration-design.md` (có ở cả hai repo)

## Global Constraints

- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot` (không có trên PATH). Trong plan viết tắt là `$GODOT`; đặt `GODOT=/Applications/Godot.app/Contents/MacOS/Godot` trước khi chạy lệnh.
- Workspace: `WS="/Volumes/Data/Downloads/Học liệu/Phát triển game trên android"`. Repo 3D = `$WS/temple-run-pro-max` (root repo = root project). Repo 2D = `$WS/Pixel-Adventure` (root project Godot là thư mục con `$WS/Pixel-Adventure/Pixel-Adventure`). Mọi lệnh 2D chạy trong thư mục project con.
- Sau khi thêm/sửa file có `class_name` hoặc autoload: chạy `$GODOT --headless --path . --import` (≈3 s, tự thoát) trước khi chạy test, để cache global class được cập nhật.
- Test chạy bằng: `$GODOT --headless --path . --script res://tests/<file>.gd`; test in `PASS`/`FAIL` từng dòng, cuối cùng `ALL PASS` và exit code 0, hoặc `N FAILED` và exit code 1.
- API: `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`, header `x-goog-api-key`. Model mặc định `"gemini-2.5-flash-lite"`, đọc đè được từ config.
- Thứ tự tìm key: env `GEMINI_API_KEY` → `user://gemini.cfg` → `res://gemini.local.cfg` (gitignored). Section `[gemini]`, khoá `api_key`, `model`.
- Không bao giờ in key ra log, không đặt key trên URL.
- Code 3D: comment tiếng Anh (theo code hiện có). Code 2D và `addons/gemini`: comment tiếng Việt. UI 2D tiếng Việt; UI 3D qua `Loc` (en/vi).
- Không có request mạng nào được `await` trong lúc đang chạy gameplay 3D.
- Commit message kết thúc bằng dòng: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Người chơi bấm "Chạy lại" trước khi bình luận về → bình luận cũ không được ghi đè lên màn Kết quả của lượt mới (Task 4 kiểm `is_same(summary)` + test gọi `_update_commentary` hai lần).
2. Cây scene đang pause (AiChat mở) → request vẫn phải hoàn tất (Task 1 test `process_mode == ALWAYS`; Task 7 test chat trả lời khi `paused == true`).
3. Người chơi bấm Gửi/nút gợi ý liên tục khi đang chờ → chỉ một request, lịch sử không xen kẽ sai (Task 7 test gọi `ask` hai lần liền).
4. Key sai / 403 / hết quota giữa cuộc trò chuyện → NPC nói câu dự phòng, vẫn đóng được, game không kẹt pause (Task 7 test 500 → `FALLBACK_REPLY`, `close()` → `paused == false`).
5. Đóng chat rồi phím E cùng khung hình mở lại hộp thoại → `AiChat.is_open` giữ cooldown 200 ms và `Dialogue.is_open` tính cả AiChat (Task 7 test).

---

## File Structure

**Cả hai project (file giống hệt):**
- `addons/gemini/gemini.gd` — autoload `Gemini`: key/config, bật/tắt, request, parse, cache, xử lý lỗi.
- `tests/test_gemini.gd` — test client với transport giả.
- `gemini.example.cfg` — mẫu cấu hình (không có key).

**3D (`temple-run-pro-max/`):**
- Create `scripts/ai/run_commentary.gd` — `RunCommentary`: snapshot lượt chạy, prompt, dự phòng, fetch.
- Create `scripts/ui/components/ai_toggle_row.gd` — dòng Cài đặt gắn với `Gemini`.
- Create `tests/test_run_commentary.gd`, `tests/test_ai_toggle_row.gd`.
- Modify `project.godot` (autoload), `.gitignore`, `README.md`, `scripts/autoload/loc.gd` (3 key), `scripts/data/catalog.gd` (`COMMENTARY`), `scenes/ui/screens/settings.tscn`, `scenes/ui/screens/results.tscn`, `scripts/ui/screens/results_screen.gd`, `export_presets.cfg`.

**2D (`Pixel-Adventure/Pixel-Adventure/`):**
- Create `ui/ai_chat/ai_chat.gd` — autoload `AiChat` (CanvasLayer dựng UI bằng code).
- Create `tests/test_ai_chat.gd`, `tests/test_npc_ai.gd`.
- Modify `project.godot` (autoload), `../.gitignore`, `../README.md`, `../CLAUDE.md`, `ui/settings_menu/settings_menu.{gd,tscn}`, `ui/dialogue/dialogue.gd` (`is_open`), `objects/npc/npc.gd`, `levels/hub/hub.tscn` (persona 3 NPC).

---

### Task 1: Client `Gemini` + test (repo 3D)

**Files:**
- Create: `temple-run-pro-max/addons/gemini/gemini.gd`
- Create: `temple-run-pro-max/tests/test_gemini.gd`
- Create: `temple-run-pro-max/gemini.example.cfg`
- Modify: `temple-run-pro-max/project.godot` (section `[autoload]`)
- Modify: `temple-run-pro-max/.gitignore`
- Modify: `temple-run-pro-max/README.md`

**Interfaces:**
- Produces (autoload `Gemini`, dùng ở mọi task sau):
  - `signal enabled_changed(enabled: bool)`
  - `var enabled: bool`, `var model: String`, `var transport: Callable` — `(url: String, headers: PackedStringArray, body: String, timeout: float) -> Dictionary{"ok": bool, "code": int, "body": String}` (có thể là coroutine)
  - `func generate_text(prompt: String, opts: Dictionary = {}) -> String` (coroutine, `""` khi lỗi)
  - `func generate_json(prompt: String, schema: Dictionary, opts: Dictionary = {}) -> Variant` (coroutine, `null` khi lỗi)
  - `func chat(history: Array, opts: Dictionary = {}) -> String` (coroutine; `history` = `[{"role": "user"|"model", "text": String}]`, phải bắt đầu bằng `"user"`)
  - `func configure(api_key: String, model_name: String = DEFAULT_MODEL) -> void`
  - `func has_key() -> bool`, `func is_user_enabled() -> bool`, `func set_user_enabled(on: bool) -> void`
  - `func cache_age(key: String) -> float` (giây; `INF` nếu chưa có)
  - `static func build_body(turns: Array, opts: Dictionary, schema: Dictionary) -> Dictionary`, `static func extract_text(body: String) -> String`, `static func clean_text(text: String) -> String`
  - `opts`: `system: String`, `temperature: float = 0.9`, `max_tokens: int = 200`, `timeout: float = 8.0`, `cache_key: String`, `persist: bool`, `refresh: bool`

- [ ] **Step 1: Viết test (sẽ fail vì chưa có client)**

Tạo `temple-run-pro-max/tests/test_gemini.gd`:

```gdscript
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
```

- [ ] **Step 2: Chạy test, xác nhận fail**

```bash
cd "$WS/temple-run-pro-max" && $GODOT --headless --path . --script res://tests/test_gemini.gd; echo "exit=$?"
```
Expected: lỗi load `res://addons/gemini/gemini.gd` (file chưa tồn tại), exit khác 0.

- [ ] **Step 3: Viết client**

Tạo `temple-run-pro-max/addons/gemini/gemini.gd`:

```gdscript
extends Node
## Autoload `Gemini`: client nhỏ gọi Gemini API (REST generateContent) qua HTTPRequest.
## File này GIỐNG HỆT ở Pixel Adventure và Temple Run Pro Max, không phụ thuộc code game.
##
## Mọi hàm gọi AI là coroutine (`await Gemini.generate_text(...)`) và KHÔNG BAO GIỜ ném lỗi:
## thất bại (không key, người chơi tắt AI, mất mạng, timeout, hết quota, key sai, bị chặn an
## toàn, JSON hỏng) → trả "" hoặc null ngay. Người gọi luôn có nội dung dự phòng.
##
## Key: env GEMINI_API_KEY → user://gemini.cfg → res://gemini.local.cfg (gitignored, đóng gói
## vào APK khi demo). Xem gemini.example.cfg. Spec: docs/superpowers/specs/
## 2026-09-29-gemini-ai-integration-design.md

signal enabled_changed(enabled: bool)

const API_URL := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"
const DEFAULT_MODEL := "gemini-2.5-flash-lite"
const CONFIG_PATHS: Array[String] = ["user://gemini.cfg", "res://gemini.local.cfg"]
const PREFS_PATH := "user://gemini_prefs.cfg"
const CACHE_PATH := "user://gemini_cache.json"
const MAX_IN_FLIGHT := 2
const QUOTA_COOLDOWN_MS := 60_000
## finishReason coi như bị chặn — không dùng text (nếu có).
const BLOCKED_REASONS: Array[String] = ["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII", "RECITATION"]

## true khi có key VÀ người chơi bật AI VÀ key chưa bị server từ chối trong phiên này.
## Chỉ client ghi; nơi khác chỉ đọc.
var enabled: bool = false
var model: String = DEFAULT_MODEL
## (url, headers, body, timeout) -> {"ok": bool, "code": int, "body": String}.
## Mặc định gửi HTTP thật; test gán hàm giả.
var transport: Callable

var _api_key := ""
var _user_enabled := true
var _session_disabled := false
var _cooldown_until_ms := 0
var _in_flight := 0
## cache_key -> {"value": Variant, "saved_at": int (unix giây), "persist": bool}
var _cache := {}


func _init() -> void:
	transport = _http_transport


func _ready() -> void:
	# AiChat (2D) pause cây scene lúc chờ trả lời — HTTPRequest con phải chạy tiếp.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_prefs()
	_load_key()
	_load_cache()
	_refresh_enabled()


# --- Cấu hình -----------------------------------------------------------------

## Ghi đè key/model lúc chạy (test dùng). Xoá trạng thái lỗi của phiên.
func configure(api_key: String, model_name: String = DEFAULT_MODEL) -> void:
	_api_key = api_key.strip_edges()
	model = model_name
	_session_disabled = false
	_cooldown_until_ms = 0
	_refresh_enabled()


func has_key() -> bool:
	return _api_key != ""


func is_user_enabled() -> bool:
	return _user_enabled


## Công tắc "Tính năng AI" trong Cài đặt. Lưu vào user://gemini_prefs.cfg.
func set_user_enabled(on: bool) -> void:
	_user_enabled = on
	var cfg := ConfigFile.new()
	cfg.set_value("gemini", "enabled", on)
	cfg.save(PREFS_PATH)
	_refresh_enabled()


func _refresh_enabled() -> void:
	var now := _api_key != "" and _user_enabled and not _session_disabled
	if now != enabled:
		enabled = now
		enabled_changed.emit(enabled)


func _load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		_user_enabled = bool(cfg.get_value("gemini", "enabled", true))


func _load_key() -> void:
	_api_key = OS.get_environment("GEMINI_API_KEY").strip_edges()
	for path in CONFIG_PATHS:
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			continue
		if _api_key == "":
			_api_key = String(cfg.get_value("gemini", "api_key", "")).strip_edges()
		if model == DEFAULT_MODEL:
			model = String(cfg.get_value("gemini", "model", DEFAULT_MODEL)).strip_edges()


# --- API công khai --------------------------------------------------------------

## Trả về text đã làm sạch, hoặc "" nếu thất bại.
func generate_text(prompt: String, opts: Dictionary = {}) -> String:
	var cached: Variant = _cache_get(opts)
	if cached is String:
		return cached
	var text := clean_text(await _request([{"role": "user", "text": prompt}], opts, {}))
	if text != "":
		_cache_put(opts, text)
	return text


## Structured output theo `schema` (định dạng OpenAPI của Gemini: "type": "OBJECT", ...).
## Trả về Dictionary/Array đã parse, hoặc null nếu thất bại.
func generate_json(prompt: String, schema: Dictionary, opts: Dictionary = {}) -> Variant:
	var cached: Variant = _cache_get(opts)
	if cached != null:
		return cached
	var raw: String = await _request([{"role": "user", "text": prompt}], opts, schema)
	if raw == "":
		return null
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary or parsed is Array):
		push_warning("[Gemini] Kết quả không phải JSON hợp lệ.")
		return null
	_cache_put(opts, parsed)
	return parsed


## Hội thoại nhiều lượt: history = [{"role": "user"|"model", "text": String}], bắt đầu
## bằng "user", xen kẽ. Không cache. Trả "" nếu thất bại.
func chat(history: Array, opts: Dictionary = {}) -> String:
	return clean_text(await _request(history, opts, {}))


## Số giây kể từ khi `key` được lưu vào cache; INF nếu chưa có.
func cache_age(key: String) -> float:
	if not _cache.has(key):
		return INF
	return Time.get_unix_time_from_system() - float(_cache[key].saved_at)


# --- Request --------------------------------------------------------------------

func _request(turns: Array, opts: Dictionary, schema: Dictionary) -> String:
	if not enabled:
		return ""
	if Time.get_ticks_msec() < _cooldown_until_ms:
		return ""
	if _in_flight >= MAX_IN_FLIGHT:
		return ""
	var headers := PackedStringArray(["Content-Type: application/json", "x-goog-api-key: " + _api_key])
	var body := JSON.stringify(build_body(turns, opts, schema))
	_in_flight += 1
	var res: Dictionary = await transport.call(API_URL % model, headers, body, float(opts.get("timeout", 8.0)))
	_in_flight -= 1
	return _handle_response(res)


func _handle_response(res: Dictionary) -> String:
	if not res.get("ok", false):
		push_warning("[Gemini] Lỗi mạng hoặc hết thời gian chờ.")
		return ""
	var code := int(res.get("code", 0))
	if code == 429:
		_cooldown_until_ms = Time.get_ticks_msec() + QUOTA_COOLDOWN_MS
		push_warning("[Gemini] Hết quota (HTTP 429) — tạm ngưng gọi AI 60 giây.")
		return ""
	if code in [400, 401, 403, 404]:
		_session_disabled = true
		_refresh_enabled()
		push_warning("[Gemini] HTTP %d — kiểm tra API key và tên model '%s'. Tắt AI đến hết phiên." % [code, model])
		return ""
	if code != 200:
		push_warning("[Gemini] HTTP %d." % code)
		return ""
	return extract_text(String(res.get("body", "")))


func _http_transport(url: String, headers: PackedStringArray, body: String, timeout: float) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = timeout
	add_child(req)
	if req.request(url, headers, HTTPClient.METHOD_POST, body) != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": ""}
	var r: Array = await req.request_completed
	req.queue_free()
	var bytes: PackedByteArray = r[3]
	return {"ok": r[0] == HTTPRequest.RESULT_SUCCESS, "code": int(r[1]), "body": bytes.get_string_from_utf8()}


static func build_body(turns: Array, opts: Dictionary, schema: Dictionary) -> Dictionary:
	var contents: Array = []
	for t: Dictionary in turns:
		contents.append({"role": String(t.role), "parts": [{"text": String(t.text)}]})
	var config := {
		"temperature": float(opts.get("temperature", 0.9)),
		"maxOutputTokens": int(opts.get("max_tokens", 200)),
	}
	if not schema.is_empty():
		config["responseMimeType"] = "application/json"
		config["responseSchema"] = schema
	var body := {"contents": contents, "generationConfig": config}
	var system := String(opts.get("system", ""))
	if system != "":
		body["systemInstruction"] = {"parts": [{"text": system}]}
	return body


## Lấy text của candidate đầu tiên (bỏ phần "thought"). "" nếu không có / bị chặn.
static func extract_text(body: String) -> String:
	var data: Variant = JSON.parse_string(body)
	if not (data is Dictionary):
		return ""
	var candidates: Array = data.get("candidates", [])
	if candidates.is_empty():
		return ""
	var cand: Dictionary = candidates[0]
	if String(cand.get("finishReason", "")) in BLOCKED_REASONS:
		return ""
	var content: Dictionary = cand.get("content", {})
	var out := ""
	for part: Variant in content.get("parts", []):
		if part is Dictionary and not part.get("thought", false):
			out += String(part.get("text", ""))
	return out


## Bỏ ký hiệu markdown, gộp khoảng trắng, bỏ ngoặc kép bao ngoài.
static func clean_text(text: String) -> String:
	var t := text
	for mark in ["*", "#", "`"]:
		t = t.replace(mark, "")
	var ws := RegEx.create_from_string("\\s+")
	t = ws.sub(t, " ", true).strip_edges()
	if t.length() >= 2 and t.begins_with("\"") and t.ends_with("\""):
		t = t.substr(1, t.length() - 2).strip_edges()
	return t


# --- Cache ------------------------------------------------------------------------

func _cache_get(opts: Dictionary) -> Variant:
	var key := String(opts.get("cache_key", ""))
	if key == "" or opts.get("refresh", false) or not _cache.has(key):
		return null
	return _cache[key].value


func _cache_put(opts: Dictionary, value: Variant) -> void:
	var key := String(opts.get("cache_key", ""))
	if key == "":
		return
	var persist := bool(opts.get("persist", false))
	_cache[key] = {"value": value, "saved_at": int(Time.get_unix_time_from_system()), "persist": persist}
	if persist:
		_save_cache()


func _save_cache() -> void:
	var out := {}
	for key: String in _cache:
		if _cache[key].persist:
			out[key] = {"value": _cache[key].value, "saved_at": _cache[key].saved_at}
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out))


func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
	if not (data is Dictionary):
		return
	for key: String in data:
		var entry: Variant = data[key]
		if entry is Dictionary and entry.has("value"):
			_cache[key] = {"value": entry.value, "saved_at": int(entry.get("saved_at", 0)), "persist": true}
```

- [ ] **Step 4: Đăng ký autoload, gitignore, file mẫu**

Trong `temple-run-pro-max/project.godot`, ngay dưới dòng `[autoload]` và dòng trống sau nó, thêm dòng **đầu tiên** của danh sách:

```ini
Gemini="*res://addons/gemini/gemini.gd"
```

Thêm vào cuối `temple-run-pro-max/.gitignore`:

```gitignore

# Gemini API key cục bộ (đóng gói vào APK khi demo) — KHÔNG commit
gemini.local.cfg
```

Tạo `temple-run-pro-max/gemini.example.cfg`:

```ini
; Mẫu cấu hình Gemini. Copy thành gemini.local.cfg (cùng thư mục, đã gitignore) hoặc
; user://gemini.cfg rồi điền key từ https://aistudio.google.com/apikey
; Trên máy tính có thể dùng biến môi trường GEMINI_API_KEY thay cho file này.
[gemini]
api_key=""
model="gemini-2.5-flash-lite"
```

- [ ] **Step 5: Chạy test, xác nhận pass**

```bash
cd "$WS/temple-run-pro-max" && $GODOT --headless --path . --import >/dev/null 2>&1; $GODOT --headless --path . --script res://tests/test_gemini.gd; echo "exit=$?"
```
Expected: tất cả dòng `PASS`, dòng cuối `ALL PASS`, `exit=0`. Có thể thấy các dòng `WARNING: [Gemini] ...` — đó là cảnh báo cố ý của các test lỗi.

- [ ] **Step 6: Thêm mục README**

Thêm vào `temple-run-pro-max/README.md`, ngay trước heading `## Cấu trúc`:

```markdown
## Tính năng AI (Gemini)

Game dùng Gemini API để tạo nội dung động (bình luận cuối lượt, ...). Không có key thì
mọi tính năng AI tự tắt, game chạy như bình thường.

1. Lấy API key tại https://aistudio.google.com/apikey (nên tạo key riêng cho demo và đặt giới hạn quota).
2. Chọn một trong các cách:
   - Máy tính: `export GEMINI_API_KEY=...` rồi chạy Godot từ terminal đó.
   - Điện thoại (demo): copy `gemini.example.cfg` thành `gemini.local.cfg`, điền `api_key`, rồi export APK.
     File này đã được `.gitignore` và được đóng gói vào APK — **ai có APK đều trích xuất được key**, chỉ dùng cho demo cá nhân.
3. Đổi model trong file cấu hình (`model=`). Mặc định `gemini-2.5-flash-lite`. Nếu chọn model có "thinking", tăng `max_tokens` ở nơi gọi.
4. Bật/tắt trong **Cài đặt → Tính năng AI (Gemini)**.

Test client (không cần mạng): `$GODOT --headless --path . --script res://tests/test_gemini.gd`
```

- [ ] **Step 7: Commit**

```bash
cd "$WS/temple-run-pro-max" && git add addons/gemini tests/test_gemini.gd gemini.example.cfg project.godot .gitignore README.md && git commit -m "feat: client Gemini dùng chung (autoload) + test headless

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Lưu ý: nếu Godot sinh file `addons/gemini/gemini.gd.uid` hoặc `tests/test_gemini.gd.uid`, add luôn chúng (project đang commit file `.uid`).

---

### Task 2: Đưa client vào Pixel Adventure (repo 2D)

**Files:**
- Create: `Pixel-Adventure/Pixel-Adventure/addons/gemini/gemini.gd` (copy nguyên từ Task 1)
- Create: `Pixel-Adventure/Pixel-Adventure/tests/test_gemini.gd` (copy nguyên từ Task 1)
- Create: `Pixel-Adventure/Pixel-Adventure/gemini.example.cfg` (copy nguyên từ Task 1)
- Modify: `Pixel-Adventure/Pixel-Adventure/project.godot`, `Pixel-Adventure/.gitignore`, `Pixel-Adventure/README.md`, `Pixel-Adventure/CLAUDE.md`

**Interfaces:**
- Consumes: file từ Task 1 (copy, không sửa).
- Produces: autoload `Gemini` trong 2D, cùng API như Task 1.

- [ ] **Step 1: Copy file**

```bash
P2="$WS/Pixel-Adventure/Pixel-Adventure"; P3="$WS/temple-run-pro-max"
mkdir -p "$P2/addons/gemini" "$P2/tests"
cp "$P3/addons/gemini/gemini.gd" "$P2/addons/gemini/gemini.gd"
cp "$P3/tests/test_gemini.gd" "$P2/tests/test_gemini.gd"
cp "$P3/gemini.example.cfg" "$P2/gemini.example.cfg"
```

- [ ] **Step 2: Đăng ký autoload**

Trong `Pixel-Adventure/Pixel-Adventure/project.godot`, section `[autoload]`, thêm làm dòng **đầu tiên** (trước `Events=`):

```ini
Gemini="*res://addons/gemini/gemini.gd"
```

- [ ] **Step 3: Chạy test**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && $GODOT --headless --path . --import >/dev/null 2>&1; $GODOT --headless --path . --script res://tests/test_gemini.gd; echo "exit=$?"
```
Expected: `ALL PASS`, `exit=0`.

- [ ] **Step 4: gitignore + tài liệu**

Thêm vào cuối `Pixel-Adventure/.gitignore`:

```gitignore

# Gemini API key cục bộ (đóng gói vào APK khi demo) — KHÔNG commit
gemini.local.cfg
```

Thêm vào `Pixel-Adventure/README.md`, ngay trước heading `## Cấu trúc thư mục`:

```markdown
## Tính năng AI (Gemini)

NPC ở làng có thể trò chuyện bằng Gemini. Không có key thì NPC dùng thoại tĩnh như cũ.

1. Lấy API key tại https://aistudio.google.com/apikey (nên tạo key riêng cho demo và đặt giới hạn quota).
2. Chọn một trong các cách:
   - Máy tính: `export GEMINI_API_KEY=...` rồi chạy Godot từ terminal đó.
   - Điện thoại (demo): copy `Pixel-Adventure/gemini.example.cfg` thành `Pixel-Adventure/gemini.local.cfg`, điền `api_key`.
     Khi tạo export preset Android: bật quyền **Internet** và thêm `gemini.local.cfg` vào *Filters to export non-resource files*.
     **Ai có APK đều trích xuất được key** — chỉ dùng cho demo cá nhân.
3. Bật/tắt trong **Cài đặt → Tính năng AI (Gemini)**.

Test (không cần mạng), chạy trong `Pixel-Adventure/`: `$GODOT --headless --path . --script res://tests/test_gemini.gd`
```

Trong `Pixel-Adventure/CLAUDE.md`, mục **Autoloads**, thêm một gạch đầu dòng cuối danh sách autoload:

```markdown
- `Gemini` (`addons/gemini/gemini.gd`) — client Gemini API dùng chung với Temple Run Pro Max (file giống hệt, sửa thì sửa cả hai). `await Gemini.generate_text/generate_json/chat(...)` trả `""`/`null` khi thất bại — mọi tính năng AI phải có dự phòng tĩnh. `process_mode = ALWAYS`. Test: `tests/test_gemini.gd` (transport giả). Key: env `GEMINI_API_KEY` → `user://gemini.cfg` → `res://gemini.local.cfg` (gitignored).
```

- [ ] **Step 5: Commit**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && git add addons/gemini tests/test_gemini.gd gemini.example.cfg project.godot ../.gitignore ../README.md ../CLAUDE.md && git commit -m "feat: thêm client Gemini dùng chung (autoload) + test headless

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Add thêm file `.uid` nếu Godot sinh ra.)

---

### Task 3: Công tắc AI trong Cài đặt (3D)

**Files:**
- Create: `temple-run-pro-max/scripts/ui/components/ai_toggle_row.gd`
- Create: `temple-run-pro-max/tests/test_ai_toggle_row.gd`
- Modify: `temple-run-pro-max/scripts/autoload/loc.gd` (bảng `S`)
- Modify: `temple-run-pro-max/scenes/ui/screens/settings.tscn`

**Interfaces:**
- Consumes: `Gemini.has_key()`, `Gemini.is_user_enabled()`, `Gemini.set_user_enabled(on)`, `Gemini.configure(...)`.
- Produces: `class_name AiToggleRow extends UIComponent` với `refresh() -> void`; Loc keys `"ai_features"`, `"ai_no_key"`, `"ai_commentary"` (Task 4 dùng `"ai_commentary"`).

- [ ] **Step 1: Viết test**

Tạo `temple-run-pro-max/tests/test_ai_toggle_row.gd`:

```gdscript
extends SceneTree
## Chạy: $GODOT --headless --path . --script res://tests/test_ai_toggle_row.gd

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
	var loc: Node = root.get_node("Loc")
	loc.lang = "vi"

	var settings: Node = load("res://scenes/ui/screens/settings.tscn").instantiate()
	var ai_row := settings.get_node_or_null("Margin/Column/Panel/Scroll/Padding/Content/Ai")
	check(ai_row != null and ai_row.get_script().resource_path == "res://scripts/ui/components/ai_toggle_row.gd",
		"settings.tscn has Ai row with AiToggleRow script")
	settings.free()

	var row: Control = load("res://scenes/ui/components/toggle_row.tscn").instantiate()
	row.set_script(load("res://scripts/ui/components/ai_toggle_row.gd"))
	root.add_child(row)
	var button: Button = row.get_node("Toggle")
	var title: Label = row.get_node("Title")

	gemini.configure("")
	row.refresh()
	check(button.disabled, "no key -> toggle disabled")
	check(title.text.contains("chưa có API key"), "no key -> hint shown")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	row.refresh()
	check(not button.disabled and button.text == "BẬT", "key + enabled -> BẬT")
	check(title.text == "Tính năng AI (Gemini)", "title from Loc")

	gemini._user_enabled = false
	gemini._refresh_enabled()
	row.refresh()
	check(button.text == "TẮT" and not gemini.enabled, "user off -> TẮT and client disabled")

	row.queue_free()
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
```

(Test không bấm nút thật để khỏi ghi `user://gemini_prefs.cfg`.)

- [ ] **Step 2: Chạy test, xác nhận fail**

```bash
cd "$WS/temple-run-pro-max" && $GODOT --headless --path . --script res://tests/test_ai_toggle_row.gd; echo "exit=$?"
```
Expected: `FAIL settings.tscn has Ai row ...` và lỗi load `ai_toggle_row.gd`, exit khác 0.

- [ ] **Step 3: Thêm key Loc**

Trong `temple-run-pro-max/scripts/autoload/loc.gd`, ngay sau dòng `"off": ["OFF", "TẮT"],` (dòng 111), thêm:

```gdscript
	"ai_features": ["AI features (Gemini)", "Tính năng AI (Gemini)"],
	"ai_no_key": ["no API key", "chưa có API key"],
	"ai_commentary": ["Commentator", "Bình luận viên"],
```

- [ ] **Step 4: Viết component**

Tạo `temple-run-pro-max/scripts/ui/components/ai_toggle_row.gd`:

```gdscript
class_name AiToggleRow
extends UIComponent
## Settings row bound to the Gemini autoload's on/off switch. Not a Profile setting:
## the shared client (addons/gemini) keeps its own prefs. Greyed out without an API key.
## Reuses toggle_row.tscn (Title + Toggle); settings.tscn swaps the script on the instance.


func _ready() -> void:
	super()
	($Toggle as Button).pressed.connect(func() -> void:
		Gemini.set_user_enabled(not Gemini.is_user_enabled())
		refresh())


func refresh() -> void:
	var has_key := Gemini.has_key()
	var title := Loc.t("ai_features")
	if not has_key:
		title += "\n(%s)" % Loc.t("ai_no_key")
	($Title as Label).text = title
	var on := has_key and Gemini.is_user_enabled()
	var b: Button = $Toggle
	b.disabled = not has_key
	b.text = Loc.t("on") if on else Loc.t("off")
	b.theme_type_variation = &"ButtonRed" if on else &"ButtonGrey"
```

- [ ] **Step 5: Thêm dòng vào settings.tscn**

Trong `temple-run-pro-max/scenes/ui/screens/settings.tscn`, sau dòng `[ext_resource type="Texture2D" path="res://assets/ui/icons/trashcan.png" id="8_trashcan"]` thêm:

```
[ext_resource type="Script" path="res://scripts/ui/components/ai_toggle_row.gd" id="9_ai_toggle"]
```

Ngay sau block node `Tutorial` (kết thúc bằng `text_key = "tutorial"`) và trước `[node name="Reset" ...`, thêm:

```

[node name="Ai" parent="Margin/Column/Panel/Scroll/Padding/Content" instance=ExtResource("7_toggle_row")]
layout_mode = 2
script = ExtResource("9_ai_toggle")
```

`settings_screen.build()` đã gọi `refresh()` cho mọi con có method đó nên không cần sửa script màn hình.

- [ ] **Step 6: Chạy test, xác nhận pass**

```bash
cd "$WS/temple-run-pro-max" && $GODOT --headless --path . --import >/dev/null 2>&1; $GODOT --headless --path . --script res://tests/test_ai_toggle_row.gd; echo "exit=$?"
```
Expected: `ALL PASS`, `exit=0`.

- [ ] **Step 7: Commit**

```bash
cd "$WS/temple-run-pro-max" && git add scripts/ui/components/ai_toggle_row.gd* tests/test_ai_toggle_row.gd* scripts/autoload/loc.gd scenes/ui/screens/settings.tscn && git commit -m "feat: công tắc Tính năng AI (Gemini) trong Cài đặt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Bình luận viên cuối lượt (3D)

**Files:**
- Create: `temple-run-pro-max/scripts/ai/run_commentary.gd`
- Create: `temple-run-pro-max/tests/test_run_commentary.gd`
- Modify: `temple-run-pro-max/scripts/data/catalog.gd` (thêm `COMMENTARY`)
- Modify: `temple-run-pro-max/scenes/ui/screens/results.tscn` (label `Commentary`)
- Modify: `temple-run-pro-max/scripts/ui/screens/results_screen.gd`

**Interfaces:**
- Consumes: `Gemini.enabled`, `await Gemini.generate_text(prompt, opts) -> String`; `Loc.pick(pair)`, `Loc.lang`, `Loc.t("ai_commentary")`; `Catalog.biomes()`, `Catalog.BIOME_LENGTH`, `Catalog.item(id)`, `Catalog.modern()`; `Game.distance/score/coins/gems/run`; `Profile.stat(key)`, `Profile.data.character`.
- Produces: `class_name RunCommentary` — `static func snapshot(summary: Dictionary) -> Dictionary`, `static func build_prompt(r: Dictionary) -> String`, `static func fallback(r: Dictionary) -> String`, `static func fetch(r: Dictionary) -> String` (coroutine, không bao giờ trả `""`); `Catalog.COMMENTARY: Dictionary` (`"fall"|"caught"|"best"` → mảng cặp `[en, vi]`); `ResultsScreen._update_commentary() -> void`.

- [ ] **Step 1: Viết test**

Tạo `temple-run-pro-max/tests/test_run_commentary.gd`:

```gdscript
extends SceneTree
## Chạy: $GODOT --headless --path . --script res://tests/test_run_commentary.gd

var _fails := 0
var calls := 0


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


func fake(code: int, text: String) -> Callable:
	return func(_u: String, _h: PackedStringArray, _b: String, _t: float) -> Dictionary:
		calls += 1
		return {"ok": true, "code": code, "body": ok_body(text)}


func sample(reason := "caught", new_best := false, lang := "vi") -> Dictionary:
	return {"reason": reason, "new_best": new_best, "distance": 1234, "score": 5678, "coins": 90,
		"gems": 2, "hits": 1, "revives": 0, "best_distance": 2000, "biome": "Phế Tích Hoàng Hôn",
		"character": "Nhà Thám Hiểm", "style": "classic jungle temple", "lang": lang}


func all_fallbacks() -> Array:
	var out := []
	for group: String in Catalog.COMMENTARY:
		for pair: Array in Catalog.COMMENTARY[group]:
			out.append_array(pair)
	return out


func _run() -> void:
	var gemini: Node = root.get_node("Gemini")
	var loc: Node = root.get_node("Loc")
	loc.lang = "vi"

	var p_vi := RunCommentary.build_prompt(sample("fall", true, "vi"))
	check(p_vi.contains("Vietnamese"), "prompt asks for Vietnamese")
	check(p_vi.contains("1234") and p_vi.contains("5678"), "prompt has distance and score")
	check(p_vi.contains("fell"), "prompt explains fall")
	check(p_vi.contains("NEW BEST"), "prompt mentions new best")
	var p_en := RunCommentary.build_prompt(sample("caught", false, "en"))
	check(p_en.contains("English") and p_en.contains("caught") and not p_en.contains("NEW BEST"), "english prompt, caught, no best")

	for reason: String in ["fall", "caught", ""]:
		for lang: String in ["vi", "en"]:
			loc.lang = lang
			var f := RunCommentary.fallback(sample(reason, false, lang))
			check(f != "" and f in all_fallbacks(), "fallback %s/%s non-empty" % [reason, lang])
	loc.lang = "vi"
	var best := RunCommentary.fallback(sample("fall", true))
	check(best in Catalog.COMMENTARY["best"].map(func(p: Array) -> String: return p[1]), "new best uses best lines")

	var snap := RunCommentary.snapshot({"reason": "fall", "new_best": false})
	check(snap.reason == "fall" and snap.biome is String and snap.biome != "", "snapshot has reason and biome")
	check(snap.lang == "vi" and snap.character is String, "snapshot has lang and character")

	gemini.configure("")
	calls = 0
	var off := await RunCommentary.fetch(sample())
	check(off in all_fallbacks() and calls == 0, "AI off -> fallback, no request")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	gemini.transport = fake(200, "Chạy hay lắm! Lần sau trượt sớm hơn.")
	check(await RunCommentary.fetch(sample()) == "Chạy hay lắm! Lần sau trượt sớm hơn.", "AI on -> AI text")
	gemini.transport = fake(500, "x")
	check(await RunCommentary.fetch(sample()) in all_fallbacks(), "AI error -> fallback")

	await test_results_screen_stale_guard(gemini)

	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)


## Review Focus #1: bình luận của lượt cũ về muộn không được ghi lên màn Kết quả của lượt mới.
func test_results_screen_stale_guard(gemini: Node) -> void:
	var screen: Node = load("res://scenes/ui/screens/results.tscn").instantiate()
	var label: Label = screen.get_node("%Commentary")
	var slow := func(_u: String, _h: PackedStringArray, _b: String, _t: float) -> Dictionary:
		await create_timer(0.1).timeout
		return {"ok": true, "code": 200, "body": ok_body("OLD RUN")}
	gemini.transport = slow
	screen.summary = {"reason": "fall"}
	screen._update_commentary()          # lượt 1: request chậm
	gemini.transport = fake(200, "NEW RUN")
	screen.summary = {"reason": "caught"}
	await screen._update_commentary()    # lượt 2: trả ngay
	check(label.text.contains("NEW RUN"), "new run commentary shown")
	await create_timer(0.2).timeout      # lượt 1 về muộn
	check(label.text.contains("NEW RUN") and not label.text.contains("OLD RUN"), "stale commentary ignored")
	calls = 0
	gemini.transport = fake(200, "AGAIN")
	await screen._update_commentary()    # refresh() cùng summary (vd. sau khi x2 xu)
	check(calls == 0 and label.text.contains("NEW RUN"), "same summary -> no refetch")
	screen.free()
```

- [ ] **Step 2: Chạy test, xác nhận fail**

```bash
cd "$WS/temple-run-pro-max" && $GODOT --headless --path . --script res://tests/test_run_commentary.gd; echo "exit=$?"
```
Expected: lỗi biên dịch `Identifier "RunCommentary" not declared` (hoặc `Catalog.COMMENTARY`), exit khác 0.

- [ ] **Step 3: Thêm câu dự phòng vào Catalog**

Trong `temple-run-pro-max/scripts/data/catalog.gd`, ngay trước dòng `## Environment presets the run cycles through (every BIOME_LENGTH metres).` (dòng ~238), thêm:

```gdscript
## Fallback end-of-run commentary when Gemini is off or fails (RunCommentary).
## Grouped by how the run ended; "best" wins when the run set a new best score.
const COMMENTARY := {
	"fall": [
		["Straight into the abyss! Watch the edges before each turn.", "Rơi thẳng xuống vực! Nhìn kỹ mép đường trước mỗi khúc cua nhé."],
		["Gravity wins this round. Swipe a little earlier at the gaps.", "Trọng lực thắng ván này. Vuốt sớm hơn một chút ở các khoảng trống."],
		["A bold leap... into nothing. Jump right at the edge next time.", "Một cú nhảy táo bạo... vào hư không. Lần sau nhảy sát mép hơn."],
	],
	"caught": [
		["The demons finally caught up! Fewer hits means more distance.", "Lũ quỷ đã bắt kịp! Ít va chạm hơn là chạy xa hơn."],
		["Caught from behind! Slide under barriers instead of tanking them.", "Bị tóm từ phía sau! Hãy trượt qua rào thay vì lao vào."],
		["So close to escaping! A shield power-up would have saved you.", "Suýt thoát rồi! Một chiếc khiên đã có thể cứu bạn."],
	],
	"best": [
		["A new personal best! This run will be remembered.", "Kỷ lục mới! Lượt chạy này sẽ được nhớ mãi."],
		["Record smashed! Can you top it on the very next run?", "Phá kỷ lục rồi! Liệu lượt sau có vượt qua được không?"],
	],
}
```

- [ ] **Step 4: Viết RunCommentary**

Tạo `temple-run-pro-max/scripts/ai/run_commentary.gd`:

```gdscript
class_name RunCommentary
extends RefCounted
## End-of-run commentator: a 2-sentence reaction + tip from Gemini on the results
## screen, in the current language. Falls back to Catalog.COMMENTARY whenever the AI is
## off or the request fails, so fetch() never returns an empty string.

const SYSTEM := "You are a lively sports commentator for the endless runner game Temple Run Pro Max. Comment on the player's run in at most 2 short sentences (under 160 characters in total): one reaction, then one concrete tip. Plain text only: no markdown, no emojis, no hashtags, no quotes."


## Everything the prompt needs, read from the finished run. `summary` is Game.end_run()'s result.
static func snapshot(summary: Dictionary) -> Dictionary:
	var biomes := Catalog.biomes()
	var dist := int(Game.distance)
	var biome: Dictionary = biomes[int(dist / Catalog.BIOME_LENGTH) % biomes.size()]
	return {
		"reason": String(summary.get("reason", "")),
		"new_best": bool(summary.get("new_best", false)),
		"distance": dist,
		"score": Game.score,
		"coins": Game.coins,
		"gems": Game.gems,
		"hits": int(Game.run.get("hits", 0)),
		"revives": int(Game.run.get("revives", 0)),
		"best_distance": int(Profile.stat("best_distance")),
		"biome": Loc.pick(biome.name),
		"character": Loc.pick(Catalog.item(Profile.data.character).get("name", [])),
		"style": "modern neon sci-fi city" if Catalog.modern() else "classic jungle temple",
		"lang": Loc.lang,
	}


static func build_prompt(r: Dictionary) -> String:
	var ending := "ran out of luck"
	match String(r.reason):
		"fall": ending = "fell into a chasm"
		"caught": ending = "was caught by the demons chasing them"
	var lines := PackedStringArray([
		"Answer in %s." % ("Vietnamese" if r.lang == "vi" else "English"),
		"World style: %s. Runner: %s." % [r.style, r.character],
		"This run: %d m, score %d, %d coins, %d gems, took %d hits, revived %d times, furthest zone reached: %s." % [
			r.distance, r.score, r.coins, r.gems, r.hits, r.revives, r.biome],
		"The run ended because the runner %s." % ending,
		"Personal best distance: %d m." % r.best_distance,
	])
	if r.new_best:
		lines.append("This run set a NEW BEST score!")
	return "\n".join(lines)


static func fallback(r: Dictionary) -> String:
	var group := "best" if r.get("new_best", false) else String(r.get("reason", ""))
	var options: Array = Catalog.COMMENTARY.get(group, Catalog.COMMENTARY["caught"])
	return Loc.pick(options[randi() % options.size()])


## Coroutine. AI text when available, otherwise a fallback line — never "".
static func fetch(r: Dictionary) -> String:
	if not Gemini.enabled:
		return fallback(r)
	var text: String = await Gemini.generate_text(build_prompt(r), {"system": SYSTEM, "max_tokens": 120, "temperature": 1.0})
	return text if text != "" else fallback(r)
```

- [ ] **Step 5: Thêm label vào results.tscn**

Trong `temple-run-pro-max/scenes/ui/screens/results.tscn`, ngay trước `[node name="Leveled" type="Label" ...]`, thêm (giữ một dòng trống giữa các block):

```

[node name="Commentary" type="Label" parent="Margin/Column/Panel/Scroll/Padding/Content"]
unique_name_in_owner = true
custom_minimum_size = Vector2(200, 0)
layout_mode = 2
size_flags_horizontal = 3
theme_type_variation = &"LabelSoft"
theme_override_font_sizes/font_size = 28
text = "…"
horizontal_alignment = 1
autowrap_mode = 3
```

- [ ] **Step 6: Nối vào ResultsScreen**

Trong `temple-run-pro-max/scripts/ui/screens/results_screen.gd`:

Sau dòng `var _doubled := false` thêm:

```gdscript
## The summary whose commentary is shown / being fetched. build() runs again on refresh()
## (e.g. after doubling coins) and must not refetch; a late reply for an older run is dropped.
var _commentary_for: Dictionary = {}
```

Trong `build()`, ngay sau dòng `%Wardrobe.text = Loc.t("wardrobe")` (dòng cuối của hàm), thêm:

```gdscript
	_update_commentary()
```

Thêm hàm mới ngay sau `build()`:

```gdscript
func _update_commentary() -> void:
	if is_same(_commentary_for, summary):
		return
	var mine := summary
	_commentary_for = mine
	var run := RunCommentary.snapshot(mine)
	%Commentary.text = "%s: …" % Loc.t("ai_commentary")
	var text: String = await RunCommentary.fetch(run)
	if not is_same(_commentary_for, mine):
		return  # a newer run took over the screen while we were waiting
	%Commentary.text = "%s: “%s”" % [Loc.t("ai_commentary"), text]
```

(`main.finish_run()` gán một Dictionary `summary` mới mỗi lượt nên `is_same` phân biệt được các lượt. Phải so với biến cục bộ `mine` — so với `summary` thì sau `await` cả hai đã là summary của lượt mới và câu cũ lọt qua.)

- [ ] **Step 7: Chạy test, xác nhận pass**

```bash
cd "$WS/temple-run-pro-max" && $GODOT --headless --path . --import >/dev/null 2>&1; $GODOT --headless --path . --script res://tests/test_run_commentary.gd; echo "exit=$?"
```
Expected: `ALL PASS`, `exit=0`.

Chạy lại hai test trước để chắc không hồi quy:

```bash
for t in test_gemini test_ai_toggle_row; do $GODOT --headless --path . --script res://tests/$t.gd 2>&1 | tail -1; done
```
Expected: hai dòng `ALL PASS`.

- [ ] **Step 8: Commit**

```bash
cd "$WS/temple-run-pro-max" && git add scripts/ai tests/test_run_commentary.gd* scripts/data/catalog.gd scenes/ui/screens/results.tscn scripts/ui/screens/results_screen.gd && git commit -m "feat: bình luận viên AI cuối lượt trên màn Kết quả

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Export Android có Internet + file key (3D)

**Files:**
- Modify: `temple-run-pro-max/export_presets.cfg`

**Interfaces:** không.

- [ ] **Step 1: Sửa preset**

Trong `temple-run-pro-max/export_presets.cfg`:
- Đổi dòng `include_filter=""` (dòng 8, section `[preset.0]`) thành `include_filter="gemini.local.cfg"`.
- Trong section `[preset.0.options]`, tìm `grep -n "permissions/internet" export_presets.cfg`. Nếu có dòng đó thì đổi giá trị thành `true`; nếu không có thì thêm dòng `permissions/internet=true` ngay dưới dòng `[preset.0.options]`.

- [ ] **Step 2: Kiểm tra preset vẫn đọc được**

```bash
cd "$WS/temple-run-pro-max" && $GODOT --headless --path . --import 2>&1 | grep -i "error" ; grep -n "include_filter=\|permissions/internet" export_presets.cfg
```
Expected: không có dòng error nào liên quan `export_presets`; grep in ra `include_filter="gemini.local.cfg"` và `permissions/internet=true`.

- [ ] **Step 3: Commit**

```bash
cd "$WS/temple-run-pro-max" && git add export_presets.cfg && git commit -m "build: bật quyền Internet và đóng gói gemini.local.cfg khi export Android

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Công tắc AI trong Cài đặt (2D)

**Files:**
- Modify: `Pixel-Adventure/Pixel-Adventure/ui/settings_menu/settings_menu.tscn`
- Modify: `Pixel-Adventure/Pixel-Adventure/ui/settings_menu/settings_menu.gd`
- Create: `Pixel-Adventure/Pixel-Adventure/tests/test_settings_ai.gd`

**Interfaces:**
- Consumes: `Gemini.has_key()`, `Gemini.is_user_enabled()`, `Gemini.set_user_enabled(on)`.
- Produces: không (UI).

- [ ] **Step 1: Viết test**

Tạo `Pixel-Adventure/Pixel-Adventure/tests/test_settings_ai.gd`:

```gdscript
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
```

- [ ] **Step 2: Chạy test, xác nhận fail**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && $GODOT --headless --path . --script res://tests/test_settings_ai.gd; echo "exit=$?"
```
Expected: lỗi `Node not found: .../AiRow/AiButton`, exit khác 0.

- [ ] **Step 3: Thêm dòng vào scene**

Trong `Pixel-Adventure/Pixel-Adventure/ui/settings_menu/settings_menu.tscn`, ngay trước `[node name="MusicVolume" ...]`, thêm:

```
[node name="AiRow" type="HBoxContainer" parent="CenterContainer/DialogPanel/VBoxContainer"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="AiLabel" type="Label" parent="CenterContainer/DialogPanel/VBoxContainer/AiRow"]
layout_mode = 2
size_flags_horizontal = 3
text = "Tính năng AI (Gemini)"

[node name="AiButton" type="Button" parent="CenterContainer/DialogPanel/VBoxContainer/AiRow"]
custom_minimum_size = Vector2(96, 36)
layout_mode = 2
text = "Bật"

```

- [ ] **Step 4: Nối script**

Trong `Pixel-Adventure/Pixel-Adventure/ui/settings_menu/settings_menu.gd`:

Sửa comment đầu file, thêm câu cuối: `## Dòng "Tính năng AI" bật/tắt autoload Gemini (lưu trong prefs riêng của client, không qua SaveManager).`

Sau dòng `@onready var touch_button: ...` thêm:

```gdscript
@onready var ai_button: Button = $CenterContainer/DialogPanel/VBoxContainer/AiRow/AiButton
```

Trong `_ready()`, sau `touch_button.pressed.connect(_on_touch_pressed)` thêm:

```gdscript

	_refresh_ai()
	ai_button.pressed.connect(_on_ai_pressed)
```

Thêm hai hàm trước `func _on_back()`:

```gdscript
func _on_ai_pressed() -> void:
	Gemini.set_user_enabled(not Gemini.is_user_enabled())
	_refresh_ai()

## Không có key thì khoá nút — người chơi không bật được AI không chạy nổi.
func _refresh_ai() -> void:
	if not Gemini.has_key():
		ai_button.text = "Chưa có key"
		ai_button.disabled = true
		return
	ai_button.disabled = false
	ai_button.text = "Bật" if Gemini.is_user_enabled() else "Tắt"
```

- [ ] **Step 5: Chạy test, xác nhận pass**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && $GODOT --headless --path . --script res://tests/test_settings_ai.gd; echo "exit=$?"
```
Expected: `ALL PASS`, `exit=0`.

- [ ] **Step 6: Commit**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && git add ui/settings_menu tests/test_settings_ai.gd* && git commit -m "feat: công tắc Tính năng AI (Gemini) trong Cài đặt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Autoload `AiChat` (2D)

**Files:**
- Create: `Pixel-Adventure/Pixel-Adventure/ui/ai_chat/ai_chat.gd`
- Create: `Pixel-Adventure/Pixel-Adventure/tests/test_ai_chat.gd`
- Modify: `Pixel-Adventure/Pixel-Adventure/project.godot` (autoload)
- Modify: `Pixel-Adventure/Pixel-Adventure/ui/dialogue/dialogue.gd` (getter `is_open`)
- Modify: `Pixel-Adventure/CLAUDE.md`

**Interfaces:**
- Consumes: `Gemini.enabled`, `await Gemini.chat(history, opts) -> String`.
- Produces (autoload `AiChat`, Task 8 dùng):
  - `signal closed`
  - `const RULES: String`, `const FALLBACK_REPLY: String`, `const PRESET_QUESTIONS: Array[String]`, `const MAX_INPUT := 120`
  - `var is_open: bool` (gồm cooldown 200 ms sau khi đóng), `var is_waiting: bool`
  - `func open(speaker: String, greeting: String, system: String) -> bool`
  - `func ask(question: String) -> void` (coroutine)
  - `func close() -> void`
  - Trong test đọc: `_body_label: Label`, `_history: Array`, `_system: String`, `_open: bool`
- `Dialogue.is_open` trả `true` cả khi `AiChat.is_open`.

Thiết kế ngắn: UI dựng bằng code (không có `.tscn`) — panel neo ở **nửa trên** màn hình để bàn phím ảo Android không che. Mở chat → `get_tree().paused = true` (phím gõ không điều khiển nhân vật); autoload có `process_mode = ALWAYS`. Lời chào của NPC không nằm trong `history` (Gemini yêu cầu lượt đầu là `user`), nó nằm trong system prompt do NPC dựng.

- [ ] **Step 1: Viết test**

Tạo `Pixel-Adventure/Pixel-Adventure/tests/test_ai_chat.gd`:

```gdscript
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
	await create_timer(0.25).timeout
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
```

- [ ] **Step 2: Chạy test, xác nhận fail**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && $GODOT --headless --path . --script res://tests/test_ai_chat.gd; echo "exit=$?"
```
Expected: lỗi `Node not found: "AiChat"`, exit khác 0.

- [ ] **Step 3: Viết AiChat**

Tạo `Pixel-Adventure/Pixel-Adventure/ui/ai_chat/ai_chat.gd`:

```gdscript
extends CanvasLayer
## Autoload `AiChat`: khung trò chuyện với NPC bằng Gemini. NPC gọi `AiChat.open(...)` khi
## có persona và `Gemini.enabled`; ngược lại NPC dùng `Dialogue` như cũ.
##
## Lúc mở: `get_tree().paused = true` — phím gõ vào ô chat vẫn cập nhật `Input`, nếu không
## pause thì player (poll Input trong _physics_process) sẽ chạy/nhảy theo. Node này và
## autoload Gemini đều `PROCESS_MODE_ALWAYS` nên nút bấm + HTTP vẫn chạy khi pause.
##
## UI dựng bằng code, neo ở nửa TRÊN màn hình để bàn phím ảo Android không che ô nhập.
## Lời chào của NPC không vào `_history` (Gemini cần lượt đầu là "user") — NPC đưa nó vào
## system prompt.

signal closed

## Giống Dialogue: sau khi đóng, chặn mở lại trong khoảng này để cú nhấn đóng không bị
## NPC/portal bên cạnh bắt lại.
const REOPEN_COOLDOWN_MS := 200
const MAX_INPUT := 120
## Số mục lịch sử gửi lên (6 cặp hỏi-đáp).
const MAX_HISTORY := 12
const PRESET_QUESTIONS: Array[String] = [
	"Tôi nên đi đâu tiếp?",
	"Kể về vùng đất này đi.",
	"Ở đây có bí mật gì không?",
]
const FALLBACK_REPLY := "…(gãi đầu) Ta không nhớ ra. Ngài hỏi lại sau nhé."
## Luật chung nối vào cuối system prompt của mọi NPC.
const RULES := "Luật: luôn nhập vai nhân vật trên và trả lời bằng tiếng Việt, tối đa 2 câu ngắn (dưới 200 ký tự). Chỉ nói về thế giới trong game; không bịa ra phần thưởng, vật phẩm, nhân vật hay cơ chế không có trong bối cảnh ở trên. Nếu bị hỏi chuyện ngoài thế giới game (đời thực, lập trình, chính trị...) thì từ chối khéo đúng giọng nhân vật. Không dùng markdown, không dùng emoji."

var is_open: bool:
	get:
		return _open or Time.get_ticks_msec() - _closed_at_ms < REOPEN_COOLDOWN_MS
## true trong lúc chờ Gemini trả lời — khoá nút gửi để không bắn nhiều request.
var is_waiting: bool = false

var _open := false
var _closed_at_ms := -REOPEN_COOLDOWN_MS
var _system := ""
var _history: Array = []
## Tăng mỗi lần mở/đóng; câu trả lời về muộn của phiên cũ bị bỏ.
var _session := 0

var _panel: PanelContainer
var _speaker_label: Label
var _body_label: Label
var _input: LineEdit
var _send_button: Button
var _preset_buttons: Array[Button] = []


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_panel.visible = false


## Trả về false nếu không mở được (AI tắt / đang có hộp thoại khác / vừa đóng).
func open(speaker: String, greeting: String, system: String) -> bool:
	if not Gemini.enabled or Dialogue.is_open:
		return false
	_open = true
	_session += 1
	_system = system
	_history = []
	_speaker_label.text = speaker
	_body_label.text = greeting
	_input.clear()
	_set_waiting(false)
	_panel.visible = true
	get_tree().paused = true
	# Trên điện thoại focus sẽ bật bàn phím che mất câu chào — để người chơi tự chạm.
	if not DisplayServer.is_touchscreen_available():
		_input.grab_focus()
	return true


## Gửi một câu hỏi. Bỏ qua nếu đang chờ, chưa mở, hoặc câu rỗng.
func ask(question: String) -> void:
	var q := question.strip_edges().left(MAX_INPUT)
	if not _open or is_waiting or q == "":
		return
	var session := _session
	_history.append({"role": "user", "text": q})
	_input.clear()
	_body_label.text = "…"
	_set_waiting(true)
	var reply: String = await Gemini.chat(_recent_history(), {"system": _system, "max_tokens": 150})
	if session != _session:
		return  # đã đóng (hoặc mở phiên mới) trong lúc chờ
	if reply == "":
		_history.pop_back()  # giữ lịch sử xen kẽ user/model
		reply = FALLBACK_REPLY
	else:
		_history.append({"role": "model", "text": reply})
	_body_label.text = reply
	_set_waiting(false)


func close() -> void:
	if not _open:
		return
	_open = false
	_session += 1
	_closed_at_ms = Time.get_ticks_msec()
	_set_waiting(false)
	_input.release_focus()
	_panel.visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _recent_history() -> Array:
	var h := _history.slice(-MAX_HISTORY)
	while not h.is_empty() and h[0].role != "user":
		h.pop_front()
	return h


func _set_waiting(waiting: bool) -> void:
	is_waiting = waiting
	_send_button.disabled = waiting
	_input.editable = not waiting
	for b in _preset_buttons:
		b.disabled = waiting


func _build_ui() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.13, 0.96)
	style.border_color = Color(0.85, 0.78, 0.55, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_left = 40.0
	_panel.offset_right = -40.0
	_panel.offset_top = 20.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	_speaker_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(0, 48)
	_body_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_body_label)

	var presets := HFlowContainer.new()
	presets.add_theme_constant_override("h_separation", 6)
	presets.add_theme_constant_override("v_separation", 6)
	vbox.add_child(presets)
	for q in PRESET_QUESTIONS:
		var b := Button.new()
		b.text = q
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(ask.bind(q))
		presets.add_child(b)
		_preset_buttons.append(b)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Hỏi điều gì đó…"
	_input.max_length = MAX_INPUT
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(ask)
	row.add_child(_input)
	_send_button = Button.new()
	_send_button.text = "Gửi"
	_send_button.focus_mode = Control.FOCUS_NONE
	_send_button.pressed.connect(func() -> void: ask(_input.text))
	row.add_child(_send_button)

	var bye := Button.new()
	bye.text = "Tạm biệt"
	bye.focus_mode = Control.FOCUS_NONE
	bye.size_flags_horizontal = Control.SIZE_SHRINK_END
	bye.pressed.connect(close)
	vbox.add_child(bye)
```

- [ ] **Step 4: Đăng ký autoload + sửa `Dialogue.is_open`**

Trong `Pixel-Adventure/Pixel-Adventure/project.godot`, ngay sau dòng `Dialogue="*res://ui/dialogue/dialogue.tscn"` thêm:

```ini
AiChat="*res://ui/ai_chat/ai_chat.gd"
```

Trong `Pixel-Adventure/Pixel-Adventure/ui/dialogue/dialogue.gd`, thay block getter:

```gdscript
## true khi đang mở VÀ trong lúc hồi sau khi đóng — mọi chỗ polling `interact` (portal,
## hub_sign, story_sign, npc) kiểm tra cờ này để không kích hoạt trùng.
var is_open: bool:
	get:
		return _open or Time.get_ticks_msec() - _closed_at_ms < REOPEN_COOLDOWN_MS
```

bằng:

```gdscript
## true khi đang mở VÀ trong lúc hồi sau khi đóng — mọi chỗ polling `interact` (portal,
## hub_sign, story_sign, npc) kiểm tra cờ này để không kích hoạt trùng. Tính cả `AiChat`
## (khung chat AI với NPC) để các chỗ đó không phải kiểm tra hai autoload.
var is_open: bool:
	get:
		return _open or Time.get_ticks_msec() - _closed_at_ms < REOPEN_COOLDOWN_MS or AiChat.is_open
```

`Dialogue.open()` đã `return false` khi `is_open`, nên tự từ chối lúc AiChat đang mở.

- [ ] **Step 5: Chạy test, xác nhận pass**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && $GODOT --headless --path . --import >/dev/null 2>&1; $GODOT --headless --path . --script res://tests/test_ai_chat.gd; echo "exit=$?"
```
Expected: `ALL PASS`, `exit=0`.

- [ ] **Step 6: Tài liệu**

Trong `Pixel-Adventure/CLAUDE.md`, mục **Autoloads**, ngay sau gạch đầu dòng `Dialogue`, thêm:

```markdown
- `AiChat` (`ui/ai_chat/ai_chat.gd`, UI dựng bằng code) — khung chat NPC bằng Gemini. `open(speaker, greeting, system) -> bool` (false nếu `Gemini.enabled == false` hoặc đang có hộp thoại) **pause cây scene** (phím gõ vẫn cập nhật `Input`); `close()` bỏ pause + emit `closed`. `ask(q)` khoá gửi khi đang chờ, lỗi → `FALLBACK_REPLY`, trả lời về sau khi đóng bị bỏ (đếm `_session`). `is_open` có cooldown 200ms như Dialogue, và `Dialogue.is_open` tính cả `AiChat.is_open`. Test: `tests/test_ai_chat.gd`.
```

- [ ] **Step 7: Commit**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && git add ui/ai_chat tests/test_ai_chat.gd* project.godot ui/dialogue/dialogue.gd ../CLAUDE.md && git commit -m "feat: khung chat AI với NPC (autoload AiChat)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: NPC ở làng dùng AiChat (2D)

**Files:**
- Modify: `Pixel-Adventure/Pixel-Adventure/objects/npc/npc.gd`
- Modify: `Pixel-Adventure/Pixel-Adventure/levels/hub/hub.tscn`
- Create: `Pixel-Adventure/Pixel-Adventure/tests/test_npc_ai.gd`

**Interfaces:**
- Consumes: `AiChat.open(speaker, greeting, system) -> bool`, `AiChat.closed`, `AiChat.RULES`, `Gemini.enabled`, `Dialogue.open(lines, speaker) -> bool`, `Progression.next_objective() -> Dictionary{"text", "world"}`.
- Produces: `@export_multiline var ai_persona: String` trên NPC; `func _open_conversation() -> bool`; `func _ai_system_prompt(lines: PackedStringArray) -> String`.

- [ ] **Step 1: Viết test**

Tạo `Pixel-Adventure/Pixel-Adventure/tests/test_npc_ai.gd`:

```gdscript
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
	await create_timer(0.25).timeout


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
```

- [ ] **Step 2: Chạy test, xác nhận fail**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && $GODOT --headless --path . --script res://tests/test_npc_ai.gd; echo "exit=$?"
```
Expected: lỗi `Invalid assignment of property or key 'ai_persona'` hoặc `Nonexistent function '_open_conversation'`, exit khác 0.

- [ ] **Step 3: Sửa npc.gd**

Trong `Pixel-Adventure/Pixel-Adventure/objects/npc/npc.gd`:

(a) Sửa dòng 3 của comment đầu file. Dòng cũ:

```gdscript
## Đứng gần + bấm `interact` (E) → mở hộp thoại (Dialogue autoload). Bong bóng "Hello"
```

Dòng mới (thay đúng một dòng bằng hai dòng):

```gdscript
## Đứng gần + bấm `interact` (E) → mở hộp thoại (Dialogue autoload), hoặc khung chat AI
## (AiChat) nếu NPC có `ai_persona` và Gemini đang bật. Bong bóng "Hello"
```

(b) Ngay sau dòng `@export var dynamic_line: DynamicLine = DynamicLine.NONE` thêm:

```gdscript
## Tính cách + vai trò của NPC, gửi cho Gemini trong system prompt. Để trống = chỉ có thoại
## tĩnh. Có persona VÀ `Gemini.enabled` → bấm E mở `AiChat` thay cho `Dialogue`.
@export_multiline var ai_persona: String = ""
```

(c) Trong `_ready()`, ngay sau `Dialogue.finished.connect(_on_dialogue_finished)` thêm:

```gdscript
	AiChat.closed.connect(_on_dialogue_finished)
```

(d) Trong `_start_dialogue()`, thay dòng

```gdscript
	if not Dialogue.open(_build_lines(), speaker):
```

bằng

```gdscript
	if not _open_conversation():
```

(e) Thêm hai hàm ngay sau `_start_dialogue()`:

```gdscript
## AiChat nếu NPC có persona và AI đang bật, không thì hộp thoại tĩnh như cũ. False nếu
## không mở được gì (đang có hộp thoại khác) — cùng hợp đồng với `Dialogue.open`.
func _open_conversation() -> bool:
	var lines := _build_lines()
	if lines.is_empty():
		return false
	if ai_persona != "" and Gemini.enabled:
		return AiChat.open(speaker, lines[0], _ai_system_prompt(lines))
	return Dialogue.open(lines, speaker)

## System prompt cho Gemini: vai + những gì NPC "biết" (chính các dòng thoại tĩnh, đã gồm
## mục tiêu kế tiếp / tâm trạng / mẹo world) + luật chung của AiChat.
func _ai_system_prompt(lines: PackedStringArray) -> String:
	return "\n".join(PackedStringArray([
		"Ngươi là %s, một NPC ở ngôi làng trung tâm (hub) trong game platformer 2D Pixel Adventure." % speaker,
		"Tính cách và vai trò: %s" % ai_persona,
		"Người chơi là vị vua đang giành lại vương quốc khỏi bọn Heo; ngươi gọi họ là 'ngài'.",
		"Mục tiêu hiện tại của người chơi: %s" % String(Progression.next_objective()["text"]),
		_ability_line(),
		"Những điều ngươi đã nói và biết: %s" % " ".join(lines),
		"Ngươi vừa chào người chơi bằng câu: \"%s\"" % lines[0],
		AiChat.RULES,
	]))
```

- [ ] **Step 4: Persona cho 3 NPC ở hub**

Trong `Pixel-Adventure/Pixel-Adventure/levels/hub/hub.tscn`, thêm một dòng `ai_persona` vào mỗi block NPC, ngay sau dòng `speaker = ...` của block đó:

Block `[node name="Advisor" ...]`, sau `speaker = "Cố vấn"`:
```
ai_persona = "Cố vấn già trung thành của nhà vua, điềm đạm, nói năng trang trọng. Nắm rõ ba cánh cổng của làng (Rừng Ranh Giới, Lâu Đài Thất Thủ, Hầm Ngục Cổ) và luôn hướng người chơi tới mục tiêu kế tiếp."
```

Block `[node name="Villager" ...]`, sau `speaker = "Dân làng"`:
```
ai_persona = "Dân làng chất phác, hay lo nhưng hiếu khách, nói giọng bình dân. Hay kể chuyện làng bị bọn Heo đốt phá, chuyện mùa màng và niềm tin vào nhà vua."
```

Block `[node name="Deserter" ...]`, sau `speaker = "Cá Mập đào ngũ"`:
```
ai_persona = "Lính đánh thuê Cá Mập vừa đào ngũ khỏi quân Vua Heo, nhát gan, hay thì thào và sợ bị phát hiện. Biết nhiều về bom và cách đánh của quân Heo, kể dần khi được tin tưởng."
```

- [ ] **Step 5: Chạy test, xác nhận pass**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && $GODOT --headless --path . --import >/dev/null 2>&1; $GODOT --headless --path . --script res://tests/test_npc_ai.gd; echo "exit=$?"
```
Expected: `ALL PASS`, `exit=0`.

Chạy toàn bộ test 2D:

```bash
for t in test_gemini test_settings_ai test_ai_chat test_npc_ai; do echo "== $t"; $GODOT --headless --path . --script res://tests/$t.gd 2>&1 | tail -1; done
```
Expected: 4 dòng `ALL PASS`.

Kiểm tra hub.tscn vẫn load được:

```bash
$GODOT --headless --path . --import 2>&1 | grep -i "hub.tscn" ; echo "grep-exit=$?"
```
Expected: không in lỗi nào về `hub.tscn` (`grep-exit=1`).

- [ ] **Step 6: Commit**

```bash
cd "$WS/Pixel-Adventure/Pixel-Adventure" && git add objects/npc/npc.gd levels/hub/hub.tscn tests/test_npc_ai.gd* && git commit -m "feat: NPC ở làng trò chuyện bằng Gemini (persona + fallback thoại tĩnh)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Kiểm tra thủ công với key thật (demo checklist)

**Files:** không sửa file nào (nếu phát hiện lỗi → quay lại task tương ứng, sửa + thêm test).

**Interfaces:** không.

Cần một Gemini API key thật trong `GEMINI_API_KEY`. Nếu môi trường không có key, **dừng và báo người dùng** tự chạy checklist này — không đánh dấu hoàn thành.

- [ ] **Step 1: Gọi thật một lần (smoke test)**

Tạo script tạm trong scratchpad (không commit), chạy trong `temple-run-pro-max`:

```gdscript
extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var g: Node = root.get_node("Gemini")
	print("enabled=", g.enabled, " model=", g.model)
	print("text=", await g.generate_text("Nói 'xin chào' bằng 3 từ.", {"max_tokens": 30}))
	print("json=", await g.generate_json("Cho một con số từ 1 đến 9.", {"type": "OBJECT", "properties": {"n": {"type": "INTEGER"}}, "required": ["n"]}))
	quit(0)
```

```bash
cd "$WS/temple-run-pro-max" && GEMINI_API_KEY="$GEMINI_API_KEY" $GODOT --headless --path . --script <scratchpad>/smoke.gd
```
Expected: `enabled=true`, `text=` một câu tiếng Việt khác rỗng, `json={ "n": <số> }`. Nếu HTTP 404 → tên model không còn tồn tại: đổi `DEFAULT_MODEL`/`model=` sang model đang có trong AI Studio.

- [ ] **Step 2: Temple Run Pro Max (mở editor, F5, có key)**
  1. Chạy một lượt, chết → màn Kết quả hiện "Bình luận viên: …" rồi đổi thành câu AI trong ~1–3 s, đúng ngôn ngữ đang chọn.
  2. Bấm "Nhân đôi xu" (nếu có) → bình luận KHÔNG đổi (không gọi lại).
  3. Bấm "Chạy lại" ngay khi còn "…" → lượt mới chết → chỉ thấy bình luận của lượt mới.
  4. Cài đặt → tắt "Tính năng AI" → chơi lại → thấy câu dự phòng ngay lập tức.
  5. Bật lại, ngắt Wi-Fi → chơi lại → sau ≤ 8 s thấy câu dự phòng, game không đơ.
  6. Chạy không có key (terminal không có biến env, không có file cfg) → Cài đặt hiện "chưa có API key", nút xám.

- [ ] **Step 3: Pixel Adventure (F5, có key)**
  1. Vào làng, tới Cố vấn, bấm E → khung chat ở nửa trên, câu chào hiện ngay; nhân vật đứng yên khi gõ phím A/D/Space vào ô chat.
  2. Bấm "Tôi nên đi đâu tiếp?" → trả lời nhập vai, khớp mục tiêu hiện tại; bấm liên tục khi đang "…" → nút bị khoá.
  3. Hỏi "viết code python cho tôi" → NPC từ chối khéo theo vai.
  4. Bấm "Tạm biệt" → game chạy tiếp; bấm E ngay → không mở lại hộp thoại trong tích tắc đó.
  5. Tới Cá Mập đào ngũ khi đang hoảng → vẫn "Đứng yên..." như cũ (không chat được khi sợ).
  6. Tắt AI trong Cài đặt → NPC dùng hộp thoại tĩnh như trước.
  7. Ngắt mạng → hỏi → sau ≤ 8 s NPC nói câu "…(gãi đầu)…", vẫn đóng được.

- [ ] **Step 4: Android (tuỳ chọn, cho buổi demo)**

Tạo `temple-run-pro-max/gemini.local.cfg` từ `gemini.example.cfg` với key thật; export APK; cài lên máy; lặp lại Step 2 mục 1 và 5. Với Pixel Adventure: tạo preset Android theo README (quyền Internet + filter `gemini.local.cfg`), lặp lại Step 3 mục 1–2 trên cảm ứng, kiểm tra bàn phím ảo không che khung chat.

- [ ] **Step 5: Ghi kết quả**

Báo lại cho người dùng: mục nào đạt, mục nào lỗi (kèm log). Không commit gì ở task này.
