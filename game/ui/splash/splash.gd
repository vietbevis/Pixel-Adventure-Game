## Màn hình vào game (splash / loading): hiện logo + ảnh giới thiệu, chạy thanh
## loading trong lúc nạp trước các scene nặng (menu, chọn nhân vật, hub, màn 1,
## player) bằng ResourceLoader nền. Nạp xong + qua thời gian tối thiểu → hiện nút
## "BẮT ĐẦU" / nhận phím bất kỳ để sang Main Menu.
extends Control

const NEXT_SCENE := "res://ui/main_menu/main_menu.tscn"

## Nạp trước để lần chuyển scene đầu tiên không khựng.
const PRELOAD := [
	"res://ui/main_menu/main_menu.tscn",
	"res://ui/character_select/character_select.tscn",
	"res://levels/hub/hub.tscn",
	"res://levels/level_1/level_1.tscn",
	"res://player/player.tscn",
]

## Thanh loading luôn hiển thị ít nhất chừng này giây dù nạp xong sớm.
const MIN_DISPLAY_TIME := 1.4

@onready var bar: ProgressBar = $CenterContainer/VBoxContainer/LoadingBar
@onready var status: Label = $CenterContainer/VBoxContainer/StatusLabel
@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton

var _elapsed: float = 0.0
var _ready_to_go: bool = false

func _ready() -> void:
	start_button.visible = false
	start_button.pressed.connect(_go)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	for path: String in PRELOAD:
		ResourceLoader.load_threaded_request(path)

func _process(delta: float) -> void:
	_elapsed += delta
	if _ready_to_go:
		return

	var total_progress := 0.0
	var done := 0
	for path: String in PRELOAD:
		var parts: Array = []
		var st := ResourceLoader.load_threaded_get_status(path, parts)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			total_progress += 1.0
			done += 1
		elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS and parts.size() > 0:
			total_progress += float(parts[0])

	var load_ratio := total_progress / float(PRELOAD.size())
	var time_ratio := clampf(_elapsed / MIN_DISPLAY_TIME, 0.0, 1.0)
	bar.value = minf(load_ratio, time_ratio)

	if done == PRELOAD.size() and _elapsed >= MIN_DISPLAY_TIME:
		_finish_loading()

func _finish_loading() -> void:
	_ready_to_go = true
	bar.value = 1.0
	status.text = "NHẤN PHÍM BẤT KỲ ĐỂ BẮT ĐẦU"
	start_button.visible = true
	start_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_go:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_go()
	elif event is InputEventMouseButton and event.pressed:
		_go()

func _go() -> void:
	if not _ready_to_go:
		return
	_ready_to_go = false  # chặn gọi hai lần
	SceneTransition.goto(NEXT_SCENE)
