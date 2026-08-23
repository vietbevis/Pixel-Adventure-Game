## Màn chọn level: hiện 1 nút cho mỗi màn trong LevelData.LEVELS.
## Màn đã mở (unlock) thì bấm được, kèm điểm cao nhất; màn chưa mở thì khoá (disabled).
extends Control

@onready var levels_box: VBoxContainer = $CenterContainer/DialogPanel/VBoxContainer/LevelsScroll/LevelsBox
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_populate_levels()

func _populate_levels() -> void:
	for child in levels_box.get_children():
		child.queue_free()
	for level in LevelData.LEVELS:
		_add_level_button(level["id"], level["name"])

func _add_level_button(level_id: String, level_name: String) -> void:
	var unlocked := SaveManager.is_level_unlocked(level_id)
	var high_score := SaveManager.get_high_score(level_id)
	var best_time := SaveManager.get_best_time(level_id)

	var button := Button.new()
	button.custom_minimum_size = Vector2(280, 52)
	button.disabled = not unlocked
	if unlocked:
		button.theme_type_variation = &"PrimaryButton"
		var stats := ""
		if high_score > 0:
			stats += "  ·  Best %d" % high_score
		if best_time >= 0.0:
			stats += "  ·  ⏱ %s" % LevelData.format_time(best_time)
		button.text = level_name + stats
		button.pressed.connect(_on_level_chosen.bind(level_id))
	else:
		button.text = "🔒  %s" % level_name
	levels_box.add_child(button)

func _on_level_chosen(level_id: String) -> void:
	GameManager.start_new_run(level_id)
	SceneTransition.goto(LevelData.get_scene_path(level_id))

func _on_back() -> void:
	SceneTransition.goto("res://ui/character_select/character_select.tscn")
