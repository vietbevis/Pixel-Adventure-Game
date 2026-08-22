## HUD trong lúc chơi: hiển thị số quả đã ăn và số tim (máu) còn lại của player.
extends CanvasLayer

const HEART_FULL := preload("res://assets/ui/controls/heart_full.png")
const HEART_EMPTY := preload("res://assets/ui/controls/heart_empty.png")
## Kích thước hiển thị mỗi icon tim trên màn hình (icon gốc chỉ 18x18px)
const HEART_ICON_SIZE := Vector2(22, 22)

@onready var label: Label = $MarginContainer/VBoxContainer/FruitLabel
@onready var hearts_row: HBoxContainer = $MarginContainer/VBoxContainer/HeartsRow

func _ready() -> void:
	# Tạo sẵn đúng số ô tim theo GameManager.MAX_HEARTS (3 hoặc 5 đều tự chạy đúng)
	for i in GameManager.MAX_HEARTS:
		var heart := TextureRect.new()
		heart.custom_minimum_size = HEART_ICON_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture = HEART_FULL
		hearts_row.add_child(heart)

func _process(_delta: float) -> void:
	label.text = "Fruits: %d" % GameManager.score
	_update_hearts()

## Tô lại từng icon tim: đầy nếu còn trong số máu hiện tại, rỗng nếu đã mất
func _update_hearts() -> void:
	for i in hearts_row.get_child_count():
		var heart: TextureRect = hearts_row.get_child(i)
		heart.texture = HEART_FULL if i < GameManager.hearts else HEART_EMPTY
