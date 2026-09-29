# Gemini AI — Đợt 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Nhiệm vụ do AI tạo (Temple Run Pro Max) và Gợi ý khi kẹt (Pixel Adventure) — AI chỉ đề xuất, game kiểm tra lại; mất AI thì hành vi y như cũ.

**Architecture:** 3D: lớp tĩnh `MissionDesigner` (prefetch ở menu → hàng đợi `Profile.data.ai_missions`, kiểm tra + kẹp giá trị), `Profile._new_mission` lấy từ hàng đợi trước. 2D: `LevelNotes` (ghi chú tay mỗi màn) + autoload `StuckHelper` (đếm chết theo màn, prefetch gợi ý ở lần chết 2, hiện qua `Dialogue` ở lần 3/6/9…), `LevelBase._ready` báo màn đã tải.

**Tech Stack:** Godot 4.7.2 GDScript, Gemini `gemini-3.5-flash-lite`, `tests/run_tests.sh`.

**Spec:** `docs/superpowers/specs/2026-09-29-gemini-ai-integration-design.md` §5.4, §6.3

## Global Constraints

- Làm thẳng trên `main`, commit mỗi task; commit kết thúc bằng `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Test không ghi đè dữ liệu thật: 3D đặt `Profile.SAVE_PATH = "user://profile_test.json"` rồi xoá; 2D không ghi save.
- Số nguyên từ JSON Gemini là float → `int()`. Chờ theo ms thật bằng vòng `Time.get_ticks_msec()`.
- Request chạy nền dùng `timeout` ≥ 15s (độ trễ API đo được 1–8s).

## Review Focus

1. AI trả target ngoài phạm vi / không phải số / template bịa → nhiệm vụ vẫn hợp lệ, kẹp trong mốc template (test `validate`).
2. Save cũ không có `ai_missions` → không crash (test `_new_mission` với data thiếu khoá).
3. Chữ nhiệm vụ AI nói một con số khác target thật → bỏ chữ AI, dùng tên template (test).
4. Chết lần 3 ở màn không checkpoint → gợi ý hiện khi màn tải lại, không hiện ở màn Game Over (test `level_ready`).
5. Gợi ý của màn trước về muộn sau khi đã sang màn khác → bị bỏ (test).

---

### Task 1: Nhiệm vụ do AI tạo (3D)

**Files:** Create `scripts/ai/mission_designer.gd`, `tests/test_mission_designer.gd`; Modify `scripts/autoload/profile.gd`, `scripts/ui/screens/menu_screen.gd`.

**Produces:** `class_name MissionDesigner` — `QUEUE_TARGET := 3`, `QUEUE_MAX := 6`, `nice(n: int) -> int`, `validate(entry: Variant) -> Dictionary` (`{}` nếu bỏ), `build_prompt() -> String`, `schema() -> Dictionary`, `prefetch() -> void` (coroutine); `Profile._take_ai_mission(used: Array) -> Dictionary`; nhiệm vụ có thể có khoá `"text": [en, vi]`.

- [ ] Step 1: tạo `tests/test_mission_designer.gd`:

```gdscript
extends SceneTree
## Chạy: tests/run_tests.sh tests/test_mission_designer.gd

var _fails := 0
var calls := 0
var last_timeout := 0.0
var M: GDScript


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
	return func(_u: String, _h: PackedStringArray, _b: String, t: float) -> Dictionary:
		calls += 1
		last_timeout = t
		return {"ok": true, "code": 200, "body": ok_body(text)}


func _run() -> void:
	M = load("res://scripts/ai/mission_designer.gd")
	var gemini: Node = root.get_node("Gemini")
	var profile: Node = root.get_node("Profile")
	var loc: Node = root.get_node("Loc")
	profile.SAVE_PATH = "user://profile_test.json"
	loc.lang = "vi"

	check(M.nice(12) == 12 and M.nice(37) == 35 and M.nice(1234) == 1230 and M.nice(23456) == 23450, "nice rounding by magnitude")

	var ok: Dictionary = M.validate({"template_id": "run_dist", "target": 1234.0, "text_en": "Sprint 1230 m in one run", "text_vi": "Chạy 1230 m trong một lượt"})
	check(ok.id == "run_dist" and ok.target == 1230 and ok.text == ["Sprint 1230 m in one run", "Chạy 1230 m trong một lượt"], "valid AI mission kept, target rounded")
	var high: Dictionary = M.validate({"template_id": "run_dist", "target": 999999, "text_en": "x", "text_vi": "y"})
	check(high.target == 4000 and not high.has("text"), "target clamped to template max; mismatched text dropped")
	var low: Dictionary = M.validate({"template_id": "tot_gems", "target": -5, "text_en": "", "text_vi": ""})
	check(low.target == 1, "target clamped to template min")
	check(M.validate({"template_id": "fly_to_moon", "target": 10}).is_empty(), "unknown template -> dropped")
	check(M.validate({"template_id": "run_coins", "target": "nhiều"}).is_empty(), "non-numeric target -> dropped")
	check(M.validate("rác").is_empty(), "non-dict -> dropped")
	var long_text: Dictionary = M.validate({"template_id": "run_coins", "target": 200, "text_en": "Collect 200 coins " + "a".repeat(80), "text_vi": "Nhặt 200 xu"})
	check(not long_text.has("text"), "text over 60 chars dropped")

	var p: String = M.build_prompt()
	check(p.contains("run_dist") and p.contains("tot_gems") and p.contains("4000"), "prompt lists templates with target range")

	# _new_mission lấy từ hàng đợi AI trước, bỏ template đang dùng.
	profile.data.ai_missions = [
		{"id": "run_dist", "target": 1230, "text": ["Sprint 1230 m", "Chạy 1230 m"]},
		{"id": "run_coins", "target": 150},
	]
	var m: Dictionary = profile._new_mission([{"id": "run_dist"}])
	check(m.id == "run_coins" and m.target == 150 and not m.has("text"), "queue skips templates already active")
	check(profile.data.ai_missions.size() == 1, "taken mission removed from queue")
	var m2: Dictionary = profile._new_mission([])
	check(m2.id == "run_dist" and profile.mission_text(m2) == "Chạy 1230 m", "mission_text uses AI text")
	var m3: Dictionary = profile._new_mission([])
	check(m3.has("id") and not m3.has("text"), "empty queue -> random template as before")
	profile.data.erase("ai_missions")
	check(not profile._new_mission([]).is_empty(), "old save without ai_missions still works")

	gemini.configure("")
	calls = 0
	profile.data.ai_missions = []
	await M.prefetch()
	check(calls == 0 and profile.data.ai_missions.is_empty(), "AI off -> no request")

	gemini.configure("k")
	gemini._user_enabled = true
	gemini._refresh_enabled()
	gemini.transport = fake(JSON.stringify({"missions": [
		{"template_id": "run_turns", "target": 42, "text_en": "Turn 40 times in one run", "text_vi": "Rẽ 40 lần trong một lượt"},
		{"template_id": "bogus", "target": 1, "text_en": "", "text_vi": ""},
		{"template_id": "tot_slides", "target": 90.0, "text_en": "Slide 90 times", "text_vi": "Trượt 90 lần"},
	]}))
	await M.prefetch()
	check(calls == 1 and last_timeout >= 15.0, "prefetch sends one background request")
	check(profile.data.ai_missions.size() == 2, "only valid AI missions queued")
	check(profile.data.ai_missions[0].target == 40 and profile.data.ai_missions[0].has("text"), "rounded target kept its matching text")
	check(FileAccess.file_exists("user://profile_test.json"), "queue saved with profile")
	profile.data.ai_missions = [{}, {}, {}]
	calls = 0
	await M.prefetch()
	check(calls == 0, "queue already full -> no request")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile_test.json"))
	if _fails == 0:
		print("ALL PASS")
	else:
		printerr("%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
```

Lưu ý test "rounded target kept its matching text": AI gửi target 42 + chữ "40" → `nice(42)` = 40 → chữ chứa "40" nên giữ.

- [ ] Step 2: chạy → FAIL.
- [ ] Step 3: tạo `scripts/ai/mission_designer.gd`:

```gdscript
class_name MissionDesigner
extends RefCounted
## AI-designed missions. From the menu, Gemini proposes missions tuned to the player's
## records; every proposal is checked against Catalog.MISSIONS (template must exist,
## target clamped to the template's range and rounded, text must name the final target)
## and queued in Profile.data.ai_missions. Profile._new_mission() takes from the queue
## first and falls back to its random pick — the AI never decides rules.

const QUEUE_TARGET := 3
const QUEUE_MAX := 6
const MAX_TEXT := 60
const SYSTEM := "You design short missions for the endless runner game Temple Run Pro Max. Only use the given template ids, keep each target inside its range, make them a fair stretch for this player, and write each mission as a short imperative sentence in English and in Vietnamese that includes the exact target number. No markdown, no emojis."

static var _pending := false


static func schema() -> Dictionary:
	return {"type": "OBJECT", "properties": {"missions": {"type": "ARRAY", "items": {"type": "OBJECT",
		"properties": {"template_id": {"type": "STRING"}, "target": {"type": "INTEGER"},
			"text_en": {"type": "STRING"}, "text_vi": {"type": "STRING"}},
		"required": ["template_id", "target", "text_en", "text_vi"]}}}, "required": ["missions"]}


## Round to a "nice" number for its size: exact < 20, then multiples of 5 / 10 / 50 / 500.
static func nice(n: int) -> int:
	var step := 1
	if n >= 20000:
		step = 500
	elif n >= 2000:
		step = 50
	elif n >= 200:
		step = 10
	elif n >= 20:
		step = 5
	return int(n / step) * step


static func _template(id: String) -> Dictionary:
	for t: Dictionary in Catalog.MISSIONS:
		if t.id == id:
			return t
	return {}


## A queue entry {id, target, text?} from one raw AI mission, or {} if unusable.
static func validate(entry: Variant) -> Dictionary:
	if not (entry is Dictionary):
		return {}
	var tpl := _template(str(entry.get("template_id", "")))
	var raw: Variant = entry.get("target")
	if tpl.is_empty() or not (raw is int or raw is float):
		return {}
	var targets: Array = tpl.targets
	var target := clampi(nice(int(raw)), int(targets[0]), int(targets[-1]))
	var out := {"id": tpl.id, "target": target}
	var en := Gemini.clean_text(str(entry.get("text_en", "")))
	var vi := Gemini.clean_text(str(entry.get("text_vi", "")))
	var number := str(target)
	if en.length() <= MAX_TEXT and vi.length() <= MAX_TEXT and en.contains(number) and vi.contains(number):
		out["text"] = [en, vi]
	return out


static func build_prompt() -> String:
	var runs := maxf(Profile.stat("runs"), 1.0)
	var lines := PackedStringArray([
		"Player: mission level %d, %d runs, best distance %d m, best score %d, most coins in a run %d, average %d m per run." % [
			Profile.multiplier(), int(Profile.stat("runs")), int(Profile.stat("best_distance")),
			int(Profile.stat("best_score")), int(Profile.stat("best_coins_run")), int(Profile.stat("total_distance") / runs)],
		"Propose %d missions, each with a different template. Templates (id, kind, description, allowed target range):" % QUEUE_TARGET,
	])
	for t: Dictionary in Catalog.MISSIONS:
		lines.append("- %s (%s): %s, target %d..%d" % [t.id, t.kind, String(t.name[0]).replace("%d", "N"), int(t.targets[0]), int(t.targets[-1])])
	lines.append("kind run = reached within one run; kind total = accumulated over several runs.")
	return "\n".join(lines)


## Coroutine; fire and forget from the menu. Tops the queue up when it runs low.
static func prefetch() -> void:
	var queue: Array = Profile.data.get("ai_missions", [])
	if _pending or not Gemini.enabled or queue.size() >= QUEUE_TARGET:
		return
	_pending = true
	var data: Variant = await Gemini.generate_json(build_prompt(), schema(),
		{"system": SYSTEM, "max_tokens": 500, "timeout": 20.0})
	_pending = false
	if not (data is Dictionary) or not (data.get("missions") is Array):
		return
	queue = Profile.data.get("ai_missions", [])
	for entry: Variant in data.missions:
		var m := validate(entry)
		if not m.is_empty() and queue.size() < QUEUE_MAX:
			queue.append(m)
	Profile.data["ai_missions"] = queue
	Profile.save()
```

- [ ] Step 4: `profile.gd`:
  - `_defaults()`: sau `"missions": {...},` thêm `"ai_missions": [],   # AI-proposed missions waiting to be assigned (MissionDesigner)`.
  - `_new_mission`: ngay sau vòng lặp tạo `used`, thêm:

```gdscript
	var ai := _take_ai_mission(used)
	if not ai.is_empty():
		return ai
```

  - thêm hàm sau `_new_mission`:

```gdscript
## First queued AI mission whose template is not already active (removed from the queue).
func _take_ai_mission(used: Array) -> Dictionary:
	var queue: Array = data.get("ai_missions", [])
	for i in queue.size():
		var q: Dictionary = queue[i]
		if q.get("id", "") in used or mission_template(q.get("id", "")).is_empty():
			continue
		queue.remove_at(i)
		var m := {"id": q.id, "target": int(q.target), "progress": 0, "done": false}
		if q.has("text"):
			m["text"] = q.text
		return m
	return {}
```

  - `mission_text`:

```gdscript
func mission_text(m: Dictionary) -> String:
	if m.get("text") is Array and m.text.size() == 2:
		return Loc.pick(m.text)
	return Loc.pick(mission_template(m.id).name) % m.target
```

- [ ] Step 5: `menu_screen.gd` — sau `BiomeLore.prefetch()` thêm `MissionDesigner.prefetch()`.
- [ ] Step 6: suite → `ALL TEST FILES PASS (6)`; boot 400 frame không lỗi mới. Commit `feat: nhiệm vụ do AI đề xuất (kiểm tra theo template)`.

---

### Task 2: Gợi ý khi kẹt (2D)

**Files:** Create `core/level_notes.gd` (`class_name LevelNotes`), `core/stuck_helper.gd` (autoload `StuckHelper`), `tests/test_stuck_helper.gd`; Modify `levels/level_base.gd`, `project.godot`, `../CLAUDE.md`.

**Produces:** `LevelNotes.NOTES: Dictionary`, `LevelNotes.tip(level_id) -> String`; autoload `StuckHelper` — `level_ready() -> void`, `build_prompt(level_id, deaths) -> String`; test đọc `_deaths`, `_hint`, `_pending`, `_level`.

- [ ] Step 1: tạo `tests/test_stuck_helper.gd`:

```gdscript
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
```

- [ ] Step 2: chạy → FAIL.
- [ ] Step 3: tạo `core/level_notes.gd`:

```gdscript
class_name LevelNotes
extends RefCounted
## Ghi chú tay về chướng ngại / quái của từng màn. StuckHelper gửi cho Gemini làm ngữ cảnh,
## và hiện thẳng làm gợi ý khi AI tắt/lỗi. Thêm màn mới trong LevelData → thêm ghi chú ở đây.

const NOTES := {
	"level_1": "Bìa rừng: gai, cưa, thú nhỏ. Nhảy đôi để qua hố rộng, đạp lên đầu quái để hạ chúng.",
	"level_2": "Leo dọc: bám tường rồi nhảy tường, dùng quạt gió đẩy lên, ván gỗ sẽ rơi nếu đứng lâu. Cuối màn nhặt di vật Lướt rồi lướt qua tường vỡ.",
	"level_3": "Tường thành: qua hào bằng bè, lướt để phá cổng, khối đá nghiền rơi khi đứng ngay dưới — chờ nó nâng lên rồi chạy qua.",
	"level_4": "Hành lang ngai: sóng lửa đuổi theo, bệ di chuyển trên hố gai, phòng đại bác, quả cầu gai lắc — canh nhịp rồi mới nhảy.",
	"boss_forest": "Vua Heo: chỉ vụ nổ của bom gây sát thương; từ giai đoạn 2 hắn lao húc (nhảy lên né, hắn choáng khi đâm tường — lúc đó đánh); giai đoạn 3 nhảy dập tạo sóng xung kích sát đất.",
	"level_5": "Lối xuống hầm: gai rơi từ trần, bộ xương trỗi dậy khi lại gần, hồn ma bay xuyên tường — lúc hồn ma mờ đi thì không đánh được.",
	"level_6": "Hầm vàng: chó săn lao tới khi đứng ngang hàng, cưa chạy trên ray, kim tự tháp lửa, bệ sụp trên vực — đừng đứng lâu trên bệ nứt.",
	"boss_dungeon": "Cai Ngục (bay): lao chéo xuống rồi lơ lửng thấp — đó là lúc đánh; gọi 2 bộ xương; giai đoạn 2 mưa cầu linh hồn có cảnh báo trên sàn; giai đoạn 3 biến mất rồi hiện sau lưng chém.",
}


static func tip(level_id: String) -> String:
	return String(NOTES.get(level_id, ""))
```

- [ ] Step 4: tạo `core/stuck_helper.gd`:

```gdscript
extends Node
## Autoload `StuckHelper`: người chơi chết nhiều lần ở một màn → Cố vấn đưa gợi ý.
## Lần chết thứ 2 gọi Gemini lấy trước gợi ý (chạy nền); lần 3, 6, 9… hiện qua `Dialogue`:
## có checkpoint thì ngay sau khi hồi sinh, không có thì khi màn tải lại (LevelBase gọi
## `level_ready()`), để gợi ý không hiện đè lên màn Game Over. AI tắt/lỗi → ghi chú tay.

const HINT_EVERY := 3
const SPEAKER := "Cố vấn"
const SYSTEM := "Ngươi là Cố vấn già của nhà vua trong game platformer 2D Pixel Adventure. Đưa MỘT mẹo cụ thể để vượt màn, tối đa 2 câu ngắn, tiếng Việt, xưng ta gọi ngài. Không markdown, không emoji."

var _level := ""
var _deaths := 0
var _hint := ""
var _pending := false


func _ready() -> void:
	Events.player_died.connect(_on_player_died)
	Events.level_completed.connect(func(level_id: String) -> void:
		if level_id == _level:
			_reset(""))


## LevelBase._ready gọi mỗi khi một màn được tải (kể cả tải lại sau Game Over).
func level_ready() -> void:
	var level := GameManager.current_level_id
	if level != _level:
		_reset(level)
	elif _pending:
		_show_after(1.2)


func build_prompt(level_id: String, deaths: int) -> String:
	var abilities: Array = SaveManager.get_unlocked_abilities()
	var idx := LevelData.get_index(level_id)
	var level_name: String = LevelData.LEVELS[idx]["name"] if idx != -1 else level_id
	return "\n".join(PackedStringArray([
		"Màn: %s." % level_name,
		"Đặc điểm màn: %s" % LevelNotes.tip(level_id),
		"Người chơi (nhân vật %s) đã chết %d lần ở màn này." % [CharacterData.get_display(GameManager.selected_character), deaths],
		"Sức mạnh đang có: %s." % (", ".join(abilities) if not abilities.is_empty() else "chưa có"),
		"Hãy đưa một mẹo giúp họ vượt qua.",
	]))


func _on_player_died() -> void:
	var level := GameManager.current_level_id
	if LevelData.get_index(level) == -1:
		return  # hub, menu...
	if level != _level:
		_reset(level)
	_deaths += 1
	if _deaths % HINT_EVERY == HINT_EVERY - 1:
		_prefetch(level, _deaths)
	elif _deaths % HINT_EVERY == 0:
		_pending = true
		if GameManager.has_checkpoint:
			_show_after(0.8)


func _prefetch(level: String, deaths: int) -> void:
	if not Gemini.enabled:
		return
	var hint: String = await Gemini.generate_text(build_prompt(level, deaths),
		{"system": SYSTEM, "max_tokens": 120, "timeout": 15.0})
	if level == _level:
		_hint = hint


func _show_after(seconds: float) -> void:
	var level := _level
	await get_tree().create_timer(seconds).timeout
	if level != _level or not _pending:
		return
	var text := _hint if _hint != "" else LevelNotes.tip(level)
	if text != "" and Dialogue.open(PackedStringArray([text]), SPEAKER):
		_pending = false


func _reset(level: String) -> void:
	_level = level
	_deaths = 0
	_hint = ""
	_pending = false
```

- [ ] Step 5: `project.godot` — sau dòng `BossVoice=...` thêm `StuckHelper="*res://core/stuck_helper.gd"`. `levels/level_base.gd` — cuối `_ready()` thêm:

```gdscript

	StuckHelper.level_ready()
```

- [ ] Step 6: suite → `ALL TEST FILES PASS (6)`; boot không lỗi mới; `CLAUDE.md` thêm dòng `StuckHelper` + `LevelNotes`. Commit `feat: Cố vấn gợi ý khi chết nhiều lần ở một màn`.

---

### Task 3: Chạy thật + review gộp đợt 2–3

- [ ] Chạy thật: MissionDesigner.prefetch (in hàng đợi đã kiểm tra), StuckHelper.build_prompt → generate_text cho 2 màn.
- [ ] Review toàn bộ thay đổi đợt 2+3 (cả hai repo) bằng một reviewer mới; sửa Critical/Important bằng TDD.
