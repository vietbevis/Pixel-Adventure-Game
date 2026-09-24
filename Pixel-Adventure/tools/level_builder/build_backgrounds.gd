extends SceneTree
## Dựng các scene nền parallax NHIỀU LỚP (shared/backgrounds/<tên>_parallax.tscn) bằng code.
##   Godot --headless --path . -s res://tools/level_builder/build_backgrounds.gd
##
## Mỗi lớp là 1 Parallax2D riêng: trôi ngang theo hệ số của lớp đó (xa = chậm), lặp vô hạn
## theo chiều ngang, và gần như KHOÁ theo chiều dọc với màn hình (scroll_scale.y nhỏ) —
## màn dọc cao 1600px vẫn luôn thấy nền, không trôi lộ mép. Lớp được căn đáy vào đáy
## khung hình (VIEW_H = 648 / zoom 1.7); phần trên ảnh thiếu thì "Backstop" (1 mảng màu
## khoá theo màn hình, màu lấy đúng mép ảnh) lấp vào.
## Nguồn ảnh (đều CC0): meadow = "Parallax background forest" (MatiasVme); deep_forest =
## "Forest Background", night_town / castle_hall / dark_castle = "Gothicvania Patreon's
## Collection" (ansimuz). Xem CREDITS.md.

const VIEW_H := 381.0
const DIR := "res://shared/backgrounds/"

## name → {top: màu lấp phía trên, bottom: màu lấp phía dưới, layers: [[file, scroll_x, scale, autoscroll_x, dy]]}
const SETS := {
	"meadow": {
		"top": Color8(96, 168, 176), "bottom": Color8(60, 84, 70),
		"layers": [
			["meadow/forest_background_sky.png", 0.0, 1.0, 0.0, 0.0],
			["meadow/forest_background_sun.png", 0.02, 1.0, 0.0, 0.0],
			["meadow/forest_background_clouds.png", 0.04, 1.0, -5.0, 0.0],
			["meadow/forest_background_mountains_3.png", 0.08, 1.0, 0.0, 0.0],
			["meadow/forest_background_mountains_2.png", 0.14, 1.0, 0.0, 0.0],
			["meadow/forest_background_mountains_1.png", 0.2, 1.0, 0.0, 0.0],
			["meadow/forest_background_trees.png", 0.3, 1.0, 0.0, 0.0],
			["meadow/forest_background_rocks.png", 0.38, 1.0, 0.0, 0.0],
		],
	},
	"deep_forest": {
		"top": Color8(176, 112, 48), "bottom": Color8(40, 26, 24),
		"layers": [
			["deep_forest/back_trees.png", 0.06, 2.0, 0.0, 0.0],
			["deep_forest/lights.png", 0.1, 2.0, 0.0, 0.0],
			["deep_forest/middle_trees.png", 0.16, 2.0, 0.0, 0.0],
			["deep_forest/front_trees.png", 0.26, 2.0, 0.0, 0.0],
		],
	},
	"night_town": {
		"top": Color8(4, 12, 12), "bottom": Color8(8, 16, 16),
		"layers": [
			["night_town/sky.png", 0.0, 2.0, 0.0, 0.0],
			["night_town/clouds.png", 0.03, 2.0, -4.0, 0.0],
			["night_town/mountains.png", 0.06, 2.0, 0.0, 0.0],
			["night_town/mountains_lights.png", 0.06, 2.0, 0.0, 0.0],
			["night_town/far_buildings.png", 0.12, 2.0, 0.0, -30.0],
			["night_town/forest.png", 0.18, 2.0, 0.0, 0.0],
			["night_town/town.png", 0.26, 2.0, 0.0, 0.0],
		],
	},
	"castle_hall": {
		"top": Color8(7, 7, 7), "bottom": Color8(7, 7, 7),
		"layers": [
			["castle_hall/hall.png", 0.2, 2.0, 0.0, 0.0],
		],
	},
	"dark_castle": {
		"top": Color8(15, 34, 41), "bottom": Color8(15, 34, 41),
		"layers": [
			["dark_castle/hall.png", 0.2, 1.0, 0.0, 0.0],
		],
	},
}

func _initialize() -> void:
	for key: String in SETS:
		_build(key, SETS[key])
	quit()

func _build(key: String, def: Dictionary) -> void:
	var root := Node2D.new()
	root.name = key.to_pascal_case() + "Backdrop"
	# Backstop: khoá cứng theo màn hình, nửa trên / nửa dưới 2 màu.
	var stop := Parallax2D.new()
	stop.name = "Backstop"
	stop.scroll_scale = Vector2.ZERO
	root.add_child(stop)
	stop.add_child(_poly("Top", def["top"], Rect2(-4000, -4000, 8000, 4000 + VIEW_H * 0.5)))
	stop.add_child(_poly("Bottom", def["bottom"], Rect2(-4000, VIEW_H * 0.5, 8000, 4000)))
	var i := 0
	for l: Array in def["layers"]:
		var tex: Texture2D = load(DIR + String(l[0]))
		var sc: float = l[2]
		var p := Parallax2D.new()
		p.name = "Layer%d" % i
		p.scroll_scale = Vector2(l[1], 0.03)
		p.repeat_size = Vector2(tex.get_width() * sc, 0)
		p.repeat_times = 4
		p.autoscroll = Vector2(l[3], 0)
		var s := Sprite2D.new()
		s.name = String(l[0]).get_file().get_basename().to_pascal_case()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(sc, sc)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Căn đáy ảnh vào đáy khung hình (+dy nếu cần nâng lớp lên).
		s.position = Vector2(0, VIEW_H - tex.get_height() * sc + float(l[4]))
		p.add_child(s)
		root.add_child(p)
		i += 1
	_own(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var path := DIR + key + "_parallax.tscn"
	print("wrote ", path, " err=", ResourceSaver.save(ps, path))
	root.free()

static func _poly(name: String, c: Color, r: Rect2) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = name
	p.color = c
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	return p

static func _own(root: Node, n: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(root, c)
