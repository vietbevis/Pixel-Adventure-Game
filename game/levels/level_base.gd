class_name LevelBase
extends Node2D
## Script dùng chung cho MỌI màn chơi (level_1..level_5 đều gắn script này).
## Quản lý: spawn point từ $Interactables/StartMarker, refill tim, giới hạn camera,
## phát hiện rơi khỏi map, và menu Pause.
## Đặt ở levels/ (không thuộc màn nào) vì ≥2 màn tham chiếu — xem CONTRIBUTING.md.

const PAUSE_MENU_SCENE := preload("res://ui/pause_menu/pause_menu.tscn")

@export var fall_death_y: float = 500.0

## Giới hạn camera theo biên bản đồ, tránh camera lộ ra vùng chưa được vẽ (nền/đất)
## nằm ngoài map khi người chơi đứng gần rìa trái/phải.
@export var camera_limit_left: int = -16
@export var camera_limit_right: int = 736
@export var camera_limit_top: int = -160
@export var camera_limit_bottom: int = 256

@onready var player: CharacterBody2D = $Player

var pause_menu_instance: CanvasLayer = null

func _enter_tree() -> void:
	# Runs before any child's _ready(), so Player picks up the right spawn point.
	if not GameManager.has_checkpoint:
		GameManager.respawn_position = $Interactables/StartMarker.global_position
	# Mỗi lần màn chơi được load lại (vào mới hoặc restart) đều cho đầy tim,
	# tránh trường hợp người chơi bắt đầu với tim còn lại từ lượt chơi trước.
	GameManager.hearts = GameManager.MAX_HEARTS

func _ready() -> void:
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = camera_limit_left
	camera.limit_right = camera_limit_right
	camera.limit_top = camera_limit_top
	camera.limit_bottom = camera_limit_bottom

func _process(_delta: float) -> void:
	if not player.is_dead and player.global_position.y > fall_death_y:
		# Rơi khỏi map: luôn bung ngay về điểm respawn (force_reposition = true)
		# để không bị trừ tim liên tục mỗi frame trong lúc còn đang rơi.
		player.hit(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not player.is_dead:
		_open_pause_menu()

func _open_pause_menu() -> void:
	if pause_menu_instance:
		return
	pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu_instance)
	pause_menu_instance.tree_exiting.connect(func() -> void: pause_menu_instance = null)
	get_tree().paused = true
