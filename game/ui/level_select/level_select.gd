## Màn chọn level: nhóm theo world (WorldData.WORLDS), mỗi world 1 tiêu đề + các màn của nó.
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
	for world: Dictionary in WorldData.WORLDS:
		_add_world_header(world["name"])
		for level_id: String in world["levels"]:
			_add_level_button(level_id, _level_name(level_id))

func _add_world_header(world_name: String) -> void:
	var label := Label.new()
	label.text = world_name.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55))
	levels_box.add_child(label)

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
	SceneTransition.goto("res://levels/hub/hub.tscn")

## Tên hiển thị của từng màn — tra từ LevelData để không lặp chuỗi.
func _level_name(level_id: String) -> String:
	var idx := LevelData.get_index(level_id)
	return LevelData.LEVELS[idx]["name"] if idx != -1 else level_id
