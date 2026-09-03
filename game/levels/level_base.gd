class_name LevelBase
extends Node2D
## Script dùng chung cho MỌI màn chơi (level_1..level_5 đều gắn script này).
## Quản lý: spawn point từ $Interactables/StartMarker, refill tim, giới hạn camera,
## phát hiện rơi khỏi map, và menu Pause.
## Đặt ở levels/ (không thuộc màn nào) vì ≥2 màn tham chiếu — xem CONTRIBUTING.md.

const PAUSE_MENU_SCENE := preload("res://ui/pause_menu/pause_menu.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://ui/touch_controls/touch_controls.tscn")

@export var fall_death_y: float = 500.0

## Thẻ tiêu đề mờ dần ~2.5s đầu màn (kể chuyện). "" = không hiện.
## world_title = tên world in hoa; level_subtitle = tên màn nhỏ bên dưới.
@export var world_title: String = ""
@export var level_subtitle: String = ""

## Giới hạn camera theo biên bản đồ, tránh camera lộ ra vùng chưa được vẽ (nền/đất)
## nằm ngoài map khi người chơi đứng gần rìa trái/phải.
@export var camera_limit_left: int = -16
@export var camera_limit_right: int = 736
@export var camera_limit_top: int = -160
@export var camera_limit_bottom: int = 256

@onready var player: CharacterBody2D = $Player
@onready var _camera: Camera2D = $Player/Camera2D

var pause_menu_instance: CanvasLayer = null

func _enter_tree() -> void:
	# Runs before any child's _ready(), so Player picks up the right spawn point.
	var start_marker := get_node_or_null(^"Interactables/StartMarker")
	if start_marker == null:
		push_error("%s: thiếu node Interactables/StartMarker — spawn sẽ sai." % name)
	elif not GameManager.has_checkpoint:
		GameManager.respawn_position = start_marker.global_position
	# (Tim đầy lại tự động: player được tạo mới khi load màn → HealthComponent._ready
	# đặt hp = max_hp.)

func _ready() -> void:
	_camera.limit_left = camera_limit_left
	_camera.limit_right = camera_limit_right
	_camera.limit_top = camera_limit_top
	_camera.limit_bottom = camera_limit_bottom

	var touch := TOUCH_CONTROLS_SCENE.instantiate()
	touch.pause_pressed.connect(_on_pause_requested)
	add_child(touch)

	var world := WorldData.world_of(GameManager.current_level_id)
	GameManager.current_world = world
	GameManager.set_timer_running(true)
	AudioManager.play_music(world)
	Events.level_started.emit(GameManager.current_level_id)

	if world_title != "":
		_show_title_card()

## Thẻ tiêu đề: 1 CanvasLayer tạm với tiêu đề world + phụ đề màn, tween fade in/hold/out
## rồi tự huỷ. Dựng bằng code để mọi màn dùng chung không cần thêm node vào scene.
func _show_title_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := Label.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.text = world_title
	root.add_child(title)

	if level_subtitle != "":
		var sub := Label.new()
		sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sub.offset_top = 44.0
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 15)
		sub.add_theme_constant_override("outline_size", 4)
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		sub.modulate = Color(0.85, 0.82, 0.7)
		sub.text = level_subtitle
		root.add_child(sub)

	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.6)
	tween.tween_property(root, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)

func _process(_delta: float) -> void:
	if not player.is_dead and player.global_position.y > fall_death_y:
		# Rơi khỏi map: luôn bung ngay về điểm respawn (force_reposition = true)
		# để không bị trừ tim liên tục mỗi frame trong lúc còn đang rơi.
		player.hit(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not player.is_dead:
		_open_pause_menu()

func _on_pause_requested() -> void:
	if not player.is_dead:
		_open_pause_menu()

func _open_pause_menu() -> void:
	if pause_menu_instance:
		return
	pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu_instance)
	pause_menu_instance.tree_exiting.connect(func() -> void: pause_menu_instance = null)
	get_tree().paused = true
