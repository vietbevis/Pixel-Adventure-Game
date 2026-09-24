extends SceneTree
## Dựng các màn từ tools/level_builder/levels/<id>.gd → levels/<id>/<id>.tscn.
##   Godot --headless --path . -s res://tools/level_builder/build_levels.gd -- level_1 level_2
## Không truyền id = dựng tất cả. Màn có lỗi (vật lơ lửng, thiếu cờ...) thì KHÔNG ghi file.
## Kèm theo ghi <id>.json (lưới + vật thể) vào thư mục tuỳ chọn --json=<dir> cho validator.

const SPEC_DIR := "res://tools/level_builder/levels/"

func _initialize() -> void:
	var ids: PackedStringArray = []
	var json_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--json="):
			json_dir = a.substr(7)
		else:
			ids.append(a)
	if ids.is_empty():
		for f in DirAccess.get_files_at(SPEC_DIR):
			if f.ends_with(".gd"):
				ids.append(f.get_basename())
	var failed := 0
	for level_id in ids:
		var spec: RefCounted = load(SPEC_DIR + level_id + ".gd").new()
		var root: Node2D = spec.build()
		for w in spec.warnings:
			print("  [warn] %s: %s" % [level_id, w])
		if not spec.errors.is_empty():
			for e in spec.errors:
				printerr("  [LỖI] %s: %s" % [level_id, e])
			failed += 1
			root.free()
			continue
		var out: String = "res://levels/%s/%s.tscn" % [spec.id, spec.id]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
		_own(root, root)
		var ps := PackedScene.new()
		var err := ps.pack(root)
		if err == OK:
			err = ResourceSaver.save(ps, out)
		print("%s → %s (err=%d)" % [level_id, out, err])
		if json_dir != "":
			var f := FileAccess.open(json_dir.path_join(level_id + ".json"), FileAccess.WRITE)
			f.store_string(JSON.stringify(spec.to_json()))
		root.free()
	quit(1 if failed > 0 else 0)

static func _own(root: Node, n: Node) -> void:
	for c in n.get_children():
		c.owner = root
		# Con của scene instance thuộc về scene đó — không kéo vào scene màn.
		if c.scene_file_path == "":
			_own(root, c)
