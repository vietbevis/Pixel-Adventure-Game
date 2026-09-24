extends RefCounted
## Bộ dựng màn: mỗi màn là 1 script con (tools/level_builder/levels/<id>.gd) khai báo bản
## đồ ASCII + bảng ký hiệu; kit dựng cây node bằng code rồi lưu thành .tscn.
## Chạy: Godot --headless --path . -s res://tools/level_builder/build_levels.gd -- [id...]
##
## Ký hiệu mặc định (màn có thể ghi đè / thêm trong `legend`):
##   #  đất            =  ván một chiều (đứng lên được, nhảy xuyên từ dưới)
##   .  trống (cả dấu cách)
##   S  điểm xuất phát  C  checkpoint   G  cờ đích
##   ^  gai sàn  v  gai trần   *  trái cây   T  lò xo   F  quạt   P  ván sập
##   <  máy bắn tên gắn tường PHẢI, bắn sang trái     >  gắn tường TRÁI, bắn sang phải
##   i  bẫy lửa   I  gai rơi (treo trần)   B  chuỳ gai (treo trần)   O  cưa quay vòng
##   w  cưa đứng yên   X  khối nghiền (treo trần)   c  pháo (bắn trái)
##   o  opossum  g  ếch  e  đại bàng  p  heo  a  heo phục kích  b  heo ném bom
##   k  bộ xương  h  hồn ma  H  chó ngục
##   W  tường nứt (chỉ vỡ khi Lướt vào, cao 3 ô)   Z  cổng Lướt (biến mất khi đã có Dash)
##   t  đuốc tường  d  đuốc đứng  n  nến  x  thùng  $  rương
## Chữ số và ký tự khác: khai báo trong `legend` của màn — {"type": ..., <thuộc tính>...}
## với tuỳ chọn "dx"/"dy" (px) để xê dịch sau khi neo.
##
## Neo vị trí KHÔNG dùng số bù tay: kit đo khung thật của từng scene (collider của thân
## với quái / vật có vật lý, phần có màu của sprite với bẫy / trang trí) rồi đặt đáy
## khung lên mặt đất (neo "floor"), đỉnh khung sát trần ("ceiling") hoặc tâm khung vào
## giữa ô ("center"). Vật "floor" mà ô bên dưới không phải đất, hay vật chồng lên đất,
## đều bị báo lỗi lúc dựng.

const TILE := 16
const TILESETS := {
	"forest": "res://levels/shared/tilesets/forest_auto.tres",
	"castle": "res://levels/shared/tilesets/castle_auto.tres",
	"dungeon": "res://levels/shared/tilesets/dungeon_auto.tres",
}
## Nền mặc định theo world; màn có thể đổi bằng `backdrop` (tên bộ trong build_backgrounds.gd).
const BACKDROPS := {"forest": "meadow", "castle": "castle_hall", "dungeon": "dark_castle"}
const FRUITS := [
	"res://objects/fruit/sprites/apple_frames.tres",
	"res://objects/fruit/sprites/bananas_frames.tres",
	"res://objects/fruit/sprites/cherries_frames.tres",
	"res://objects/fruit/sprites/kiwi_frames.tres",
	"res://objects/fruit/sprites/orange_frames.tres",
]
const PLAYER := "res://player/player.tscn"
const HUD := "res://ui/hud/hud.tscn"
## Người chơi: collider 22x32 tâm ở y=+4 → bàn chân ở gốc + 20.
const PLAYER_FEET := 20.0

## type → scene, neo, nhóm node cha, tiền tố tên, cách đo ("body"/"sprite").
const TYPES := {
	"start": {"scene": "res://objects/start_marker/start_marker.tscn", "anchor": "floor", "group": "Interactables", "name": "StartMarker"},
	"checkpoint": {"scene": "res://objects/checkpoint/checkpoint.tscn", "anchor": "floor", "group": "Interactables", "name": "Checkpoint"},
	"goal": {"scene": "res://objects/goal_flag/goal_flag.tscn", "anchor": "floor", "group": "Interactables", "name": "GoalFlag"},
	"sign": {"scene": "res://objects/story_sign/story_sign.tscn", "anchor": "floor", "group": "Decor", "name": "Sign"},
	"fruit": {"scene": "res://objects/fruit/fruit.tscn", "anchor": "center", "group": "Fruits", "name": "Fruit"},
	"diamond": {"scene": "res://objects/collectible_diamond/collectible_diamond.tscn", "anchor": "center", "group": "Secrets", "name": "Diamond"},
	"relic": {"scene": "res://objects/ability_relic/ability_relic.tscn", "anchor": "center", "group": "Interactables", "name": "Relic"},
	"ability_gate": {"scene": "res://objects/ability_gate/ability_gate.tscn", "anchor": "floor", "group": "Secrets", "name": "AbilityGate", "measure": "body"},
	"dash_wall": {"scene": "res://objects/dash_wall/dash_wall.tscn", "anchor": "floor", "group": "Traps", "name": "DashWall", "measure": "body"},
	"boss_gate": {"scene": "res://objects/boss_gate/boss_gate.tscn", "anchor": "floor", "group": "Interactables", "name": "BossGate", "measure": "body"},
	"spikes": {"scene": "res://objects/enemies/spikes/spikes.tscn", "anchor": "floor", "group": "Traps", "name": "Spikes"},
	"spikes_ceiling": {"scene": "res://objects/enemies/spikes/spikes.tscn", "anchor": "ceiling", "group": "Traps", "name": "SpikesTop", "rotation": PI},
	"trampoline": {"scene": "res://objects/traps/trampoline/trampoline.tscn", "anchor": "floor", "group": "Traps", "name": "Trampoline"},
	"fan": {"scene": "res://objects/traps/fan/fan.tscn", "anchor": "floor", "group": "Traps", "name": "Fan"},
	"falling_platform": {"scene": "res://objects/traps/falling_platform/falling_platform.tscn", "anchor": "top", "group": "Traps", "name": "FallingPlatform", "measure": "body"},
	"moving_platform": {"scene": "res://objects/moving_platform/moving_platform.tscn", "anchor": "top", "group": "Traps", "name": "MovingPlatform", "measure": "body"},
	"fire_trap": {"scene": "res://objects/traps/fire_trap/fire_trap.tscn", "anchor": "floor", "group": "Traps", "name": "Fire"},
	"falling_spike": {"scene": "res://objects/enemies/falling_spike/falling_spike.tscn", "anchor": "ceiling", "group": "Traps", "name": "FallingSpike"},
	"spiked_ball": {"scene": "res://objects/traps/spiked_ball/spiked_ball.tscn", "anchor": "pivot", "group": "Traps", "name": "SpikedBall"},
	"orbit_saw": {"scene": "res://objects/enemies/orbit_saw/orbit_saw.tscn", "anchor": "center", "group": "Traps", "name": "OrbitSaw"},
	"saw": {"scene": "res://objects/enemies/saw/saw.tscn", "anchor": "center", "group": "Traps", "name": "Saw"},
	"crusher": {"scene": "res://objects/traps/crusher/crusher.tscn", "anchor": "ceiling", "group": "Traps", "name": "Crusher"},
	"arrow_left": {"scene": "res://objects/traps/arrow_shooter/arrow_shooter.tscn", "anchor": "wall_right", "group": "Traps", "name": "ArrowShooter"},
	"arrow_right": {"scene": "res://objects/traps/arrow_shooter/arrow_shooter.tscn", "anchor": "wall_left", "group": "Traps", "name": "ArrowShooter"},
	"cannon": {"scene": "res://objects/enemies/cannon/cannon.tscn", "anchor": "floor", "group": "Enemies", "name": "Cannon"},
	"opossum": {"scene": "res://objects/enemies/opossum/opossum.tscn", "anchor": "floor", "group": "Enemies", "name": "Opossum", "measure": "body"},
	"frog": {"scene": "res://objects/enemies/frog/frog.tscn", "anchor": "floor", "group": "Enemies", "name": "Frog", "measure": "body"},
	"eagle": {"scene": "res://objects/enemies/eagle/eagle.tscn", "anchor": "center", "group": "Enemies", "name": "Eagle", "measure": "body"},
	"pig": {"scene": "res://objects/enemies/pig/pig.tscn", "anchor": "floor", "group": "Enemies", "name": "Pig", "measure": "body"},
	"pig_ambusher": {"scene": "res://objects/enemies/pig/pig_ambusher.tscn", "anchor": "floor", "group": "Enemies", "name": "PigAmbusher", "measure": "body"},
	"pig_bomber": {"scene": "res://objects/enemies/pig_bomber/pig_bomber.tscn", "anchor": "floor", "group": "Enemies", "name": "PigBomber", "measure": "body"},
	"skeleton": {"scene": "res://objects/enemies/skeleton/skeleton.tscn", "anchor": "floor", "group": "Enemies", "name": "Skeleton", "measure": "body"},
	"ghost": {"scene": "res://objects/enemies/ghost/ghost.tscn", "anchor": "center", "group": "Enemies", "name": "Ghost", "measure": "body"},
	"hellhound": {"scene": "res://objects/enemies/hellhound/hellhound.tscn", "anchor": "floor", "group": "Enemies", "name": "Hellhound", "measure": "body"},
	"torch": {"scene": "res://objects/decor/torch/torch.tscn", "anchor": "center", "group": "Decor", "name": "Torch"},
	"dungeon_torch": {"scene": "res://objects/decor/dungeon_torch/dungeon_torch.tscn", "anchor": "floor", "group": "Decor", "name": "Brazier"},
	"candle": {"scene": "res://objects/decor/candle/candle.tscn", "anchor": "floor", "group": "Decor", "name": "Candle"},
	"crate": {"scene": "res://objects/decor/crate/crate.tscn", "anchor": "floor", "group": "Decor", "name": "Crate", "measure": "body"},
	"chest": {"scene": "res://objects/decor/chest/chest.tscn", "anchor": "floor", "group": "Decor", "name": "Chest"},
	"king_pig": {"scene": "res://objects/bosses/king_pig/king_pig.tscn", "anchor": "floor", "group": "Boss", "name": "KingPig", "measure": "body"},
	"ghost_warden": {"scene": "res://objects/bosses/ghost_warden/ghost_warden.tscn", "anchor": "center", "group": "Boss", "name": "GhostWarden", "measure": "body"},
	"npc": {"scene": "res://objects/npc/npc.tscn", "anchor": "floor", "group": "Village", "name": "NPC"},
	"portal": {"scene": "res://objects/portal/portal.tscn", "anchor": "floor", "group": "Village", "name": "Portal"},
	"hub_sign": {"scene": "res://objects/hub_sign/hub_sign.tscn", "anchor": "floor", "group": "Decor", "name": "HubSign"},
}

const DEFAULT_LEGEND := {
	"S": "start", "C": "checkpoint", "G": "goal",
	"^": "spikes", "v": "spikes_ceiling", "*": "fruit", "T": "trampoline", "F": "fan",
	"P": "falling_platform", "<": "arrow_left", ">": "arrow_right", "i": "fire_trap",
	"I": "falling_spike", "B": "spiked_ball", "O": "orbit_saw", "w": "saw", "X": "crusher",
	"c": "cannon", "o": "opossum", "g": "frog", "e": "eagle", "p": "pig",
	"a": "pig_ambusher", "b": "pig_bomber", "k": "skeleton", "h": "ghost", "H": "hellhound",
	"t": "torch", "d": "dungeon_torch", "n": "candle", "x": "crate", "$": "chest",
	"Z": "ability_gate", "W": "dash_wall",
}
## Đồ trang trí theo world (Sprite2D tĩnh). "wall" = treo trên tường nền, đáy ảnh = đáy ô;
## "hang" = treo từ trần, đỉnh ảnh = đỉnh ô; còn lại đứng trên đất.
const P := "res://shared/props/"
const WORLD_PROPS := {
	"forest": {
		"j": {"type": "prop:" + P + "forest/tree.png"},
		"l": {"type": "prop:" + P + "forest/pine.png"},
		"q": {"type": "prop:" + P + "forest/bush.png"},
		"r": {"type": "prop:" + P + "forest/rock.png"},
		"u": {"type": "prop:" + P + "forest/shrooms.png"},
		"y": {"type": "prop:" + P + "forest/rock_2.png"},
		"z": {"type": "prop:" + P + "forest/skulls.png"},
	},
	"castle": {
		"j": {"type": "prop:" + P + "castle/banner_red.png", "wall": true},
		"l": {"type": "prop:" + P + "castle/window_gold.png", "wall": true},
		"q": {"type": "prop:" + P + "castle/armor.png"},
		"r": {"type": "prop:" + P + "castle/column.png"},
		"u": {"type": "prop:" + P + "castle/window_light.png", "wall": true},
		"y": {"type": "prop:" + P + "castle/banner_grey.png", "wall": true},
		"z": {"type": "prop:" + P + "castle/window_gold_small.png", "wall": true},
	},
	"dungeon": {
		"j": {"type": "prop:" + P + "dungeon/dead_tree.png"},
		"l": {"type": "prop:" + P + "dungeon/window_green.png", "wall": true},
		"q": {"type": "prop:" + P + "dungeon/grave_1.png"},
		"r": {"type": "prop:" + P + "dungeon/column_broken.png"},
		"u": {"type": "prop:" + P + "dungeon/hanging_skeleton.png", "hang": true},
		"y": {"type": "prop:" + P + "dungeon/grave_bush.png"},
		"z": {"type": "prop:" + P + "dungeon/statue_broken.png"},
		"Q": {"type": "prop:" + P + "dungeon/grave_2.png"},
		"R": {"type": "prop:" + P + "dungeon/column.png"},
		"U": {"type": "prop:" + P + "dungeon/cross.png"},
	},
}
## Thứ tự nhóm = thứ tự vẽ. Decor đứng TRƯỚC Terrain để mép cỏ phủ lên gốc cây.
const GROUP_ORDER := ["Decor", "Terrain", "Secrets", "Traps", "Interactables", "Village", "Fruits", "Enemies", "Boss"]

# --- khai báo của từng màn (script con gán trong define()) ----------------------
var id: String = ""
var world: String = "forest"
var script_path: String = "res://levels/level_base.gd"
var backdrop: String = ""
var root_name: String = ""
var title: String = ""
var subtitle: String = ""
var map: PackedStringArray = []
## Cách vẽ thứ hai: danh sách "khúc" ghép ngang. Mỗi khúc là mảng dòng, CĂN ĐÁY (khúc
## thấp hơn được đệm dòng trống ở trên) và dòng ngắn được đệm "." bên phải — nên chỉ cần
## viết phần có nội dung. `walls` thêm 1 cột đất kín mỗi bên.
var chunks: Array = []
var walls: bool = true
var legend: Dictionary = {}
## Vùng tường nền khai báo bằng back(); rỗng = không có tường nền.
var _back_rects: Array = []
## Số hàng kéo dài hàng cuối của bản đồ xuống (đất liền thành khối, hố thành vực sâu).
var extrude: int = 10
var root_props: Dictionary = {}
## Vật đặt bằng code: [{"type", "cell": Vector2i, ...thuộc tính}]
var extras: Array = []
## Có cờ đích không (arena boss thì không).
var needs_goal: bool = true

func define() -> void:
	pass

## Hook cho màn cần node đặc biệt (boss...). `cell_pos(c)` = toạ độ px của ô.
func extra_nodes(_root: Node2D) -> void:
	pass

# --- trạng thái dựng ------------------------------------------------------------
var _w: int
var _h: int
var _grid: Array[PackedByteArray] = []  # 0 trống, 1 đất, 2 ván
var _groups: Dictionary = {}
var _counters: Dictionary = {}
var _fruit_i: int = 0
var _fp_cache: Dictionary = {}
var errors: PackedStringArray = []
var warnings: PackedStringArray = []
var _entities: Array = []
var _start_px: Vector2

static func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE, c.y * TILE)

func solid(x: int, y: int) -> bool:
	if x < 0 or x >= _w:
		return true  # mép trái/phải bản đồ coi như tường (camera cũng chặn ở đó)
	if y < 0:
		return false
	if y >= _h:
		return _grid[_h - 1][x] == 1
	return _grid[y][x] == 1

func plank(x: int, y: int) -> bool:
	return x >= 0 and x < _w and y >= 0 and y < _h and _grid[y][x] == 2

## Hàng cho phép trần thấp đúng 3 ô (hành lang cố ý) — mặc định không kiểm "trần 2 ô"
## ở những ô này. Màn khai báo bằng allow_low(x0, b0, x1, b1).
var _low_ok: Array = []

func allow_low(x0: int, b0: int, x1: int, b1: int) -> void:
	_low_ok.append([x0, b0, x1, b1])

func build() -> Node2D:
	define()
	_parse()
	_lint_tight()
	var root := Node2D.new()
	root.name = root_name if root_name != "" else id.to_pascal_case()
	root.set_script(load(script_path))
	var bottom := _h * TILE
	root.set("fall_death_y", float(bottom + 48))
	root.set("camera_limit_left", 0)
	root.set("camera_limit_right", _w * TILE)
	root.set("camera_limit_bottom", bottom)
	root.set("camera_limit_top", mini(0, bottom - 26 * TILE))
	root.set("world_title", title)
	root.set("level_subtitle", subtitle)
	for k: String in root_props:
		root.set(k, root_props[k])

	var bd: String = backdrop if backdrop != "" else String(BACKDROPS[world])
	var parallax: Node = (load("res://shared/backgrounds/%s_parallax.tscn" % bd) as PackedScene).instantiate()
	parallax.name = "Parallax"
	root.add_child(parallax)
	var ts: TileSet = load(TILESETS[world])
	if not _back_rects.is_empty():
		var back := TileMapLayer.new()
		back.name = "BackWall"
		back.tile_set = ts
		back.modulate = Color(0.62, 0.6, 0.68)
		root.add_child(back)
		_paint_backwall(back)
	for g: String in GROUP_ORDER:
		var n: Node2D
		if g == "Terrain":
			var tm := TileMapLayer.new()
			tm.tile_set = ts
			n = tm
			_paint_terrain(tm)
		else:
			n = Node2D.new()
		n.name = g
		root.add_child(n)
		_groups[g] = n

	for e: Dictionary in _entities:
		_place(e)
	for e: Dictionary in extras:
		var d: Dictionary = e.duplicate()
		d["from_extras"] = true
		if d.has("canvas"):
			var cv: Vector2i = d["canvas"]
			d["cell"] = Vector2i(cv.x + (1 if walls else 0), _cv_h - 1 - cv.y)
			d.erase("canvas")
		_place(d)

	var player: Node2D = (load(PLAYER) as PackedScene).instantiate()
	player.name = "Player"
	player.position = _start_px + Vector2(0, -PLAYER_FEET)
	root.add_child(player)
	var hud: Node = (load(HUD) as PackedScene).instantiate()
	hud.name = "HUD"
	root.add_child(hud)
	extra_nodes(root)

	# Nhóm rỗng thì bỏ cho scene gọn.
	for g: String in _groups:
		var n: Node = _groups[g]
		if g != "Interactables" and g != "Terrain" and n.get_child_count() == 0:
			root.remove_child(n)
			n.free()
	_check_counts()
	return root

# --- phân tích bản đồ ----------------------------------------------------------

# --- vẽ bằng lệnh (màn dọc) ---------------------------------------------------
# Toạ độ (x, b): x tính từ trái, b tính từ ĐÁY bản đồ lên (b = 0 là hàng dưới cùng) —
# khớp cách nghĩ "leo lên". Tường 2 bên do `walls` thêm, không tính trong x.
var _cv: Array = []
var _cv_h: int = 0

func canvas(w: int, h: int) -> void:
	_cv_h = h
	_cv = []
	for i in h:
		var line: Array = []
		line.resize(w)
		line.fill(".")
		_cv.append(line)

func rect(x0: int, b0: int, x1: int, b1: int, ch: String = "#") -> void:
	for b in range(mini(b0, b1), maxi(b0, b1) + 1):
		for x in range(mini(x0, x1), maxi(x0, x1) + 1):
			at(x, b, ch)

func at(x: int, b: int, ch: String) -> void:
	var y := _cv_h - 1 - b
	if y < 0 or y >= _cv_h or x < 0 or x >= (_cv[0] as Array).size():
		errors.append("vẽ ra ngoài canvas: (%d, b%d)" % [x, b])
		return
	_cv[y][x] = ch

## Đặt 1 vật có thuộc tính riêng tại ô canvas (x, b) — cho vật cần tham số khác nhau
## (bẫy lửa lệch pha, bệ trôi...) mà không phải tốn 1 ký hiệu legend cho mỗi cái.
func put(x: int, b: int, type: String, props: Dictionary = {}) -> void:
	var d := props.duplicate()
	d["type"] = type
	d["canvas"] = Vector2i(x, b)
	extras.append(d)

## Tường nền (không va chạm) cho phòng kín — chỉ tô lên ô trống.
func back(x0: int, b0: int, x1: int, b1: int) -> void:
	_back_rects.append([x0, b0, x1, b1])

## Viết một chuỗi ký hiệu bắt đầu từ ô (x0, b) sang phải; "." trong chuỗi = bỏ qua ô đó.
func text(x0: int, b: int, s: String) -> void:
	for i in s.length():
		if s[i] != ".":
			at(x0 + i, b, s[i])

func _hjoin() -> void:
	var h := 0
	for c: Array in chunks:
		h = maxi(h, c.size())
	var rows: Array[String] = []
	rows.resize(h)
	rows.fill("#" if walls else "")
	for c: Array in chunks:
		var cw := 0
		for line: String in c:
			cw = maxi(cw, line.length())
		var pad := h - c.size()
		for y in h:
			var line: String = c[y - pad] if y >= pad else ""
			rows[y] += line.rpad(cw, ".")
	for y in h:
		if walls:
			rows[y] += "#"
	map = PackedStringArray(rows)

func _parse() -> void:
	if map.is_empty() and not _cv.is_empty():
		var rows: PackedStringArray = []
		for line: Array in _cv:
			var r := "".join(PackedStringArray(line))
			rows.append(("#" + r + "#") if walls else r)
		map = rows
	elif map.is_empty() and not chunks.is_empty():
		_hjoin()
	_w = 0
	for row in map:
		_w = maxi(_w, row.length())
	var rows := map.size()
	_h = rows + extrude
	var full_legend := DEFAULT_LEGEND.duplicate()
	full_legend.merge(WORLD_PROPS.get(world, {}), true)
	full_legend.merge(legend, true)
	for y in rows:
		var row := map[y]
		var line := PackedByteArray()
		line.resize(_w)
		for x in _w:
			var ch := row[x] if x < row.length() else "."
			match ch:
				"#": line[x] = 1
				"=": line[x] = 2
				".", " ": line[x] = 0
				_:
					line[x] = 0
					if not full_legend.has(ch):
						errors.append("ký hiệu lạ '%s' ở ô (%d,%d)" % [ch, x, y])
						continue
					var spec = full_legend[ch]
					var d: Dictionary = {"type": spec} if spec is String else (spec as Dictionary).duplicate()
					d["cell"] = Vector2i(x, y)
					d["char"] = ch
					_entities.append(d)
		_grid.append(line)
	for i in extrude:
		var line := PackedByteArray()
		line.resize(_w)
		for x in _w:
			line[x] = 1 if _grid[rows - 1][x] == 1 else 0
		_grid.append(line)

# --- kiểm "chỗ kẹt" ----------------------------------------------------------------
# Thân người chơi 22x32 px = 1.4 x 2 ô. Khoảng trống đúng 2 ô cao / 2 ô rộng thì lọt được
# trên lý thuyết nhưng trong game là cụng góc, kẹt đầu — người chơi thấy như bị kẹt.
# Luật: (1) chỗ đứng nào cũng phải có >= 3 ô trống phía trên (ván một chiều không tính là
# trần vì nhảy xuyên được); (2) khe dọc (lỗ trên sàn/trần, khe giữa 2 khối) người chơi đi
# qua phải rộng >= 3 ô. Vi phạm = lỗi dựng, không xuất màn.

func _lint_tight() -> void:
	var off := 1 if walls else 0
	for y in _h:
		for x in _w:
			if _grid[y][x] != 0:
				continue
			var floor_below := y + 1 < _h and _grid[y + 1][x] != 0
			if floor_below:
				var head := 0
				while y - head >= 0 and _grid[y - head][x] != 1 and head < 3:
					head += 1
				if head < 3 and y - head >= 0 and not _is_low_ok(x - off, _h - 1 - y):
					errors.append("chỗ kẹt: ô (%d,%d) chỉ có %d ô trống phía trên (cần >= 3)" % [x, y, head])
	# Khe dọc: dải trống giữa 2 khối đặc trên cùng một hàng, rộng 1-2 ô, mà phía trên hoặc
	# dưới dải đó cũng trống (tức là người chơi phải chui xuyên qua nó theo chiều dọc).
	for y in range(1, _h - 1):
		var x := 0
		while x < _w:
			if _grid[y][x] == 1:
				x += 1
				continue
			var s0 := x
			while x < _w and _grid[y][x] != 1:
				x += 1
			var width := x - s0
			if width <= 2 and s0 > 0 and x < _w:
				var through := true
				for xx in range(s0, x):
					if _grid[y - 1][xx] == 1 and _grid[y + 1][xx] == 1:
						through = false
				var open_above := false
				var open_below := false
				for xx in range(s0, x):
					open_above = open_above or _grid[y - 1][xx] != 1
					open_below = open_below or _grid[y + 1][xx] != 1
				if through and open_above and open_below and y < _h - extrude - 1:
					errors.append("khe hẹp: hàng %d, cột %d..%d chỉ rộng %d ô (cần >= 3)" % [y, s0, x - 1, width])

	# (3) Góc cụng đầu: mép dưới của một gờ LƠ LỬNG (đất, bên dưới trống) nằm chéo phía trên
	# mép một chỗ đứng — cách 1..3 hàng, lệch 1..2 cột. Nhảy từ chỗ đứng lên gờ đó là cụng
	# góc (ảnh "gờ so le sát mép nhau" trong tháp canh). Chỉ xét mép của chỗ đứng (ô kế
	# bên về phía gờ là khoảng trống) để không bắt nhầm lối vào hành lang.
	for y in range(1, _h):
		for x in _w:
			if _grid[y][x] != 0 or y + 1 >= _h or _grid[y + 1][x] == 0:
				continue  # không phải chỗ đứng
			for dir: int in [-1, 1]:
				var nx := x + dir
				if nx < 0 or nx >= _w or _grid[y][nx] != 0 or _grid[y + 1][nx] != 0:
					continue  # không phải mép hướng ra khoảng trống
				for dx: int in [1, 2]:
					var ox := x + dir * dx
					if ox < 0 or ox >= _w:
						continue
					for dy: int in [1, 2, 3]:
						var oy := y - dy
						if oy < 1:
							continue
						# ô gờ: đất, bên dưới trống (gờ lơ lửng), và cột ngay trên chỗ đứng trống
						if _grid[oy][ox] == 1 and _grid[oy + 1][ox] == 0 and _grid[oy][x] != 1 \
								and not _is_low_ok(x - off, _h - 1 - y):
							errors.append("góc cụng đầu: chỗ đứng (%d,%d) sát mép gờ (%d,%d) — lệch %d cột, cao %d hàng" % [x, y, ox, oy, dx, dy + 1])

func _is_low_ok(cx: int, b: int) -> bool:
	for r: Array in _low_ok:
		if cx >= r[0] and cx <= r[2] and b >= r[1] and b <= r[3]:
			return true
	return false

# --- tô tile ---------------------------------------------------------------------

func _paint_terrain(tm: TileMapLayer) -> void:
	for y in _h:
		for x in _w:
			var v := _grid[y][x]
			if v == 1:
				var mask := 0
				if solid(x, y - 1): mask |= 1
				if solid(x + 1, y): mask |= 2
				if solid(x, y + 1): mask |= 4
				if solid(x - 1, y): mask |= 8
				tm.set_cell(Vector2i(x, y), 0, Vector2i(mask, (x & 1) + 2 * (y & 1)))
			elif v == 2:
				var l := plank(x - 1, y) or solid(x - 1, y)
				var r := plank(x + 1, y) or solid(x + 1, y)
				var kind := 2 if (l and r) else (3 if l else (1 if r else 0))
				tm.set_cell(Vector2i(x, y), 0, Vector2i(kind + 4 * (x & 1), 4))

## Tường nền: chỉ trong các vùng back() đã khai báo (toạ độ canvas → cộng cột tường).
func _paint_backwall(tm: TileMapLayer) -> void:
	var off := 1 if walls else 0
	for r: Array in _back_rects:
		for b in range(r[1], r[3] + 1):
			var y := _cv_h - 1 - b
			for xx in range(r[0], r[2] + 1):
				var x: int = xx + off
				if y >= 0 and y < _h and x >= 0 and x < _w and _grid[y][x] != 1:
					tm.set_cell(Vector2i(x, y), 0, Vector2i((x & 1) + 2 * (y & 1), 5))

# --- đặt vật ---------------------------------------------------------------------

func _place(e: Dictionary) -> void:
	var type: String = e["type"]
	var c: Vector2i = e["cell"]
	if type.begins_with("prop:"):
		_place_prop(e)
		return
	if not TYPES.has(type):
		errors.append("type lạ '%s' ở %s" % [type, c])
		return
	var t: Dictionary = TYPES[type]
	var inst: Node2D = (load(t["scene"]) as PackedScene).instantiate()
	var rot: float = t.get("rotation", 0.0)
	inst.rotation = rot
	var fp := _footprint(t["scene"], inst, t.get("measure", ""), rot)
	var anchor: String = t["anchor"]
	var pos := Vector2.ZERO
	var cx := c.x * TILE + TILE / 2.0
	match anchor:
		"floor":
			pos = Vector2(cx - fp.get_center().x, (c.y + 1) * TILE - fp.end.y)
			if not (solid(c.x, c.y + 1) or plank(c.x, c.y + 1)):
				errors.append("%s '%s' ở %s không có đất bên dưới" % [type, e.get("char", ""), c])
		"ceiling":
			pos = Vector2(cx - fp.get_center().x, c.y * TILE - fp.position.y)
			if not solid(c.x, c.y - 1) and not e.get("free", false):
				errors.append("%s ở %s không có trần phía trên" % [type, c])
		"top":
			pos = Vector2(cx - fp.get_center().x, c.y * TILE - fp.position.y)
		"center":
			pos = Vector2(cx, c.y * TILE + TILE / 2.0) - fp.get_center()
		"pivot":
			pos = Vector2(cx, c.y * TILE)
			if not solid(c.x, c.y - 1):
				errors.append("%s ở %s không có trần để treo" % [type, c])
		"wall_right":
			pos = Vector2((c.x + 1) * TILE, c.y * TILE + TILE / 2.0)
			inst.set("direction", Vector2.LEFT)
			if not solid(c.x + 1, c.y):
				errors.append("%s ở %s không có tường bên phải" % [type, c])
		"wall_left":
			pos = Vector2(c.x * TILE, c.y * TILE + TILE / 2.0)
			inst.set("direction", Vector2.RIGHT)
			if not solid(c.x - 1, c.y):
				errors.append("%s ở %s không có tường bên trái" % [type, c])
	if solid(c.x, c.y):
		errors.append("%s ở %s nằm trong đất" % [type, c])
	pos += Vector2(e.get("dx", 0.0), e.get("dy", 0.0))
	inst.position = pos
	if type == "fruit" and not e.has("variant_frames"):
		inst.set("variant_frames", load(FRUITS[_fruit_i % FRUITS.size()]))
		_fruit_i += 1
	for k: String in e:
		if k in ["type", "cell", "char", "dx", "dy", "free", "from_extras", "name"]:
			continue
		var v = e[k]
		if v is String and (v as String).begins_with("res://") and k != "target_scene":
			v = load(v)
		inst.set(k, v)
	inst.name = e.get("name", _next_name(t["name"], type in ["start", "goal"]))
	(_groups[t["group"]] as Node).add_child(inst)
	if type == "start":
		_start_px = Vector2(cx, (c.y + 1) * TILE)
	var rec := {"type": type, "x": c.x, "y": c.y}
	for k in ["move_distance", "radius", "chain_length", "bounce_velocity", "secret_id"]:
		if e.has(k):
			rec[k] = e[k] if not (e[k] is Vector2) else [e[k].x, e[k].y]
	_entities_out.append(rec)

var _entities_out: Array = []

## Đồ trang trí tĩnh: Sprite2D thường, đáy ảnh chạm mặt đất ô đó (hoặc treo nếu "hang").
func _place_prop(e: Dictionary) -> void:
	var path: String = String(e["type"]).substr(5)
	var c: Vector2i = e["cell"]
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	var size := s.texture.get_size()
	var sc: float = e.get("scale", 1.0)
	s.scale = Vector2(sc, sc)
	var cx := c.x * TILE + TILE / 2.0
	if e.get("hang", false):
		s.position = Vector2(cx - size.x * sc / 2.0, c.y * TILE)
	elif e.get("wall", false):
		s.position = Vector2(cx - size.x * sc / 2.0, (c.y + 1) * TILE - size.y * sc)
	else:
		s.position = Vector2(cx - size.x * sc / 2.0, (c.y + 1) * TILE - size.y * sc + e.get("sink", 2.0))
		if not (solid(c.x, c.y + 1) or plank(c.x, c.y + 1)):
			errors.append("trang trí %s ở %s không có đất bên dưới" % [path.get_file(), c])
	s.position += Vector2(e.get("dx", 0.0), e.get("dy", 0.0))
	s.flip_h = e.get("flip", false)
	if e.has("modulate"):
		s.modulate = e["modulate"]
	if e.get("front", false):
		s.z_index = 2
	s.name = e.get("name", _next_name(path.get_file().get_basename().to_pascal_case(), false))
	(_groups["Decor"] as Node).add_child(s)

func _next_name(prefix: String, single: bool) -> String:
	if single:
		return prefix
	var n: int = _counters.get(prefix, 0) + 1
	_counters[prefix] = n
	return "%s%d" % [prefix, n]

## Khung (Rect2, toạ độ của gốc scene) dùng để neo.
func _footprint(scene_path: String, inst: Node2D, measure: String, rot: float) -> Rect2:
	var key := "%s|%s|%f" % [scene_path, measure, rot]
	if _fp_cache.has(key):
		return _fp_cache[key]
	var r := Rect2()
	var have := false
	if measure != "body":
		for c in inst.get_children():
			var rr := _visual_rect(c)
			if rr.size != Vector2.ZERO:
				r = rr if not have else r.merge(rr)
				have = true
	if not have:
		for c in inst.get_children():
			if c is CollisionShape2D and c.shape:
				var rr: Rect2 = (c as CollisionShape2D).transform * (c.shape as Shape2D).get_rect()
				r = rr if not have else r.merge(rr)
				have = true
	if not have:
		r = Rect2(-8, -8, 16, 16)
	r = Transform2D(rot, Vector2.ZERO) * r
	_fp_cache[key] = r
	return r

static func _visual_rect(c: Node) -> Rect2:
	if not (c is CanvasItem) or not (c as CanvasItem).visible:
		return Rect2()
	if c is AnimatedSprite2D and c.sprite_frames:
		var s := c as AnimatedSprite2D
		var anim := s.animation
		if not s.sprite_frames.has_animation(anim):
			anim = s.sprite_frames.get_animation_names()[0]
		return _tex_rect(s, s.sprite_frames.get_frame_texture(anim, 0), s.centered, s.offset)
	if c is Sprite2D and c.texture:
		var s := c as Sprite2D
		if s.hframes > 1 or s.vframes > 1 or s.region_enabled:
			return Rect2()
		return _tex_rect(s, s.texture, s.centered, s.offset)
	if c is Polygon2D:
		var p := c as Polygon2D
		if p.polygon.is_empty():
			return Rect2()
		var rr := Rect2(p.polygon[0], Vector2.ZERO)
		for v in p.polygon:
			rr = rr.expand(v)
		return p.transform * rr
	return Rect2()

static func _tex_rect(n: Node2D, tex: Texture2D, centered: bool, offset: Vector2) -> Rect2:
	var img := tex.get_image()
	if img == null:
		return Rect2()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	var size := Vector2(img.get_size())
	var origin := offset - (size / 2.0 if centered else Vector2.ZERO)
	return n.transform * Rect2(origin + Vector2(used.position), Vector2(used.size))

func _check_counts() -> void:
	var counts := {}
	for e: Dictionary in _entities_out:
		counts[e["type"]] = counts.get(e["type"], 0) + 1
	if counts.get("start", 0) != 1:
		errors.append("cần đúng 1 điểm xuất phát S (đang có %d)" % counts.get("start", 0))
	if needs_goal and counts.get("goal", 0) != 1:
		errors.append("cần đúng 1 cờ đích G (đang có %d)" % counts.get("goal", 0))

## Dữ liệu cho validator / xem trước: lưới + vật thể.
func to_json() -> Dictionary:
	var rows: PackedStringArray = []
	for y in _h:
		var s := ""
		for x in _w:
			s += ["." , "#", "="][_grid[y][x]]
		rows.append(s)
	return {"id": id, "world": world, "w": _w, "h": _h, "rows": rows, "entities": _entities_out}
