extends Area2D

@export_multiline var line_1: String = ""
@export_multiline var line_2: String = ""
@export_multiline var line_3: String = ""
@export var speaker: String = ""

@onready var _prompt: Label = $Prompt

var _near: bool = false

func _ready() -> void:
	_prompt.visible = false
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _process(_delta: float) -> void:
	if _near and not Dialogue.is_open and Input.is_action_just_pressed("interact"):
		var lines := PackedStringArray()
		if line_1 != "":
			lines.append(line_1)
		if line_2 != "":
			lines.append(line_2)
		if line_3 != "":
			lines.append(line_3)
		
		if not lines.is_empty():
			Dialogue.open(lines, speaker)

func _on_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true
		_prompt.visible = true

func _on_exit(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false
