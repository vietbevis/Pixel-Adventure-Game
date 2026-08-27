## Màn chọn nhân vật: sinh 1 thẻ cho mỗi nhân vật trong CharacterData.NAMES
## (portrait từ player/sprites/<Tên>/portrait.png). Cùng cách làm với level_select —
## thêm nhân vật chỉ cần sửa CharacterData, không đụng scene.
extends Control

@onready var characters_box: HBoxContainer = $CenterContainer/VBoxContainer/CharactersBox
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_populate()

func _populate() -> void:
	for child in characters_box.get_children():
		child.queue_free()
	for character_name in CharacterData.NAMES:
		characters_box.add_child(_make_card(character_name))

func _make_card(character_name: String) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)

	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(112, 112)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = load(CharacterData.get_portrait_path(character_name))
	button.pressed.connect(_on_chosen.bind(character_name))
	card.add_child(button)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = CharacterData.get_display(character_name)
	card.add_child(label)
	return card

func _on_chosen(character_name: String) -> void:
	GameManager.selected_character = character_name
	SceneTransition.goto("res://ui/level_select/level_select.tscn")

func _on_back() -> void:
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
