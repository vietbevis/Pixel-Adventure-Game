class_name ScreenFit
extends RefCounted
## Giữ khối menu giữa màn (CenterContainer > Panel) lọt màn hình ở MỌI kích thước/tỉ lệ:
## máy tính 16:9, iPad 4:3, điện thoại ngang 19.5:9/20:9 (sau khi MobileScale phóng to
## thì viewport ảo chỉ còn ~430px cao). Mỗi lần viewport đổi cỡ, thử lần lượt:
##   1. bố cục gốc (xếp dọc) nếu đủ cao;
##   2. `flip`: các BoxContainer chuyển sang xếp ngang — màn ngang thấp dùng bề rộng dư;
##   3. `shrink`: các ScrollContainer thấp/hẹp bớt (nội dung vẫn cuộn), không dưới MIN_SCROLL;
##   4. vẫn thiếu thì thu nhỏ đều cả khối quanh tâm màn hình.
## Scale đặt trên chính CenterContainer: Container reset scale của con mỗi lần sắp xếp.

const MARGIN := 10.0
const MIN_SCROLL := Vector2(300, 96)

## Gọi trong `_ready` của màn. Lần tính đầu chạy deferred, sau khi màn dựng xong nội dung động.
static func attach(center: Control, flip: Array[BoxContainer] = [], shrink: Array[ScrollContainer] = []) -> void:
	for s in shrink:
		s.set_meta(&"fit_min", s.custom_minimum_size)
	# Gom nhiều lần kích hoạt trong 1 frame thành 1 lần tính.
	var refit := func() -> void:
		if center.has_meta(&"fit_pending"):
			return
		center.set_meta(&"fit_pending", true)
		(func() -> void:
			if not is_instance_valid(center):
				return  # màn đã bị đổi trước khi kịp tính
			center.remove_meta(&"fit_pending")
			_refit(center, flip, shrink)).call_deferred()
	# Signal của chính các node màn này → tự ngắt khi màn bị giải phóng.
	center.resized.connect(refit)
	# Hiện/ẩn một phần tử (hộp xác nhận, nút BẮT ĐẦU, nút Màn tiếp...) đổi kích thước cần chứa.
	for c in center.find_children("*", "Control", true, false):
		c.visibility_changed.connect(refit)
	refit.call()

static func _refit(center: Control, flip: Array[BoxContainer], shrink: Array[ScrollContainer]) -> void:
	if not center.is_inside_tree():
		return
	var screen := center.get_viewport().get_visible_rect().size
	var avail := screen - Vector2.ONE * MARGIN * 2.0
	for b in flip:
		b.vertical = true
	for s in shrink:
		s.custom_minimum_size = s.get_meta(&"fit_min")

	var over := _need(center).y - avail.y
	if over > 0.0 and not flip.is_empty():
		for b in flip:
			b.vertical = false
		over = _need(center).y - avail.y
	var over_x := _need(center).x - avail.x
	for s in shrink:
		var cut_y := clampf(over, 0.0, maxf(0.0, s.custom_minimum_size.y - MIN_SCROLL.y))
		var cut_x := clampf(over_x, 0.0, maxf(0.0, s.custom_minimum_size.x - MIN_SCROLL.x))
		s.custom_minimum_size -= Vector2(cut_x, cut_y)
		over -= cut_y
		over_x -= cut_x

	var need := _need(center)
	var k := 1.0
	if need.x > 0.0 and need.y > 0.0:
		k = minf(1.0, minf(avail.x / need.x, avail.y / need.y))
	center.pivot_offset = screen * 0.5
	center.scale = Vector2.ONE * k

## Kích thước tối thiểu của panel đang hiện (CenterContainer có thể chứa vài panel luân phiên).
static func _need(center: Control) -> Vector2:
	var need := Vector2.ZERO
	for c in center.get_children():
		if c is Control and c.visible:
			need = need.max((c as Control).get_combined_minimum_size())
	return need
