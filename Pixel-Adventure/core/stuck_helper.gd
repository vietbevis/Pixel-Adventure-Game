extends Node
## Autoload `StuckHelper`: người chơi chết nhiều lần ở một màn → Cố vấn đưa gợi ý.
## Lần chết thứ 2 gọi Gemini lấy trước gợi ý (chạy nền); lần 3, 6, 9… hiện qua `Dialogue`:
## có checkpoint thì ngay sau khi hồi sinh, không có thì khi màn tải lại (LevelBase gọi
## `level_ready()`), để gợi ý không hiện đè lên màn Game Over. AI tắt/lỗi → ghi chú tay.

const HINT_EVERY := 3
const SPEAKER := "Cố vấn"
const SYSTEM := "Ngươi là Cố vấn già của nhà vua trong game platformer 2D Pixel Adventure. Đưa MỘT mẹo cụ thể để vượt màn, tối đa 2 câu ngắn, tiếng Việt, xưng ta gọi ngài. Chỉ dựa vào đặc điểm màn và sức mạnh được cho; không bịa ra cơ chế, vật phẩm hay đòn đánh không có (người chơi chỉ chạy, nhảy, bám tường, đánh thường, đạp đầu quái và lướt nếu đã có). Không markdown, không emoji."

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
		"Checkpoint: %s." % ("đã chạm, chết sẽ hồi sinh tại đó" if GameManager.has_checkpoint else "chưa có, chết là chơi lại từ đầu màn"),
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
	if level == _level and hint != "":
		_hint = hint  # a failed re-prefetch keeps the earlier good hint


func _show_after(seconds: float) -> void:
	var level := _level
	await get_tree().create_timer(seconds).timeout
	if level != _level or not _pending:
		return
	# AI hint only while AI is still on (the player may have switched it off since).
	var text := _hint if Gemini.enabled and _hint != "" else LevelNotes.tip(level)
	if text != "" and Dialogue.open(PackedStringArray([text]), SPEAKER):
		_pending = false


func _reset(level: String) -> void:
	_level = level
	_deaths = 0
	_hint = ""
	_pending = false
