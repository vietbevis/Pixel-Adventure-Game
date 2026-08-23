extends CanvasLayer
## Instanced by level_1.gd on top of the game when the player presses "pause".
## process_mode is ALWAYS so its buttons keep working while the tree is paused.

@onready var resume_button: Button = $CenterContainer/Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/Panel/VBoxContainer/RestartButton
@onready var menu_button: Button = $CenterContainer/Panel/VBoxContainer/MenuButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)

func _on_resume() -> void:
	get_tree().paused = false
	queue_free()

func _on_restart() -> void:
	GameManager.start_new_run(GameManager.current_level_id)
	SceneTransition.goto(LevelData.get_scene_path(GameManager.current_level_id))

func _on_menu() -> void:
	GameManager.has_checkpoint = false
	SceneTransition.goto("res://ui/level_select/level_select.tscn")
