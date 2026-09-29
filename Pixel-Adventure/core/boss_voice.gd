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
		{"system": SYSTEM, "max_tokens": 300, "timeout": 15.0})
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
