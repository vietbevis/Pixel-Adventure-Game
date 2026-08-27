## HUD trong lúc chơi: số quả đã ăn, thời gian, số tim.
## Tim đọc từ `Events.player_health_changed` (player là nguồn). 3 icon tim dựng sẵn
## trong hud.tscn (HeartsRow) — script chỉ đổi texture đầy/rỗng.
extends CanvasLayer

const HEART_FULL := preload("res://ui/shared/controls/heart_full.png")
const HEART_EMPTY := preload("res://ui/shared/controls/heart_empty.png")

@onready var label: Label = $MarginContainer/VBoxContainer/FruitLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var hearts_row: HBoxContainer = $MarginContainer/VBoxContainer/HeartsRow

var _hearts: int = 3

func _ready() -> void:
	Events.player_health_changed.connect(_on_health_changed)
	_update_hearts()

func _on_health_changed(current: int, _maximum: int) -> void:
	_hearts = current
	_update_hearts()

func _process(_delta: float) -> void:
	label.text = "Fruits: %d" % GameManager.score
	time_label.text = "Time: %s" % LevelData.format_time(GameManager.elapsed_time())

func _update_hearts() -> void:
	for i in hearts_row.get_child_count():
		var heart: TextureRect = hearts_row.get_child(i)
		heart.texture = HEART_FULL if i < _hearts else HEART_EMPTY
