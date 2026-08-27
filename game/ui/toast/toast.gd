extends CanvasLayer
## Autoload: thông báo ngắn trượt vào giữa-trên màn hình khi mở ability / nhặt đồ...
## Sống xuyên scene (autoload) nên hiện được cả khi vừa đổi sang end_screen.

const DISPLAY := {"dash": "Dash"}

@onready var _panel: Control = $Panel
@onready var _label: Label = $Panel/Margin/Label

var _queue: Array[String] = []
var _busy: bool = false

func _ready() -> void:
	layer = 100
	_panel.modulate.a = 0.0
	Events.ability_unlocked.connect(_on_ability_unlocked)

func _on_ability_unlocked(id: String) -> void:
	_queue.append("%s unlocked!" % String(DISPLAY.get(id, id.capitalize())))
	if not _busy:
		_run_queue()

func _run_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		_label.text = _queue.pop_front()
		var tween := create_tween()
		tween.tween_property(_panel, "modulate:a", 1.0, 0.3)
		tween.tween_interval(2.0)
		tween.tween_property(_panel, "modulate:a", 0.0, 0.5)
		await tween.finished
	_busy = false
