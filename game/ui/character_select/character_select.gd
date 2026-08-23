## Màn chọn nhân vật: 4 nút bấm được dựng sẵn trong character_select.tscn
## (Godot editor), script chỉ nối sự kiện bấm — không tự tạo node bằng code.
extends Control

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var character_buttons: Dictionary = {
	"Mask Dude": $CenterContainer/VBoxContainer/CharactersBox/MaskDude/Button,
	"Ninja Frog": $CenterContainer/VBoxContainer/CharactersBox/NinjaFrog/Button,
	"Pink Man": $CenterContainer/VBoxContainer/CharactersBox/PinkMan/Button,
	"Virtual Guy": $CenterContainer/VBoxContainer/CharactersBox/VirtualGuy/Button,
}

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for character_name in character_buttons:
		var button: TextureButton = character_buttons[character_name]
		button.pressed.connect(_on_character_chosen.bind(character_name))

func _on_character_chosen(character_name: String) -> void:
	GameManager.selected_character = character_name
	SceneTransition.goto("res://ui/level_select/level_select.tscn")

func _on_back() -> void:
	SceneTransition.goto("res://ui/main_menu/main_menu.tscn")
