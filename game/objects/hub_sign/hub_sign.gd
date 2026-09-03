extends Area2D
## Biển chỉ dẫn trong hub: player đứng gần + bấm `interact` → đổi sang `target_scene`.
## Dùng cho "Levels" (chơi lẻ), và sau này Settings / Achievements...

@export var target_scene: String = "res://ui/level_select/level_select.tscn"
@export var label_text: String = "Levels"

@onready var _label: Label = $Label
@onready var _prompt: Label = $Prompt

var _near: bool = false

func _ready() -> void:
	_label.text = label_text
	_prompt.visible = false
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _process(_delta: float) -> void:
	if _near and not Dialogue.is_blocking_interact() and Input.is_action_just_pressed("interact"):
		SceneTransition.goto(target_scene)

func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true
		_prompt.visible = true

func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false
