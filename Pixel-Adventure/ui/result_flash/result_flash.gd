extends CanvasLayer
## Hiệu ứng báo kết quả NGAY TRÊN MÀN CHƠI, trước khi chuyển sang `end_screen`.
## Phủ một lớp màu toàn màn + dòng chữ lớn, tự huỷ khi tween xong.
##
## Dùng: instance scene này vào `get_tree().current_scene` rồi gọi `show_result(kind)`.
## `player.gd` là nơi duy nhất gọi — xem PLAN.md mục 4 giải thích vì sao không nghe
## `Events.player_died` (signal đó phát cả khi hồi sinh tại checkpoint).

## Cấu hình từng kiểu kết quả: chữ, màu chữ, màu lớp phủ, thời gian giữ.
const PRESETS := {
	"lose": {
		"text": "GỤC NGÃ",
		"color": Color(0.95, 0.35, 0.32),
		"veil": Color(0.32, 0.03, 0.05, 0.55),
		"hold": 0.55,
	},
	"win": {
		"text": "HOÀN THÀNH!",
		"color": Color(1.0, 0.86, 0.36),
		"veil": Color(1.0, 0.95, 0.75, 0.30),
		"hold": 0.45,
	},
	"final": {
		"text": "VƯƠNG MIỆN TRỞ VỀ",
		"color": Color(1.0, 0.88, 0.42),
		"veil": Color(1.0, 0.94, 0.7, 0.42),
		"hold": 1.1,
	},
}

@onready var _veil: ColorRect = $Veil
@onready var _label: Label = $Label

func _ready() -> void:
	# Chạy kể cả khi cây scene đang pause (vd. chết ngay lúc mở menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil.color.a = 0.0
	_label.modulate.a = 0.0

func show_result(kind: String) -> void:
	var preset: Dictionary = PRESETS.get(kind, PRESETS["lose"])
	_label.text = preset["text"]
	_label.add_theme_color_override("font_color", preset["color"])

	var veil_target: Color = preset["veil"]
	var hold: float = preset["hold"]

	# Chờ 1 frame để Control có `size` thật, nếu không pivot = 0 và chữ phóng ra từ góc.
	await get_tree().process_frame
	# Chữ bật ra từ to → về kích thước thật (TRANS_BACK), pivot giữa màn.
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2(1.6, 1.6)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_veil, "color", veil_target, 0.18)
	tween.tween_property(_label, "modulate:a", 1.0, 0.18)
	tween.tween_property(_label, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var out := create_tween()
	out.tween_interval(0.32 + hold)
	# Chỉ ghép song song hai bước mờ dần với nhau. `set_parallel(true)` ở đây từng làm
	# bước mờ dần chạy song song với cả khoảng chờ → chữ tắt ngay sau ~0.3s.
	out.tween_property(_label, "modulate:a", 0.0, 0.3)
	out.parallel().tween_property(_veil, "color:a", 0.0, 0.3)
	out.tween_callback(queue_free)
