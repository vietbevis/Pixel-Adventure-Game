extends Node
## Autoload: phóng to giao diện trên điện thoại. Viewport gốc 1152x648 vẽ lên màn
## điện thoại chỉ cao ~2.5 inch thì chữ 20px còn ~1.6mm — đọc rất khó. Trên mobile
## đặt `content_scale_factor` của root theo kích thước THẬT của màn (inch, từ DPI)
## để mỗi inch màn hình có khoảng TARGET_PX_PER_INCH px ảo; máy tính bảng/màn lớn
## ra hệ số < 1 nên giữ nguyên 1.
## Hệ số này phóng mọi thứ (canvas_items), nên camera (level_base) bù lại để thế giới
## game chỉ to lên `world_factor`, còn nút cảm ứng (touch_controls) giữ đúng cỡ cũ.
## Thử trên máy tính: Godot --path . -- ui_scale=1.5

const BASE_HEIGHT := 648.0
const TARGET_PX_PER_INCH := 170.0
const MAX_FACTOR := 1.6
## Phần phóng dành cho thế giới game: phóng hết bằng `factor` thì khung nhìn hẹp
## quá (thấy ít đường phía trước), nên chỉ phóng nhẹ.
const WORLD_SHARE := 1.2

## Hệ số phóng toàn bộ canvas (1 = như trên máy tính).
var factor := 1.0
## Thế giới game to lên bao nhiêu so với máy tính.
var world_factor := 1.0

func _ready() -> void:
	factor = _pick_factor()
	if factor <= 1.0:
		factor = 1.0
		return
	world_factor = minf(WORLD_SHARE, factor)
	get_tree().root.content_scale_factor = factor

func _pick_factor() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("ui_scale="):
			return arg.get_slice("=", 1).to_float()
	if not OS.has_feature("mobile"):
		return 1.0
	var size := DisplayServer.screen_get_size()
	var dpi := DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return 1.5  # không đọc được DPI: coi như điện thoại
	var short_inches := minf(size.x, size.y) / float(dpi)
	return clampf(BASE_HEIGHT / (short_inches * TARGET_PX_PER_INCH), 1.0, MAX_FACTOR)

## Nhân vào zoom camera: thế giới to lên `world_factor` chứ không phải `factor`.
func camera_zoom_mult() -> float:
	return world_factor / factor
