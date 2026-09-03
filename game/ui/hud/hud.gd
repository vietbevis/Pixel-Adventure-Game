## HUD trong lúc chơi: số trái cây, thời gian, số tim, số Ngọc bí mật (chỉ hiện ở world có ngọc).
## Tim đọc từ `Events.player_health_changed` (player là nguồn) — số icon tim dựng LẠI theo
## `maximum` để hỗ trợ heart container, không cố định 3.
extends CanvasLayer

const SafeArea := preload("res://core/safe_area.gd")
const HEART_FULL := preload("res://ui/shared/controls/heart_full.png")
const HEART_EMPTY := preload("res://ui/shared/controls/heart_empty.png")
const HEART_SIZE := Vector2(30, 30)

@onready var _margin: MarginContainer = $MarginContainer
@onready var label: Label = $MarginContainer/VBoxContainer/FruitLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var hearts_row: HBoxContainer = $MarginContainer/VBoxContainer/HeartsRow
@onready var secret_label: Label = $MarginContainer/VBoxContainer/SecretLabel

var _hearts: int = 3
var _max_hearts: int = 3

func _ready() -> void:
	Events.player_health_changed.connect(_on_health_changed)
	Events.collectible_collected.connect(_on_collectible_collected)
	Events.fruit_collected.connect(_on_fruit_collected)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_update_secret_label()
	_rebuild_hearts()
	_on_fruit_collected(GameManager.score)

## Chừa lề theo vùng an toàn (tai thỏ / thanh cử chỉ) như touch_controls.
func _apply_safe_area() -> void:
	var vp := get_viewport().get_visible_rect().size
	var safe: Dictionary = SafeArea.insets(vp)
	_margin.add_theme_constant_override("margin_left", int(14.0 + float(safe["left"])))
	_margin.add_theme_constant_override("margin_top", int(12.0 + float(safe["top"])))

func _on_fruit_collected(total: int) -> void:
	label.text = "Trái cây: %d" % total

func _on_collectible_collected(_id: String, kind: String) -> void:
	if kind == "diamond":
		_update_secret_label()

func _process(_delta: float) -> void:
	time_label.text = "Giờ: %s" % LevelData.format_time(GameManager.elapsed_time())

func _on_health_changed(current: int, maximum: int) -> void:
	_hearts = current
	if maximum != _max_hearts:
		_max_hearts = maximum
		_rebuild_hearts()
	else:
		_refresh_hearts()

func _rebuild_hearts() -> void:
	while hearts_row.get_child_count() < _max_hearts:
		var heart := TextureRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hearts_row.add_child(heart)
	while hearts_row.get_child_count() > _max_hearts:
		var extra := hearts_row.get_child(hearts_row.get_child_count() - 1)
		hearts_row.remove_child(extra)  # remove ngay để get_child_count() giảm tức thì
		extra.queue_free()
	_refresh_hearts()

func _refresh_hearts() -> void:
	for i in hearts_row.get_child_count():
		var heart: TextureRect = hearts_row.get_child(i)
		heart.texture = HEART_FULL if i < _hearts else HEART_EMPTY

## Chỉ hiện bộ đếm Ngọc khi world hiện tại có ngọc bí mật (hiện chỉ Rừng).
func _update_secret_label() -> void:
	var world := WorldData.world_of(GameManager.current_level_id)
	if world != "forest":
		secret_label.visible = false
		return
	secret_label.visible = true
	var total := GameIds.FOREST_SECRETS.size()
	var got := 0
	for id: String in GameIds.FOREST_SECRETS:
		if SaveManager.is_secret_collected(id):
			got += 1
	secret_label.text = "Ngọc %d/%d" % [got, total]
