extends Node
## Autoload: small helper so every screen changes scenes the same way
## (and always makes sure the game isn't left paused behind it).

func goto(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
