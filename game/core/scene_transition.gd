## Autoload (scene_transition.tscn): mọi màn chuyển scene qua goto() để luôn có
## hiệu ứng fade to black giống nhau, và không bao giờ bị kẹt paused sau khi
## đổi màn. Hiệu ứng fade dựng bằng AnimationPlayer trong scene_transition.tscn
## (Godot editor) — script chỉ phát animation, không tự tween bằng code.
extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer

## Chặn gọi chồng: goto() là coroutine nối thẳng vào signal `pressed` của ~10 nút,
## double-click sẽ khởi 2 lượt fade + 2 lần change_scene → màn đen / kẹt.
var _busy: bool = false

func goto(path: String) -> void:
	if _busy:
		return
	if path.is_empty():
		push_error("SceneTransition.goto: đường dẫn scene rỗng — bỏ qua.")
		return
	_busy = true
	get_tree().paused = false
	# An toàn: nếu đổi scene ngay giữa lúc hit-stop (player.gd) chưa kịp khôi phục.
	Engine.time_scale = 1.0
	animation_player.play("fade_in")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	animation_player.play("fade_out")
	await animation_player.animation_finished
	_busy = false
