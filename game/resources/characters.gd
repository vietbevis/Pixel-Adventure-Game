class_name CharacterData
extends RefCounted

## Playable characters, matching the folder names in assets/characters/.
const NAMES: Array[String] = ["Mask Dude", "Ninja Frog", "Pink Man", "Virtual Guy"]

const ANIMATION_FILES := {
	"idle": "Idle (32x32).png",
	"run": "Run (32x32).png",
	"jump": "Jump (32x32).png",
	"double_jump": "Double Jump (32x32).png",
	"wall_jump": "Wall Jump (32x32).png",
	"fall": "Fall (32x32).png",
	"hit": "Hit (32x32).png",
}

static func get_folder(character_name: String) -> String:
	return "res://assets/characters/%s/" % character_name

static func get_animation_path(character_name: String, animation_file: String) -> String:
	return get_folder(character_name) + animation_file
