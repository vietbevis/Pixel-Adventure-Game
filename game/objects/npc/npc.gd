extends Area2D
## NPC thoại tĩnh trong hub: đứng gần + bấm `interact` (E) → mở hộp thoại (Dialogue autoload).
## Dùng lại sprite idle của Pig (không cần art mới). Bong bóng "Hello" của Kings and Pigs
## nổi trên đầu lúc đang nói. `report_abilities` = thêm 1 dòng liệt kê ability đã mở.

@export_multiline var line_1: String = ""
@export_multiline var line_2: String = ""
@export_multiline var line_3: String = ""
@export var speaker: String = ""
## Nếu bật: append 1 dòng về các ability người chơi đã mở khoá (dựng từ SaveManager).
@export var report_abilities: bool = false
## SpriteFrames cho dáng đứng NPC — mặc định là Pig. Đổi trên instance nếu muốn NPC khác.
@export var idle_frames: SpriteFrames = preload("res://objects/enemies/pig/sprites/pig_frames.tres")
## Hướng nhìn mặc định của sprite: false = quay trái (Kings and Pigs), true = quay phải (Pixel Frog).
@export var sprite_faces_right: bool = false

## Tên hiển thị của từng ability trong dòng report (khớp DISPLAY của Toast).
const ABILITY_NAMES := {"dash": "Lướt (Dash)"}

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _bubble: AnimatedSprite2D = $Bubble
@onready var _prompt: Label = $Prompt

var _near: bool = false

func _ready() -> void:
	_sprite.sprite_frames = idle_frames
	_sprite.play("idle")
	_bubble.visible = false
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Dialogue.finished.connect(_on_dialogue_finished)

func _process(_delta: float) -> void:
	if _near and not Dialogue.is_blocking_interact() and Input.is_action_just_pressed("interact"):
		_face_player()
		_bubble.visible = true
		_bubble.play("in")
		Dialogue.open(_build_lines(), speaker)

func _build_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for line: String in [line_1, line_2, line_3]:
		if line != "":
			lines.append(line)
	if report_abilities:
		lines.append(_ability_line())
	return lines

func _ability_line() -> String:
	var unlocked: Array = SaveManager.get_unlocked_abilities()
	if unlocked.is_empty():
		return "Ngươi chưa có sức mạnh nào. Di vật của các hiệp sĩ xưa vẫn nằm đâu đó trong Rừng."
	var names: PackedStringArray = []
	for id: String in unlocked:
		names.append(String(ABILITY_NAMES.get(id, id.capitalize())))
	return "Sức mạnh ngươi đã có: %s." % ", ".join(names)

func _face_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		var player_on_right := player.global_position.x > global_position.x
		_sprite.flip_h = player_on_right != sprite_faces_right

func _on_dialogue_finished() -> void:
	if _bubble.visible:
		_bubble.play("out")
		await _bubble.animation_finished
		_bubble.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true
		_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false
