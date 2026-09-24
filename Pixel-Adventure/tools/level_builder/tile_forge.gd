extends SceneTree
## Sinh atlas terrain 16px "tự ghép" cho 3 world từ các khối 9-slice của asset gốc, rồi
## đóng gói thành TileSet .tres. Chạy 2 bước vì PNG mới phải được Godot import trước khi
## .tres tham chiếu được nó:
##   Godot --headless --path . -s res://tools/level_builder/tile_forge.gd -- png
##   Godot --headless --path . --import
##   Godot --headless --path . -s res://tools/level_builder/tile_forge.gd -- tres
##
## Cách ghép: mỗi ô 16px = 4 mini-tile 8px. Mini-tile chọn vùng nguồn theo việc cạnh
## nào của ô lộ ra ngoài (hàng xóm trống) — lộ trái thì lấy dải viền trái của khối nguồn,
## không lộ thì lấy phần ruột, lặp theo chu kỳ bằng kích thước tile nguồn (nhờ "parity"
## của ô). Vì vậy mọi hình dạng — cột rộng 1 ô, bệ dày 1 ô — đều có viền đúng, và khối
## nguồn 32px (Kings and Pigs) giữ nguyên độ nét thay vì bị thu nhỏ mờ.
##
## Bố cục atlas (cột = mask 4 hướng, hàng = parity):
##   hàng 0..3 : ô đặc, cột = mask (N=1, E=2, S=4, W=8 — bit bật = hàng xóm là đất),
##               hàng = px + 2*py (parity x/y của ô trên lưới)
##   hàng 4    : nền một chiều (one-way) — cột 0 đơn, 1 đầu trái, 2 giữa, 3 đầu phải;
##               cột 4..7 như trên cho parity x lẻ
##   hàng 5    : tường nền (không va chạm) — cột = px + 2*py; chỉ world có "back_src"

const OUT_DIR := "res://levels/shared/tilesets/"
const N := 1
const E := 2
const S := 4
const W := 8

## src: ảnh nguồn · origin: góc trên-trái của khối 3x3 (px) · t: cạnh tile nguồn (px)
## plat_*: khối 3x3 dùng lấy dải mép trên làm ván một chiều.
const TERRAINS := {
	"forest": {
		"src": "res://levels/level_1/terrain/Terrain (16x16).png",
		"origin": Vector2i(96, 0), "t": 16,
		"plat_src": "res://levels/level_1/terrain/Terrain (16x16).png",
		"plat_origin": Vector2i(0, 64), "plat_t": 16,
	},
	"castle": {
		"src": "res://levels/shared/tilesets/castle_terrain_32.png",
		"origin": Vector2i(32, 32), "t": 32,
		"plat_src": "res://levels/shared/tilesets/castle_terrain_32.png",
		"plat_origin": Vector2i(32, 32), "plat_t": 32,
		"back_src": "res://levels/shared/tilesets/castle_terrain_32.png",
		"back_rect": Rect2i(64, 256, 32, 32), "back_bg": Color("#2b2436"),
	},
	"dungeon": {
		"src": "res://levels/level_1/terrain/Terrain (16x16).png",
		"origin": Vector2i(0, 0), "t": 16,
		"plat_src": "res://levels/level_1/terrain/Terrain (16x16).png",
		"plat_origin": Vector2i(0, 0), "plat_t": 16,
		"back_src": "res://levels/shared/tilesets/dungeon_wall_16.png",
		"back_rect": Rect2i(0, 0, 16, 16), "back_bg": Color("#16131c"),
	},
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "png"
	for key: String in TERRAINS:
		if mode == "png":
			_make_png(key, TERRAINS[key])
		else:
			_make_tileset(key)
	quit()

static func _load_image(path: String) -> Image:
	# Đọc thẳng file (không qua import) để bước "png" chạy được trước khi import.
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img

## Toạ độ nguồn (theo 1 trục) của mini-tile. lo/hi_exposed = cạnh đầu/cuối của ô lộ ra.
static func _src_axis(t: int, first_half: bool, lo_exposed: bool, hi_exposed: bool, parity: int) -> int:
	if first_half:
		if lo_exposed:
			return 0
		if hi_exposed:
			return 3 * t - 16
	else:
		if hi_exposed:
			return 3 * t - 8
		if lo_exposed:
			return 8
	return t + ((parity * 16 + (0 if first_half else 8)) % t)

func _make_png(key: String, def: Dictionary) -> void:
	var src := _load_image(def["src"])
	var o: Vector2i = def["origin"]
	var t: int = def["t"]
	var out := Image.create(16 * 16, 16 * 6, false, Image.FORMAT_RGBA8)
	for row in 4:
		var px := row % 2
		var py := row / 2
		for mask in 16:
			var cell := Vector2i(mask * 16, row * 16)
			for my in 2:
				for mx in 2:
					var sx := _src_axis(t, mx == 0, mask & W == 0, mask & E == 0, px)
					var sy := _src_axis(t, my == 0, mask & N == 0, mask & S == 0, py)
					out.blit_rect(src, Rect2i(o + Vector2i(sx, sy), Vector2i(8, 8)), cell + Vector2i(mx * 8, my * 8))
	# Ván một chiều: dải 8px mép trên, có đầu mút trái/phải.
	var psrc := _load_image(def["plat_src"])
	var po: Vector2i = def["plat_origin"]
	var pt: int = def["plat_t"]
	for px in 2:
		for kind in 4:  # 0 đơn, 1 đầu trái, 2 giữa, 3 đầu phải
			var cell := Vector2i((kind + px * 4) * 16, 4 * 16)
			var left_cap := kind == 0 or kind == 1
			var right_cap := kind == 0 or kind == 3
			for mx in 2:
				var sx := _src_axis(pt, mx == 0, left_cap, right_cap, px)
				out.blit_rect(psrc, Rect2i(po + Vector2i(sx, 0), Vector2i(8, 8)), cell + Vector2i(mx * 8, 0))
	# Tường nền: tile nguồn (16 hoặc 32px) cắt theo parity, dán lên nền tối cho đục hẳn
	# (tile gốc của Kings and Pigs bán trong suốt — để lộ parallax thì trông như lỗi).
	if def.has("back_src"):
		var bsrc := _load_image(def["back_src"])
		var br: Rect2i = def["back_rect"]
		for pi in 4:
			var bpx := pi % 2
			var bpy := pi / 2
			var tile := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			tile.fill(def["back_bg"])
			var sub := Rect2i(br.position + Vector2i((bpx * 16) % br.size.x, (bpy * 16) % br.size.y), Vector2i(16, 16))
			tile.blend_rect(bsrc, sub, Vector2i.ZERO)
			out.blit_rect(tile, Rect2i(0, 0, 16, 16), Vector2i(pi * 16, 5 * 16))
	var path := OUT_DIR + key + "_auto.png"
	out.save_png(ProjectSettings.globalize_path(path))
	print("wrote ", path)

func _make_tileset(key: String) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(OUT_DIR + key + "_auto.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var plank := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -2), Vector2(-8, -2)])
	for row in 4:
		for mask in 16:
			_add_tile(src, Vector2i(mask, row), full, false)
	for col in 8:
		_add_tile(src, Vector2i(col, 4), plank, true)
	if TERRAINS[key].has("back_src"):
		for col in 4:
			src.create_tile(Vector2i(col, 5))
	var path := OUT_DIR + key + "_auto.tres"
	var err := ResourceSaver.save(ts, path)
	print("wrote ", path, " err=", err)

static func _add_tile(src: TileSetAtlasSource, coords: Vector2i, poly: PackedVector2Array, one_way: bool) -> void:
	src.create_tile(coords)
	var data := src.get_tile_data(coords, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, poly)
	data.set_collision_polygon_one_way(0, 0, one_way)
