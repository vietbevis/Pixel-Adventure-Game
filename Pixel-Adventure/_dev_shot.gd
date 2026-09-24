extends Node
## Harness chụp ảnh màn hình — CÔNG CỤ DEV TẠM, KHÔNG COMMIT.
## Chạy: Godot --path game res://_dev_shot.tscn -- <res://scene.tscn> <đường/dẫn/ra.png>
## Nạp scene đích, chờ vài frame cho tween/layout ổn định, lưu PNG rồi thoát.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("cần: <scene> <output.png>")
		get_tree().quit(1)
		return
	var scene: PackedScene = load(args[0])
	add_child(scene.instantiate())
	# 40 frame ~0.66s: đủ cho tween fade/pop của các màn UI chạy xong.
	for i in 40:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png(args[1])
	print("saved ", args[1])
	get_tree().quit()
