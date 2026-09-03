extends RefCounted
## Lề vùng an toàn (tai thỏ / thanh cử chỉ) quy về toạ độ CANVAS (viewport).
##
## `DisplayServer.get_display_safe_area()` trả toạ độ MÀN HÌNH VẬT LÝ, không phải
## lề. Trên desktop cửa sổ nằm lệch giữa màn hình nên `safe.position` là hàng trăm
## px — lấy thẳng làm lề thì HUD/nút bị đẩy vào giữa màn hình (bug cũ). Ở đây quy
## safe-rect về lề tương đối với cửa sổ, scale sang px canvas, và chặn trần 12%
## (không "tai thỏ" nào lớn hơn thế) để một giá trị lỗi không phá bố cục.

const MAX_FRACTION := 0.12

## Trả {left, top, right, bottom} theo px canvas. vp = get_viewport()...size.
static func insets(vp: Vector2) -> Dictionary:
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	var l := maxf(safe.position.x - float(win_pos.x), 0.0)
	var t := maxf(safe.position.y - float(win_pos.y), 0.0)
	var r := maxf(float(win_pos.x + win_size.x) - safe.end.x, 0.0)
	var b := maxf(float(win_pos.y + win_size.y) - safe.end.y, 0.0)
	var sx := vp.x / maxf(float(win_size.x), 1.0)
	var sy := vp.y / maxf(float(win_size.y), 1.0)
	return {
		"left": minf(l * sx, vp.x * MAX_FRACTION),
		"top": minf(t * sy, vp.y * MAX_FRACTION),
		"right": minf(r * sx, vp.x * MAX_FRACTION),
		"bottom": minf(b * sy, vp.y * MAX_FRACTION),
	}
