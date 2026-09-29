# Gemini AI — Đợt 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Huấn luyện viên AI (màn Thống kê) + Truyền thuyết vùng cảnh (banner khi đổi vùng) cho Temple Run Pro Max; Lời thoại boss động cho Pixel Adventure — đều có dự phòng tĩnh và không request mạng giữa gameplay.

**Architecture:** Dùng lại autoload `Gemini` của đợt 1 (thêm `cached(key)` và `cache_path` đổi được). 3D: hai lớp tĩnh `Coach`, `BiomeLore` trong `scripts/ai/`. 2D: autoload `BossVoice` (CanvasLayer tự dựng label) + `SaveManager.boss_attempts`.

**Tech Stack:** Godot 4.7.2 GDScript, Gemini REST `v1beta` model `gemini-3.5-flash-lite`, test headless `tests/run_tests.sh`.

**Spec:** `docs/superpowers/specs/2026-09-29-gemini-ai-integration-design.md` §5.2, §5.3, §6.2

## Global Constraints

- Làm thẳng trên `main` (yêu cầu của người dùng), commit mỗi task.
- `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`; test: `tests/run_tests.sh [file...]` trong thư mục project Godot (2D: `Pixel-Adventure/Pixel-Adventure`).
- Test nạp class 3D bằng `load()` lúc runtime (file test biên dịch trước khi autoload thành global). Chờ cooldown/thời hạn tính bằng ms thật thì dùng vòng `Time.get_ticks_msec()`, không dùng `create_timer`.
- Test không được ghi đè dữ liệu thật: đặt `Gemini.cache_path` sang file test; test 2D sao lưu và khôi phục `user://save_data.json`.
- `addons/gemini/gemini.gd` và `tests/test_gemini.gd` phải giống hệt ở hai repo.
- Số từ JSON của Gemini về là float (`7.0`) → luôn `int()`.
- Commit kết thúc bằng `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. Cache truyền thuyết cũ (khác phong cách/ngôn ngữ) không được hiện sai vùng → khoá cache theo `style_lang`, test đổi `Loc.lang`.
2. Người chơi tắt AI trong Cài đặt → không hiện truyền thuyết AI từ cache (test `line_for` khi AI tắt).
3. AI gợi ý nâng cấp đã max / id bịa → bỏ, dùng gợi ý luật (test `validate`).
4. Hai trận boss nối nhau, request trận trước về muộn → không ghi đè câu trận sau (test fight id).
5. `player_died` ngoài màn boss (màn thường) → không hiện câu boss (test không có node nhóm `boss`).

---

### Task 1: `Gemini.cached()` + `cache_path` (cả hai repo)

**Files:** Modify `addons/gemini/gemini.gd`, `tests/test_gemini.gd` (3D rồi copy nguyên sang 2D).

**Produces:** `func cached(key: String) -> Variant` (null nếu chưa có); `var cache_path: String = CACHE_PATH` (dùng cho `_save_cache`/`_load_cache`).

- [ ] Step 1: thêm test vào `test_gemini.gd` (gọi trong `_run` sau `test_cache`):

```gdscript
func test_cached_and_persist() -> void:
	var g := make_client()
	g.cache_path = "user://gemini_cache_test.json"
	g.transport = fake(200, ok_body("{\"a\": 1}"))
	check(g.cached("p") == null, "cached() missing -> null")
	await g.generate_json("x", {"type": "OBJECT"}, {"cache_key": "p", "persist": true})
	check(g.cached("p") is Dictionary and int(g.cached("p").a) == 1, "cached() returns stored value")
	var g2: Node = GeminiScript.new()
	g2.cache_path = "user://gemini_cache_test.json"
	root.add_child(g2)
	check(g2.cached("p") is Dictionary, "persisted cache reloads from cache_path")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://gemini_cache_test.json"))
	g.queue_free()
	g2.queue_free()
```

Lưu ý: `g2.cache_path` phải gán TRƯỚC `add_child` (vì `_ready` đọc cache).

- [ ] Step 2: chạy → FAIL (`cached` không tồn tại).
- [ ] Step 3: trong client: thêm `var cache_path: String = CACHE_PATH` (sau `var transport`), thay `CACHE_PATH` bằng `cache_path` trong `_save_cache`/`_load_cache`, thêm sau `cache_age`:

```gdscript
## Giá trị đã cache cho `key` (kể cả nạp từ đĩa), hoặc null. Tính năng đọc cache lúc đang
## chơi mà không gọi mạng (vd. truyền thuyết vùng cảnh).
func cached(key: String) -> Variant:
	return _cache[key].value if _cache.has(key) else null
```

- [ ] Step 4: chạy → PASS; copy `gemini.gd` + `test_gemini.gd` sang 2D, chạy suite 2D → PASS; `diff` hai bản giống hệt.
- [ ] Step 5: commit ở cả hai repo: `feat: Gemini.cached() + cache_path đổi được cho test`.

---

### Task 2: Huấn luyện viên AI (3D)

**Files:** Create `scripts/ai/coach.gd`, `tests/test_coach.gd`; Modify `scripts/ui/screens/stats_screen.gd`, `scripts/autoload/loc.gd`.

**Consumes:** `Gemini.enabled/generate_json/clean_text`, `Profile.stat/upgrade_level/upgrade_price/balance`, `Catalog.UPGRADES/UPGRADE_PRICES/upgrade()`, `Loc`.
**Produces:** `class_name Coach` — `snapshot() -> Dictionary`, `build_prompt(s) -> String`, `validate(data, s) -> Dictionary` (`{}` nếu hỏng), `fallback(s) -> Dictionary`, `cheapest(s) -> String`, `fetch(s) -> Dictionary` (coroutine, luôn có `advice`), `format(r, s) -> String`.

- [ ] Step 1: tạo `tests/test_coach.gd`:

```gdscript
extends SceneTree
## Chạy: tests/run_tests.sh tests/test_coach.gd

var _fails := 0
var calls := 0
var C: GDScript


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


func sample(runs := 10, falls := 7, catches := 3, coins := 1500) -> Dictionary:
	return {"runs": runs, "falls": falls, "catches": catches, "avg_distance": 800, "best_distance": 2100,
		"jumps_per_run": 12.5, "slides_per_run": 6.0, "turns_per_run": 9.0, "revives": 2, "coins": coins, "lang": "vi",
		"upgrades": {
			"magnet": {"name": "Nam Châm", "level": 5, "max": 5, "price": -1},
			"shield": {"name": "Khiên", "level": 1, "max": 5, "price": 1200},
			"boost": {"name": "Tăng Tốc", "level": 0, "max": 5, "price": 500},
			"double": {"name": "Nhân Đôi", "level": 3, "max": 5, "price": 5000},
		}}


func _run() -> void:
	C = load("res://scripts/ai/coach.gd")
	var gemini: Node = root.get_node("Gemini")
	root.get_node("Loc").lang = "vi"

	var snap: Dictionary = C.snapshot()
	check(snap.upgrades.size() == 4 and int(snap.upgrades.magnet.max) == 5, "snapshot lists 4 upgrades with max 5")
	check(snap.has("falls") and snap.has("avg_distance") and snap.lang == "vi", "snapshot has stats and lang")

	var p: String = C.build_prompt(sample())
	check(p.contains("Vietnamese") and p.contains("boost") and p.contains("MAXED"), "prompt lists upgrades, marks maxed")

	check(C.validate({"advice": "Nhảy sớm hơn.", "recommend_id": "boost"}, sample()).recommend_id == "boost", "valid id kept")
	check(C.validate({"advice": "x", "recommend_id": "magnet"}, sample()).recommend_id == "", "maxed id dropped")
	check(C.validate({"advice": "x", "recommend_id": "laser"}, sample()).recommend_id == "", "unknown id dropped")
	check(C.validate({"advice": "", "recommend_id": "boost"}, sample()).is_empty(), "empty advice -> invalid")
	check(C.validate("nope", sample()).is_empty(), "non-dict -> invalid")
	check(String(C.validate({"advice": "a".repeat(400), "recommend_id": ""}, sample()).advice).length() <= C.MAX_ADVICE, "long advice truncated")

	check(C.cheapest(sample()) == "boost", "cheapest affordable upgrade")
	check(C.cheapest(sample(10, 7, 3, 100)) == "boost", "cheapest non-max when none affordable")
	var fb_f: Dictionary = C.fallback(sample(10, 7, 3))
	var fb_c: Dictionary = C.fallback(sample(10, 2, 8))
	var fb_0: Dictionary = C.fallback(sample(0, 0, 0))
	check(fb_f.advice != fb_c.advice and fb_0.advice != fb_f.advice, "fallback advice depends on falls/catches/runs")
	check(fb_f.recommend_id == "boost", "fallback recommends cheapest")

	gemini.configure("")
	calls = 0
	var off: Dictionary = await C.fetch(sample())
	check(off.advice == fb_f.advice and calls == 0, "AI off -> fallback, no request")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	gemini._cache = {}
	gemini.transport = fake(200, "{\"advice\": \"Trượt sớm hơn ở rào thấp.\", \"recommend_id\": \"shield\"}")
	var on: Dictionary = await C.fetch(sample())
	check(on.advice == "Trượt sớm hơn ở rào thấp." and on.recommend_id == "shield", "AI on -> AI advice + valid pick")
	gemini._cache = {}
	gemini.transport = fake(200, "{\"advice\": \"Cố lên!\", \"recommend_id\": \"magnet\"}")
	var bad_pick: Dictionary = await C.fetch(sample())
	check(bad_pick.advice == "Cố lên!" and bad_pick.recommend_id == "boost", "AI maxed pick -> rule pick")
	gemini._cache = {}
	gemini.transport = fake(500, "x")
	var err: Dictionary = await C.fetch(sample())
	check(err.advice == fb_f.advice, "AI error -> fallback")
	check(C.format(on, sample()).contains("Khiên"), "format names the upgrade")

	gemini.configure("")
	var screen: Control = load("res://scenes/ui/screens/stats.tscn").instantiate()
	root.add_child(screen)
	screen.build()
	var box: Node = screen.get_node("%Content").get_child(0)
	check(box.name == "Coach", "coach box is first in stats content")
	await screen._ask_coach()
	check(screen._coach_label.visible and screen._coach_label.text != "…", "ask coach shows advice (AI off)")
	screen.queue_free()

	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
```

- [ ] Step 2: chạy → FAIL (không có `coach.gd`).
- [ ] Step 3: tạo `scripts/ai/coach.gd`:

```gdscript
class_name Coach
extends RefCounted
## Stats-screen coach: one piece of advice + one upgrade to buy next, from Gemini with the
## player's lifetime stats. The pick is validated against the real upgrade list (must exist
## and not be maxed); a rule-based fallback covers AI off / errors / bad picks.

const MAX_ADVICE := 220
const SYSTEM := "You are a friendly, concise coach for the endless runner game Temple Run Pro Max. Based on the player's stats give ONE practical piece of advice (at most 2 short sentences, under 200 characters) and pick ONE upgrade id from the list to buy next (never a MAXED one). Plain text only: no markdown, no emojis."
const SCHEMA := {"type": "OBJECT", "properties": {
	"advice": {"type": "STRING"}, "recommend_id": {"type": "STRING"}}, "required": ["advice", "recommend_id"]}
const FALLBACK := {
	"first": ["Play a few runs first, then I can read your habits.", "Chạy thử vài lượt đã, rồi tôi mới đọc được thói quen của bạn."],
	"falls": ["Most of your runs end in a chasm: watch the edges and swipe a beat before each turn.", "Bạn hay rơi vực nhất: nhìn kỹ mép đường và vuốt sớm một nhịp trước mỗi khúc cua."],
	"catches": ["The demons catch you after too many hits: slide under barriers and jump earlier.", "Lũ quỷ bắt được bạn vì va chạm quá nhiều: trượt qua rào và nhảy sớm hơn."],
}


static func snapshot() -> Dictionary:
	var runs := int(Profile.stat("runs"))
	var upgrades := {}
	for kind: String in Catalog.UPGRADES:
		upgrades[kind] = {"name": Loc.pick(Catalog.upgrade(kind).name), "level": Profile.upgrade_level(kind),
			"max": Catalog.UPGRADE_PRICES.size(), "price": Profile.upgrade_price(kind)}
	return {
		"runs": runs,
		"falls": int(Profile.stat("falls")),
		"catches": int(Profile.stat("catches")),
		"avg_distance": int(_per_run("total_distance", runs)),
		"best_distance": int(Profile.stat("best_distance")),
		"jumps_per_run": snappedf(_per_run("jumps", runs), 0.1),
		"slides_per_run": snappedf(_per_run("slides", runs), 0.1),
		"turns_per_run": snappedf(_per_run("turns", runs), 0.1),
		"revives": int(Profile.stat("revives")),
		"coins": Profile.balance("coins"),
		"upgrades": upgrades,
		"lang": Loc.lang,
	}


static func _per_run(key: String, runs: int) -> float:
	return Profile.stat(key) / maxf(runs, 1.0)


static func build_prompt(s: Dictionary) -> String:
	var lines := PackedStringArray([
		"Answer in %s." % ("Vietnamese" if s.lang == "vi" else "English"),
		"Runs: %d. Ended by falling into a chasm: %d. Caught by the demons: %d. Revives used: %d." % [s.runs, s.falls, s.catches, s.revives],
		"Average distance: %d m, best: %d m. Per run: %.1f jumps, %.1f slides, %.1f turns." % [
			s.avg_distance, s.best_distance, s.jumps_per_run, s.slides_per_run, s.turns_per_run],
		"Coins available: %d." % s.coins,
		"Upgrades (id: name, level, next price):",
	])
	for kind: String in s.upgrades:
		var u: Dictionary = s.upgrades[kind]
		var state := "MAXED" if int(u.level) >= int(u.max) else "next level costs %d coins" % int(u.price)
		lines.append("- %s: %s, level %d/%d, %s" % [kind, u.name, int(u.level), int(u.max), state])
	return "\n".join(lines)


## {advice, recommend_id} from raw AI output, or {} if unusable. A bad pick becomes "".
static func validate(data: Variant, s: Dictionary) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var advice := Gemini.clean_text(str(data.get("advice", "")))
	if advice == "":
		return {}
	if advice.length() > MAX_ADVICE:
		advice = advice.left(MAX_ADVICE - 1).strip_edges() + "…"
	var rid := str(data.get("recommend_id", ""))
	if not _upgradable(rid, s):
		rid = ""
	return {"advice": advice, "recommend_id": rid}


static func _upgradable(id: String, s: Dictionary) -> bool:
	return s.upgrades.has(id) and int(s.upgrades[id].level) < int(s.upgrades[id].max)


## Cheapest upgrade the player can afford, else the cheapest one not maxed, else "".
static func cheapest(s: Dictionary) -> String:
	var best := ""
	var best_affordable := ""
	for kind: String in s.upgrades:
		if not _upgradable(kind, s):
			continue
		var price := int(s.upgrades[kind].price)
		if best == "" or price < int(s.upgrades[best].price):
			best = kind
		if price <= int(s.coins) and (best_affordable == "" or price < int(s.upgrades[best_affordable].price)):
			best_affordable = kind
	return best_affordable if best_affordable != "" else best


static func fallback(s: Dictionary) -> Dictionary:
	var key := "first"
	if int(s.runs) > 0:
		key = "falls" if int(s.falls) > int(s.catches) else "catches"
	return {"advice": Loc.pick(FALLBACK[key]), "recommend_id": cheapest(s)}


## Coroutine. Always returns {advice, recommend_id}.
static func fetch(s: Dictionary) -> Dictionary:
	if not Gemini.enabled:
		return fallback(s)
	var data: Variant = await Gemini.generate_json(build_prompt(s), SCHEMA,
		{"system": SYSTEM, "max_tokens": 200, "cache_key": "coach_%s_%d" % [s.lang, s.runs]})
	var out := validate(data, s)
	if out.is_empty():
		return fallback(s)
	if out.recommend_id == "":
		out.recommend_id = cheapest(s)
	return out


static func format(r: Dictionary, s: Dictionary) -> String:
	var text := String(r.advice)
	var rid := String(r.get("recommend_id", ""))
	if rid != "" and s.upgrades.has(rid):
		text += "\n" + Loc.t("coach_pick", s.upgrades[rid].name)
	return text
```

- [ ] Step 4: Loc — sau dòng `"ai_commentary": ...` thêm:

```gdscript
	"coach_ask": ["Ask the coach", "Hỏi huấn luyện viên"],
	"coach_pick": ["Suggested upgrade: %s", "Nên nâng cấp: %s"],
```

- [ ] Step 5: `stats_screen.gd` — thêm biến + `_ready` + bỏ qua khối Coach trong vòng lặp + hàm hỏi:

```gdscript
var _coach_button: Button
var _coach_label: Label


func _ready() -> void:
	_build_coach()  # before super() so UI.wire_buttons() gives it the click sound
	super()


func build() -> void:
	set_title(Loc.t("stats"))
	_coach_button.text = Loc.t("coach_ask")
	for row in %Content.get_children():
		if not row.has_node("Key"):
			continue  # the coach box
		var key := String(row.name)
		(row.get_node("Key") as Label).text = Loc.t("st_" + key)
		(row.get_node("Value") as Label).text = _value(key)


func _build_coach() -> void:
	var box := VBoxContainer.new()
	box.name = "Coach"
	box.add_theme_constant_override("separation", 8)
	_coach_button = Button.new()
	_coach_button.custom_minimum_size = Vector2(0, 72)
	_coach_button.focus_mode = Control.FOCUS_NONE
	_coach_button.theme_type_variation = &"ButtonRed"
	_coach_button.add_theme_font_size_override("font_size", 30)
	_coach_button.pressed.connect(_ask_coach)
	box.add_child(_coach_button)
	_coach_label = Label.new()
	_coach_label.custom_minimum_size = Vector2(200, 0)
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coach_label.theme_type_variation = &"LabelSoft"
	_coach_label.add_theme_font_size_override("font_size", 28)
	_coach_label.visible = false
	box.add_child(_coach_label)
	%Content.add_child(box)
	%Content.move_child(box, 0)


func _ask_coach() -> void:
	_coach_button.disabled = true
	_coach_label.visible = true
	_coach_label.text = "…"
	var s := Coach.snapshot()
	var r: Dictionary = await Coach.fetch(s)
	_coach_label.text = Coach.format(r, s)
	_coach_button.disabled = false
```

(Giữ `const SUFFIX` và `_value` như cũ; xoá `build()` cũ vì đã thay bằng bản trên.)

- [ ] Step 6: `tests/run_tests.sh` → `ALL TEST FILES PASS (4)`. Commit: `feat: huấn luyện viên AI trên màn Thống kê`.

---

### Task 3: Truyền thuyết vùng cảnh (3D)

**Files:** Create `scripts/ai/biome_lore.gd`, `tests/test_biome_lore.gd`; Modify `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`, `scripts/world/main.gd`, `scripts/ui/screens/menu_screen.gd`.

**Consumes:** `Gemini.enabled/cache_age/cached/generate_json/clean_text/cache_path`, `Catalog.biomes()/modern()`, `Loc`.
**Produces:** `class_name BiomeLore` — `cache_key() -> String`, `build_prompt() -> String`, `schema() -> Dictionary`, `prefetch() -> void` (coroutine), `sanitize(data, count) -> Dictionary`, `line_for(index) -> String`; `Hud.show_banner(text, seconds := 2.5, lore := "")`.

- [ ] Step 1: tạo `tests/test_biome_lore.gd`:

```gdscript
extends SceneTree
## Chạy: tests/run_tests.sh tests/test_biome_lore.gd

var _fails := 0
var calls := 0
var L: GDScript


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


func fake(text: String) -> Callable:
	return func(_u: String, _h: PackedStringArray, _b: String, _t: float) -> Dictionary:
		calls += 1
		return {"ok": true, "code": 200, "body": ok_body(text)}


func _run() -> void:
	L = load("res://scripts/ai/biome_lore.gd")
	var gemini: Node = root.get_node("Gemini")
	var loc: Node = root.get_node("Loc")
	gemini.cache_path = "user://gemini_cache_test.json"
	gemini._cache = {}
	loc.lang = "vi"

	var data := {"biomes": [
		{"index": 0.0, "lines": ["Rừng già thì thầm tên kẻ chạy trốn.", "", "x".repeat(200)]},
		{"index": 1, "lines": ["Tàn tích đỏ rực dưới hoàng hôn."]},
		{"index": 9, "lines": ["ngoài phạm vi"]},
		"rác",
	]}
	var clean: Dictionary = L.sanitize(data, 3)
	check(clean.has(0) and clean[0].size() == 1, "float index ok, empty and too-long lines dropped")
	check(clean.has(1) and not clean.has(9), "out-of-range index dropped")
	check(L.sanitize("nope", 3).is_empty() and L.sanitize({"biomes": 5}, 3).is_empty(), "bad shapes -> empty")

	check(L.cache_key() == "lore_classic_vi" or L.cache_key() == "lore_modern_vi", "cache key has style and lang")
	var p: String = L.build_prompt()
	check(p.contains("Vietnamese") and p.contains("0: ") and p.contains("2: "), "prompt lists every zone by index")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	gemini.transport = fake(JSON.stringify(data))
	calls = 0
	await L.prefetch()
	check(calls == 1 and gemini.cached(L.cache_key()) != null, "prefetch fills the cache")
	await L.prefetch()
	check(calls == 1, "fresh cache -> no second request")
	check(L.line_for(1) == "Tàn tích đỏ rực dưới hoàng hôn.", "line_for returns a cached legend")
	check(L.line_for(2) == "", "zone without legend -> empty")

	loc.lang = "en"
	check(L.line_for(1) == "", "other language -> no stale legend")
	loc.lang = "vi"

	gemini._user_enabled = false
	gemini._refresh_enabled()
	check(L.line_for(1) == "", "AI switched off -> no AI legend")

	var hud: Control = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	hud.show_banner("Đang vào\nX", 0.1, "Truyền thuyết")
	check(hud.get_node("%Lore").text == "Truyền thuyết", "hud shows lore under the banner")
	hud.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://gemini_cache_test.json"))
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
```

- [ ] Step 2: chạy → FAIL.
- [ ] Step 3: tạo `scripts/ai/biome_lore.gd`:

```gdscript
class_name BiomeLore
extends RefCounted
## One-line legends shown under the "Entering <zone>" banner. All zones of the current style
## are written in ONE Gemini call from the menu and cached on disk for a day, keyed by style
## and language — nothing is requested during a run. No cache / AI off → banner as before.

const MAX_LEN := 90
const MAX_AGE_S := 86400.0
const SYSTEM := "You write atmospheric one-sentence legends for the zones of an endless runner game. Every legend is under 90 characters. Plain text only: no markdown, no quotes, no emojis."

static var _pending := false


static func cache_key() -> String:
	return "lore_%s_%s" % ["modern" if Catalog.modern() else "classic", Loc.lang]


static func schema() -> Dictionary:
	return {"type": "OBJECT", "properties": {"biomes": {"type": "ARRAY", "items": {"type": "OBJECT",
		"properties": {"index": {"type": "INTEGER"}, "lines": {"type": "ARRAY", "items": {"type": "STRING"}}},
		"required": ["index", "lines"]}}}, "required": ["biomes"]}


static func build_prompt() -> String:
	var lines := PackedStringArray([
		"Answer in %s." % ("Vietnamese" if Loc.lang == "vi" else "English"),
		"World style: %s." % ("modern neon sci-fi city" if Catalog.modern() else "classic jungle temple"),
		"Write 3 different legends for each zone below and return them with the zone's index.",
	])
	var biomes := Catalog.biomes()
	for i in biomes.size():
		lines.append("%d: %s" % [i, Loc.pick(biomes[i].name)])
	return "\n".join(lines)


## Coroutine; fire and forget from the menu. Refreshes a missing or day-old cache.
static func prefetch() -> void:
	if _pending or not Gemini.enabled or Gemini.cache_age(cache_key()) < MAX_AGE_S:
		return
	_pending = true
	await Gemini.generate_json(build_prompt(), schema(),
		{"system": SYSTEM, "max_tokens": 700, "cache_key": cache_key(), "persist": true, "refresh": true})
	_pending = false


## zone index -> Array of usable legends, from possibly malformed AI output.
static func sanitize(data: Variant, count: int) -> Dictionary:
	var out := {}
	if not (data is Dictionary) or not (data.get("biomes") is Array):
		return out
	for entry: Variant in data.biomes:
		if not (entry is Dictionary) or not (entry.get("lines") is Array):
			continue
		var idx := int(entry.get("index", -1))
		if idx < 0 or idx >= count:
			continue
		var good: Array = []
		for raw: Variant in entry.lines:
			var t := Gemini.clean_text(str(raw))
			if t != "" and t.length() <= MAX_LEN:
				good.append(t)
		if not good.is_empty():
			out[idx] = good
	return out


## A cached legend for zone `index`, or "" (AI off, nothing cached, or none for that zone).
static func line_for(index: int) -> String:
	if not Gemini.enabled:
		return ""
	var lines := sanitize(Gemini.cached(cache_key()), Catalog.biomes().size())
	if not lines.has(index):
		return ""
	var options: Array = lines[index]
	return options[randi() % options.size()]
```

- [ ] Step 4: `hud.tscn` — ngay sau block node `Banner` (trước node kế tiếp), thêm:

```
[node name="Lore" type="Label" parent="."]
unique_name_in_owner = true
layout_mode = 1
anchors_preset = 10
anchor_right = 1.0
offset_left = 48.0
offset_top = 440.0
offset_right = -48.0
offset_bottom = 440.0
grow_horizontal = 2
modulate = Color(1, 1, 1, 0)
theme_type_variation = &"Hud"
theme_override_font_sizes/font_size = 28
theme_override_constants/outline_size = 8
horizontal_alignment = 1
autowrap_mode = 3
```

`hud.gd`: thêm `@onready var _lore: Label = %Lore` sau `_banner`; đổi `show_banner`:

```gdscript
func show_banner(text: String, seconds := 2.5, lore := "") -> void:
	_banner.text = text
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(seconds)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)
	if lore == "":
		return
	# The legend is longer than the zone name, so it lingers a little longer.
	_lore.text = lore
	var lt := _lore.create_tween()
	lt.tween_property(_lore, "modulate:a", 1.0, 0.3)
	lt.tween_interval(seconds + 1.5)
	lt.tween_property(_lore, "modulate:a", 0.0, 0.6)
```

- [ ] Step 5: `main.gd` — trong lambda `biome_changed`: `ui.hud.show_banner(Loc.t("entering") + "\n" + Loc.pick(Catalog.biomes()[i].name), 2.5, BiomeLore.line_for(i))`. `menu_screen.gd` — cuối `build()` thêm `BiomeLore.prefetch()` (không await).
- [ ] Step 6: suite → `ALL TEST FILES PASS (5)`; khởi động game headless 300 frame không lỗi mới. Commit: `feat: truyền thuyết vùng cảnh do AI viết (tải trước ở menu)`.

---

### Task 4: Lời thoại boss động (2D)

**Files:** Create `core/boss_voice.gd` (autoload `BossVoice`), `tests/test_boss_voice.gd`; Modify `core/save_manager.gd`, `project.godot`, `../CLAUDE.md`.

**Consumes:** `Events.boss_intro/boss_phase_changed/player_died/boss_defeated`, `Gemini.enabled/generate_json/clean_text`, `CharacterData.get_display`, `GameManager.selected_character`, `SaveManager.get_unlocked_abilities`.
**Produces:** `SaveManager.get_boss_attempts(id) -> int`, `add_boss_attempt(id) -> int`; autoload `BossVoice` — `say(text)`, `static merge(base, data) -> Dictionary`, `static fallback_lines(boss_id) -> Dictionary`, `build_prompt(boss_id, display_name, attempts) -> String`; test đọc `_label`, `_lines`, `_fight`.

- [ ] Step 1: tạo `tests/test_boss_voice.gd`:

```gdscript
extends SceneTree
## Chạy: tests/run_tests.sh tests/test_boss_voice.gd
## Sao lưu + khôi phục user://save_data.json vì BossVoice ghi số lần đánh boss.

var _fails := 0
var calls := 0
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
	return func(_u: String, _h: PackedStringArray, _b: String, _t: float) -> Dictionary:
		calls += 1
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
```

- [ ] Step 2: chạy → FAIL (`BossVoice` chưa có).
- [ ] Step 3: `save_manager.gd` — thêm biến sau `var last_level`:

```gdscript
## boss_id -> số lần đã vào đánh. BossVoice nhắc lại trong lời khiêu khích.
var boss_attempts: Dictionary = {}
```

Thêm hàm sau `mark_boss_defeated`:

```gdscript
func get_boss_attempts(id: String) -> int:
	return int(boss_attempts.get(id, 0))

func add_boss_attempt(id: String) -> int:
	boss_attempts[id] = get_boss_attempts(id) + 1
	save_data()
	return boss_attempts[id]
```

`save_data()` thêm `"boss_attempts": boss_attempts,`; `load_data()` thêm `boss_attempts = parsed.get("boss_attempts", {})`; `reset_progress()` thêm `boss_attempts = {}`.

- [ ] Step 4: tạo `core/boss_voice.gd`:

```gdscript
extends CanvasLayer
## Autoload `BossVoice`: lời thoại boss do Gemini viết — MỘT request mỗi trận (lúc
## `Events.boss_intro`), hiện ở dòng chữ ngay dưới thanh máu boss. Giữa trận chỉ đọc kết quả
## đã có, không chờ mạng. AI tắt/lỗi/chậm → câu tĩnh trong BOSSES.
##
## Tự dựng Label bằng code (không sửa scene màn boss — các màn là file SINH ra).
## `_fight` tăng mỗi trận: request của trận cũ về muộn bị bỏ.

const MAX_LEN := 70
const SHOW_SECONDS := 3.0
## Chờ câu intro của AI tối đa chừng này rồi dùng câu tĩnh.
const INTRO_WAIT_MS := 1500
const KEYS: Array[String] = ["intro", "phase_2", "player_died", "defeated"]
const SYSTEM := "Chỉ trả JSON đúng schema. Mỗi câu là tiếng Việt, dưới 70 ký tự, không markdown, không emoji, không ngoặc kép."
const SCHEMA := {"type": "OBJECT", "properties": {
	"intro": {"type": "STRING"}, "phase_2": {"type": "STRING"},
	"player_died": {"type": "STRING"}, "defeated": {"type": "STRING"}},
	"required": ["intro", "phase_2", "player_died", "defeated"]}
const BOSSES := {
	"forest_boss": {
		"persona": "Vua Heo — kẻ cướp ngôi, kiêu ngạo, ồn ào, thích ném bom và lao húc.",
		"intro": "Ngai vàng này là của ta! Xéo khỏi lâu đài!",
		"phase_2": "Hết kiên nhẫn rồi — nếm thử cú húc này!",
		"player_died": "Ha! Quay về làng mà khóc đi!",
		"defeated": "Không... Vương Miện... của ta...",
	},
	"dungeon_boss": {
		"persona": "Cai Ngục — hồn ma canh giữ Hầm Ngục Cổ, lạnh lẽo, nói chậm rãi đầy đe doạ, gọi hồn và biến mất rồi hiện sau lưng.",
		"intro": "Kẻ sống không được bước vào hầm ngục này.",
		"phase_2": "Các linh hồn... hãy trỗi dậy!",
		"player_died": "Thêm một linh hồn cho hầm ngục của ta.",
		"defeated": "Cuối cùng... ta được yên nghỉ...",
	},
}
const GENERIC := {
	"persona": "một boss hung dữ",
	"intro": "Ngươi sẽ không qua được đây!",
	"phase_2": "Giờ mới là thật!",
	"player_died": "Yếu ớt!",
	"defeated": "Không thể nào...",
}

var _lines: Dictionary = {}
var _fight := 0
var _boss_id := ""
var _ai_ready := false
var _phase_2_shown := false
var _label: Label
var _tween: Tween


func _ready() -> void:
	layer = 80
	_build_label()
	Events.boss_intro.connect(_on_intro)
	Events.boss_phase_changed.connect(_on_phase)
	Events.player_died.connect(_on_player_died)
	Events.boss_defeated.connect(_on_defeated)


static func fallback_lines(boss_id: String) -> Dictionary:
	var src: Dictionary = BOSSES.get(boss_id, GENERIC)
	var out := {}
	for key in KEYS:
		out[key] = src[key]
	return out


## Lấy từng câu AI hợp lệ (khác rỗng, ≤ MAX_LEN), còn lại giữ câu tĩnh của `base`.
static func merge(base: Dictionary, data: Variant) -> Dictionary:
	var out := base.duplicate()
	if not (data is Dictionary):
		return out
	for key in KEYS:
		var t := Gemini.clean_text(str(data.get(key, "")))
		if t != "" and t.length() <= MAX_LEN:
			out[key] = t
	return out


func build_prompt(boss_id: String, display_name: String, attempts: int) -> String:
	var info: Dictionary = BOSSES.get(boss_id, GENERIC)
	var abilities: Array = SaveManager.get_unlocked_abilities()
	return "\n".join(PackedStringArray([
		"Ngươi là %s, boss trong game platformer 2D Pixel Adventure." % display_name,
		"Tính cách: %s" % info.persona,
		"Người chơi (nhân vật %s) đang vào đấu với ngươi lần thứ %d." % [
			CharacterData.get_display(GameManager.selected_character), attempts],
		"Sức mạnh người chơi đang có: %s." % (", ".join(abilities) if not abilities.is_empty() else "chưa có"),
		"Viết 4 câu thoại đúng giọng nhân vật: intro (trận bắt đầu; nếu đã thua nhiều lần thì chế nhạo điều đó), phase_2 (ngươi nổi giận chuyển giai đoạn), player_died (người chơi vừa chết), defeated (ngươi bị hạ).",
	]))


func say(text: String) -> void:
	if text == "":
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_label.text = text
	_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(SHOW_SECONDS)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.5)


func _on_intro(boss_id: String, display_name: String) -> void:
	_fight += 1
	var fight := _fight
	_boss_id = boss_id
	_phase_2_shown = false
	_ai_ready = false
	_lines = fallback_lines(boss_id)
	var attempts := SaveManager.add_boss_attempt(boss_id)
	if Gemini.enabled:
		_fetch(fight, boss_id, display_name, attempts)
		var end := Time.get_ticks_msec() + INTRO_WAIT_MS
		while not _ai_ready and fight == _fight and Time.get_ticks_msec() < end:
			await get_tree().process_frame
	if fight == _fight:
		say(_lines.intro)


func _fetch(fight: int, boss_id: String, display_name: String, attempts: int) -> void:
	var data: Variant = await Gemini.generate_json(build_prompt(boss_id, display_name, attempts), SCHEMA,
		{"system": SYSTEM, "max_tokens": 300})
	if fight != _fight:
		return
	_lines = merge(fallback_lines(boss_id), data)
	_ai_ready = true


func _on_phase(phase: int) -> void:
	if phase >= 2 and not _phase_2_shown and _boss_present():
		_phase_2_shown = true
		say(_lines.phase_2)


func _on_player_died() -> void:
	if _boss_present():
		say(_lines.player_died)


func _on_defeated(boss_id: String) -> void:
	if boss_id == _boss_id:
		say(_lines.defeated)


## Chỉ nói khi đang trong màn boss: `player_died` cũng phát ở màn thường.
func _boss_present() -> bool:
	return _boss_id != "" and get_tree().get_first_node_in_group("boss") != null


func _build_label() -> void:
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 72.0
	_label.offset_left = 40.0
	_label.offset_right = -40.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	_label.modulate.a = 0.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
```

`project.godot`: sau dòng `AiChat=...` thêm `BossVoice="*res://core/boss_voice.gd"`.

- [ ] Step 5: suite 2D → `ALL TEST FILES PASS (5)`; khởi động game headless không lỗi mới; `CLAUDE.md` thêm gạch đầu dòng `BossVoice` sau `AiChat` và nhắc `boss_attempts` trong dòng `SaveManager`. Commit: `feat: lời thoại boss do AI viết (một request mỗi trận)`.

---

### Task 5: Chạy thật với key + review

- [ ] Chạy thử với Gemini thật: Coach (vi/en), BiomeLore.prefetch rồi `line_for(0..2)`, BossVoice với cả hai boss. In kết quả, kiểm tra độ dài và giọng văn.
- [ ] Ghi kết quả vào ledger; review gộp đợt 2 + 3 ở cuối đợt 3.
