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

func _ready() -> void:
	layer = 10
	visible = _should_show()
	get_viewport().size_changed.connect(_layout)
	_layout()
	$BtnDash.visible = SaveManager.is_ability_unlocked("dash")
	$BtnPause.pressed.connect(func() -> void: pause_pressed.emit())

func _should_show() -> bool:
	match SaveManager.get_setting("touch_controls", "auto"):
		"on":
			return true
		"off":
			return false
		_:
			return DisplayServer.is_touchscreen_available()

## TouchScreenButton là Node2D (không anchor) → tự đặt vị trí theo mép màn hình.
## (Safe-area cho tai thỏ để tinh chỉnh ở Phase Polish — MARGIN đang chừa rộng.)
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var bottom := vp.y - MARGIN - BTN
	var corner_x := vp.x - MARGIN - BTN
	$BtnLeft.position = Vector2(MARGIN, bottom)
	$BtnRight.position = Vector2(MARGIN + BTN + GAP, bottom)
	$BtnJump.position = Vector2(corner_x, bottom)
	$BtnAttack.position = Vector2(corner_x - BTN - GAP, bottom)
	$BtnDash.position = Vector2(corner_x, bottom - BTN - GAP)
	$BtnPause.position = Vector2(corner_x, MARGIN)
