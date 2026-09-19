extends SceneTree

func _init():
	var scene_path = "res://levels/level_1/level_1.tscn"
	var packed_scene = ResourceLoader.load(scene_path)
	var root = packed_scene.instantiate()
	var terrain = root.get_node("Terrain")
	
	# The floating platform seems to be blocking the player near x=832, y=144 to y=176.
	# Let's just remove the tiles from the floating platform that block the path,
	# or clear the space above the ground.
	
	# Pig is at y=128 (tile y=8), fruit is at y=192 (tile y=12).
	# The platform blocking the player is probably at y=9, 10 or 11.
	var removed = 0
	for x in range(45, 60):
		for y in range(8, 12):
			if terrain.get_cell_source_id(Vector2i(x, y)) != -1:
				print("Removing tile at ", x, ", ", y)
				terrain.set_cell(Vector2i(x, y), -1)
				removed += 1
				
	if removed > 0:
		var new_scene = PackedScene.new()
		new_scene.pack(root)
		var err = ResourceSaver.save(new_scene, scene_path)
		if err == OK:
			print("Successfully saved scene with ", removed, " tiles removed.")
		else:
			print("Error saving scene: ", err)
	else:
		print("No tiles found to remove in that area.")
		
	quit()
