extends Control

const FRAME_SIZE := Vector2i(32, 32)

@onready var characters_box: HBoxContainer = $CenterContainer/VBoxContainer/CharactersBox
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for character_name in CharacterData.NAMES:
		_add_character_button(character_name)

func _add_character_button(character_name: String) -> void:
	var idle_tex: Texture2D = load(CharacterData.get_animation_path(character_name, "Idle (32x32).png"))
	var atlas := AtlasTexture.new()
	atlas.atlas = idle_tex
	atlas.region = Rect2(0, 0, FRAME_SIZE.x, FRAME_SIZE.y)

	var button := TextureButton.new()
	button.texture_normal = atlas
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.custom_minimum_size = Vector2(96, 96)
	button.pressed.connect(_on_character_chosen.bind(character_name))

	var label := Label.new()
	label.text = character_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var box := VBoxContainer.new()
	box.add_child(button)
	box.add_child(label)
	characters_box.add_child(box)

func _on_character_chosen(character_name: String) -> void:
	GameManager.selected_character = character_name
	GameManager.start_new_run()
	SceneTransition.goto("res://levels/level_1/level_1.tscn")

func _on_back() -> void:
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
