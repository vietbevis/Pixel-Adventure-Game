## HUD trong lúc chơi: hiển thị số quả đã ăn, thời gian và số tim (máu) còn lại.
## 3 icon tim được dựng sẵn trong hud.tscn (Godot editor) — script chỉ đổi
## texture đầy/rỗng theo GameManager.hearts, không tự tạo node bằng code.
extends CanvasLayer

const HEART_FULL := preload("res://ui/shared/controls/heart_full.png")
const HEART_EMPTY := preload("res://ui/shared/controls/heart_empty.png")

@onready var label: Label = $MarginContainer/VBoxContainer/FruitLabel
@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var hearts_row: HBoxContainer = $MarginContainer/VBoxContainer/HeartsRow

func _process(_delta: float) -> void:
	label.text = "Fruits: %d" % GameManager.score
	time_label.text = "Time: %s" % LevelData.format_time(GameManager.elapsed_time())
	_update_hearts()

## Tô lại từng icon tim: đầy nếu còn trong số máu hiện tại, rỗng nếu đã mất
func _update_hearts() -> void:
	for i in hearts_row.get_child_count():
		var heart: TextureRect = hearts_row.get_child(i)
		heart.texture = HEART_FULL if i < GameManager.hearts else HEART_EMPTY
