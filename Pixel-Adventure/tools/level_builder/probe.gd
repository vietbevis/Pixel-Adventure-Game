extends SceneTree
## Prints the footprint of every object scene: collision rects + opaque sprite rects,
## relative to the scene root origin. Used to derive placement anchors.

func _initialize() -> void:
	var paths: PackedStringArray = []
	_scan("res://objects", paths)
	for p in paths:
		var inst: Node = (load(p) as PackedScene).instantiate()
		var line := "%s [%s]" % [p.replace("res://objects/", ""), inst.get_class()]
		print(line)
		_dump(inst, inst, "  ")
		inst.free()
	quit()

func _scan(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + d, out)

func _xf(root: Node, n: Node) -> Transform2D:
	var t := Transform2D.IDENTITY
	var cur := n
	while cur != root and cur != null:
		if cur is Node2D:
			t = (cur as Node2D).transform * t
		cur = cur.get_parent()
	return t

func _dump(root: Node, n: Node, ind: String) -> void:
	for c in n.get_children():
		if c is CollisionShape2D and c.shape:
			var r: Rect2 = c.shape.get_rect()
			var t := _xf(root, c)
			var rr := t * r
			print("%sshape %s %s parent=%s" % [ind, c.name, rr, c.get_parent().name])
		elif c is CollisionPolygon2D:
			var t := _xf(root, c)
			var pts: PackedVector2Array = t * c.polygon
			var rr := Rect2(pts[0], Vector2.ZERO)
			for p in pts: rr = rr.expand(p)
			print("%spoly %s %s" % [ind, c.name, rr])
		elif c is AnimatedSprite2D and c.sprite_frames:
			var anim: StringName = c.animation
			if not c.sprite_frames.has_animation(anim):
				anim = c.sprite_frames.get_animation_names()[0]
			var tex: Texture2D = c.sprite_frames.get_frame_texture(anim, 0)
			print("%sanim %s %s" % [ind, c.name, _opaque(root, c, tex, c.centered, c.offset)])
		elif c is Sprite2D and c.texture:
			var tex: Texture2D = c.texture
			if c.hframes > 1 or c.vframes > 1 or c.region_enabled:
				print("%ssprite %s (sheet/region) size=%s" % [ind, c.name, c.texture.get_size()])
			else:
				print("%ssprite %s %s" % [ind, c.name, _opaque(root, c, tex, c.centered, c.offset)])
		_dump(root, c, ind + "  ")

func _opaque(root: Node, c: Node2D, tex: Texture2D, centered: bool, offset: Vector2) -> String:
	var img := tex.get_image()
	if img == null:
		return "noimg"
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var size := Vector2(img.get_size())
	var origin := offset - (size / 2.0 if centered else Vector2.ZERO)
	var r := Rect2(origin + Vector2(used.position), Vector2(used.size))
	return "%s (frame %s)" % [_xf(root, c) * r, size]
