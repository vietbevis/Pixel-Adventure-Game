extends CanvasLayer
## Nút điều khiển cảm ứng cho mobile. Mỗi nút là TouchScreenButton có `action` → kích
## hoạt đúng InputMap action như bàn phím, nên player.gd/level_base không cần biết gì.
## level_base instance scene này lúc vào màn; tự ẩn nếu không phải thiết bị cảm ứng
## (hoặc theo SaveManager.get_setting("touch_controls")).

## Pause phát qua signal (an toàn hơn dựa vào InputEventAction tới _unhandled_input).
signal pause_pressed

## Kích thước nút sau khi scale (px), + lề mép màn hình + khoảng cách 2 nút cạnh nhau.
const BTN := 96.0
const MARGIN := 40.0
const GAP := 22.0

var _enabled: bool = false

func _ready() -> void:
	layer = 10
	_enabled = _should_show()
	visible = _enabled
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh_dash_button()
	$BtnPause.pressed.connect(func() -> void: pause_pressed.emit())
	# Nút Dash hiện ngay khi nhặt relic giữa màn, không đợi load lại.
	Events.ability_unlocked.connect(func(_id: String) -> void: _refresh_dash_button())
	# Ẩn khi đang thoại / tạm dừng để không che và không bấm nhầm.
	set_process(_enabled)

func _process(_delta: float) -> void:
	visible = not Dialogue.is_open and not get_tree().paused

func _refresh_dash_button() -> void:
	$BtnDash.visible = SaveManager.is_ability_unlocked("dash")

func _should_show() -> bool:
	match SaveManager.get_setting("touch_controls", "auto"):
		"on":
			return true
		"off":
			return false
		_:
			return DisplayServer.is_touchscreen_available()

## TouchScreenButton là Node2D (không anchor) → tự đặt vị trí theo mép an toàn.
## Trừ safe-area (tai thỏ / bo góc) khỏi vùng bố trí nút.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var full := DisplayServer.screen_get_size()
	var pad_l := MARGIN + (maxf(safe.position.x, 0.0) / maxf(full.x, 1.0)) * vp.x
	var pad_r := MARGIN + (maxf(full.x - safe.end.x, 0.0) / maxf(full.x, 1.0)) * vp.x
	var pad_b := MARGIN + (maxf(full.y - safe.end.y, 0.0) / maxf(full.y, 1.0)) * vp.y
	var pad_t := MARGIN + (maxf(safe.position.y, 0.0) / maxf(full.y, 1.0)) * vp.y
	var bottom := vp.y - pad_b - BTN
	var corner_x := vp.x - pad_r - BTN
	$BtnLeft.position = Vector2(pad_l, bottom)
	$BtnRight.position = Vector2(pad_l + BTN + GAP, bottom)
	$BtnJump.position = Vector2(corner_x, bottom)
	$BtnAttack.position = Vector2(corner_x - BTN - GAP, bottom)
	$BtnDash.position = Vector2(corner_x, bottom - BTN - GAP)
	$BtnInteract.position = Vector2(corner_x - BTN - GAP, bottom - BTN - GAP)
	$BtnPause.position = Vector2(corner_x, pad_t)
