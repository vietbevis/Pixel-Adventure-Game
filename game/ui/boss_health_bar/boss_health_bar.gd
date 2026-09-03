extends CanvasLayer
## Thanh máu boss trên đỉnh màn hình. Nghe `Events.boss_health_changed` /
## `Events.boss_defeated`. Ẩn cho tới khi boss báo máu lần đầu.

@onready var _label: Label = $Margin/VBox/Label
@onready var _bar: ProgressBar = $Margin/VBox/Bar

func _ready() -> void:
	visible = false
	Events.boss_intro.connect(_on_intro)
	Events.boss_health_changed.connect(_on_health_changed)
	Events.boss_phase_changed.connect(_on_phase_changed)
	Events.boss_defeated.connect(_on_defeated)

func _on_intro(display_name: String, _max_hp: int) -> void:
	_label.text = display_name.to_upper()

func _on_phase_changed(phase: int) -> void:
	# đỏ dần theo phase (1 = vàng cam, 3 = đỏ)
	var t := clampf((phase - 1) / 2.0, 0.0, 1.0)
	_bar.modulate = Color(1, 1, 1).lerp(Color(1, 0.4, 0.35), t)

func _on_health_changed(current: int, maximum: int) -> void:
	visible = true
	_bar.max_value = maximum
	_bar.value = current

func _on_defeated(_boss_id: String) -> void:
	var tween := create_tween()
	tween.tween_property(_bar, "value", 0.0, 0.4)
	tween.tween_interval(0.4)
	tween.tween_callback(func() -> void: visible = false)
