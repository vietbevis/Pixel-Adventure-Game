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
	var parsed: Variant = _parse_json(raw)
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
	var data: Variant = _parse_json(body)
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


## JSON.parse_string in ERROR đỏ ra log khi gặp chuỗi hỏng — output AI hỏng là chuyện bình
## thường, nên dùng instance JSON (chỉ trả mã lỗi). null nếu không parse được.
static func _parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


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
	var data: Variant = _parse_json(FileAccess.get_file_as_string(CACHE_PATH))
	if not (data is Dictionary):
		return
	for key: String in data:
		var entry: Variant = data[key]
		if entry is Dictionary and entry.has("value"):
			_cache[key] = {"value": entry.value, "saved_at": int(entry.get("saved_at", 0)), "persist": true}
