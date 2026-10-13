extends CanvasLayer
## Nút điều khiển cảm ứng cho mobile. Trái/phải là joystick (joystick.gd), các nút còn
## lại là TouchScreenButton có `action` → kích hoạt đúng InputMap action như bàn phím,
## nên player.gd/level_base không cần biết gì.
## level_base instance scene này lúc vào màn; tự ẩn nếu không phải thiết bị cảm ứng
## (hoặc theo SaveManager.get_setting("touch_controls")).

## Pause phát qua signal (an toàn hơn dựa vào InputEventAction tới _unhandled_input).
signal pause_pressed

## Kích thước nút sau khi scale (px), + lề mép màn hình + khoảng cách 2 nút cạnh nhau.
const BTN := 96.0
const MARGIN := 40.0
const GAP := 22.0
## Vùng chạm của joystick: phần trái màn (tỉ lệ bề ngang), bỏ dải trên (HUD tim/điểm).
const STICK_ZONE_W := 0.45
const STICK_ZONE_TOP := 0.3

func _ready() -> void:
	layer = 10
	visible = _should_show()
	get_viewport().size_changed.connect(_layout)
	_layout()
	$BtnDash.visible = SaveManager.is_ability_unlocked("dash")
	# Mở khoá giữa màn (nhặt relic / thắng boss) → hiện nút ngay, không đợi vào lại màn.
	Events.ability_unlocked.connect(_on_ability_unlocked)
	# Đổi "Nút cảm ứng" trong Cài đặt mở từ menu pause → áp ngay giữa màn.
	Events.setting_changed.connect(_on_setting_changed)
	$BtnPause.pressed.connect(func() -> void: pause_pressed.emit())

func _on_ability_unlocked(id: String) -> void:
	if id == "dash":
		$BtnDash.visible = true

func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "touch_controls":
		visible = _should_show(String(value))

func _should_show(mode: String = SaveManager.get_setting("touch_controls", "auto")) -> bool:
	match mode:
		"on":
			return true
		"off":
			return false
		_:
			return DisplayServer.is_touchscreen_available()

## TouchScreenButton là Node2D (không anchor) → tự đặt vị trí theo mép an toàn.
## Trừ safe-area (tai thỏ / bo góc) khỏi vùng bố trí nút.
func _layout() -> void:
	# MobileScale phóng to cả canvas; thu layer lại để nút giữ đúng cỡ trên màn (vốn
	# đã vừa ngón tay), rồi bố trí theo kích thước viewport tính ở tỉ lệ đó.
	var k := MobileScale.factor
	scale = Vector2.ONE / k
	var vp := get_viewport().get_visible_rect().size * k
	var bottom := vp.y - MARGIN - BTN
	var corner_x := vp.x - MARGIN - BTN
	var stick: TouchJoystick = $Joystick
	stick.position = Vector2(MARGIN + stick.radius, vp.y - MARGIN - stick.radius)
	stick.zone = Rect2(0.0, vp.y * STICK_ZONE_TOP, vp.x * STICK_ZONE_W, vp.y * (1.0 - STICK_ZONE_TOP))
	$BtnJump.position = Vector2(corner_x, bottom)
	$BtnAttack.position = Vector2(corner_x - BTN - GAP, bottom)
	$BtnDash.position = Vector2(corner_x, bottom - BTN - GAP)
	$BtnInteract.position = Vector2(corner_x - BTN - GAP, bottom - BTN - GAP)
	$BtnPause.position = Vector2(corner_x, MARGIN)
