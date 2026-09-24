extends CanvasLayer
## Thanh máu boss trên đỉnh màn hình. Nghe `Events.boss_intro` (đặt tên),
## `Events.boss_health_changed` và `Events.boss_defeated`.
## Ẩn cho tới khi boss báo máu lần đầu.

@onready var _label: Label = $Margin/VBox/Label
@onready var _bar: ProgressBar = $Margin/VBox/Bar

func _ready() -> void:
	visible = false
	Events.boss_intro.connect(_on_intro)
	Events.boss_health_changed.connect(_on_health_changed)
	Events.boss_defeated.connect(_on_defeated)

## Tên boss phải đến từ đây: trước đây nhãn bị hardcode "KING PIG" trong scene nên
## trận Cai Ngục ở màn cuối vẫn hiện tên Vua Heo.
func _on_intro(boss_id: String, display_name: String) -> void:
	_label.text = display_name if display_name != "" else boss_id.to_upper()

func _on_health_changed(current: int, maximum: int) -> void:
	visible = true
	_bar.max_value = maximum
	_bar.value = current

func _on_defeated(_boss_id: String) -> void:
	var tween := create_tween()
	tween.tween_property(_bar, "value", 0.0, 0.4)
	tween.tween_interval(0.4)
	tween.tween_callback(func() -> void: visible = false)
