extends SceneTree
## Chạy: tests/run_tests.sh tests/test_screen_fit.gd
## Mọi màn menu phải lọt màn hình cả trên máy tính (1152x648) lẫn điện thoại sau khi
## MobileScale phóng 1.5 (viewport ảo 768x432) — trước đây menu chính, Cài đặt, Tiến
## trình tràn mất nút dưới cùng trên iPhone. Màn thấp thì menu chính phải xếp ngang.

const SCREENS := [
	"res://ui/main_menu/main_menu.tscn",
	"res://ui/splash/splash.tscn",
	"res://ui/character_select/character_select.tscn",
	"res://ui/level_select/level_select.tscn",
	"res://ui/settings_menu/settings_menu.tscn",
	"res://ui/progress_screen/progress_screen.tscn",
	"res://ui/end_screen/end_screen.tscn",
	"res://ui/pause_menu/pause_menu.tscn",
]

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS ", name)
	else:
		_fails += 1
		printerr("FAIL ", name)


func _run() -> void:
	# end_screen ghi kết quả vào save khi cờ này chưa bật — không đụng file save thật.
	root.get_node("GameManager").result_recorded = true
	root.size = Vector2i(1152, 648)  # cửa sổ headless mặc định là hình vuông
	await process_frame
	for factor: float in [1.0, 1.5]:
		root.content_scale_factor = factor
		var screen := root.get_visible_rect()
		for path: String in SCREENS:
			var scene: Node = load(path).instantiate()
			root.add_child(scene)
			for i in 3:
				await process_frame
			var center: Control = scene.get_node("CenterContainer") if scene.has_node("CenterContainer") \
					else scene.get_node("Root/CenterContainer")
			var tag := "%s @%.1f" % [path.get_file().get_basename(), factor]
			for c in center.get_children():
				if c is Control and c.visible:
					var r: Rect2 = c.get_global_rect()
					# get_global_rect bỏ qua scale của cha → tự nhân scale của center quanh pivot.
					var k: float = center.scale.x
					var pivot: Vector2 = center.global_position + center.pivot_offset
					var shown := Rect2(pivot + (r.position - pivot) * k, r.size * k)
					check(screen.grow(0.5).encloses(shown), "%s: %s fits %s (got %s)" % [tag, c.name, screen.size, shown])
			if path.contains("main_menu"):
				var box: BoxContainer = center.get_node("DialogPanel/VBoxContainer")
				check(box.vertical == (factor == 1.0), "%s: logo/buttons stacked only when tall enough" % tag)
			scene.queue_free()
			await process_frame
	paused = false

	print("ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
