extends SceneTree
## Dựng scene của quái / bẫy mới bằng code rồi lưu thành .tscn + SpriteFrames .tres.
## (Quy ước dự án: KHÔNG dựng SpriteFrames lúc chạy game — ở đây dựng 1 lần, lưu ra file.)
##   Godot --headless --path . -s res://tools/level_builder/build_objects.gd
## Gốc toạ độ của mọi quái mặt đất = điểm giữa bàn chân (sprite được dời để đáy phần có
## màu chạm y=0), nên bộ dựng màn đặt chúng lên mặt đất không cần số bù tay.

const CRITTER := "res://objects/enemies/critter/critter.gd"
const FLYING := "res://objects/enemies/flying/flying_enemy.gd"
const HEALTH := "res://components/health_component.gd"
const HURTBOX := "res://components/hurtbox.gd"
const HITBOX := "res://components/hitbox.gd"
const REACTION := "res://components/enemy_hit_reaction.gd"
const STOMP := "res://components/stomp_box.gd"

func _initialize() -> void:
	_opossum()
	_frog()
	_eagle()
	_skeleton()
	_ghost()
	_hellhound()
	_crusher()
	_dash_wall()
	_soul_orb()
	_ghost_warden()
	quit()

# --- SpriteFrames ------------------------------------------------------------

## anims: [[name, strip_path, frame_count, fps, loop, (chỉ số khung dùng)], ...] — mỗi strip
## là 1 hàng ngang `frame_count` khung; phần tử thứ 6 (tuỳ chọn) chọn khung con, vd [0].
static func _frames(anims: Array, out_path: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for a: Array in anims:
		var tex: Texture2D = load(a[1])
		var count: int = a[2]
		var w := tex.get_width() / count
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[3])
		sf.set_animation_loop(a[0], a[4])
		var picks: Array = a[5] if a.size() > 5 else range(count)
		for i: int in picks:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * w, 0, w, tex.get_height())
			sf.add_frame(a[0], at)
	ResourceSaver.save(sf, out_path)
	return load(out_path)

## Đáy phần có màu (px tính từ mép trên frame) lớn nhất qua mọi frame của strip.
static func _opaque_bottom(strip: String, count: int) -> int:
	var img := Image.load_from_file(ProjectSettings.globalize_path(strip))
	var w := img.get_width() / count
	var bottom := 0
	for i in count:
		var r := img.get_region(Rect2i(i * w, 0, w, img.get_height())).get_used_rect()
		bottom = maxi(bottom, r.end.y)
	return bottom

# --- node helpers ------------------------------------------------------------

static func _rect(parent: Node, name: String, size: Vector2, pos: Vector2, disabled := false) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	cs.name = name
	var sh := RectangleShape2D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.disabled = disabled
	parent.add_child(cs)
	return cs

static func _area(parent: Node, name: String, script: String, layer: int, mask: int) -> Area2D:
	var a := Area2D.new()
	a.name = name
	if script != "":
		a.set_script(load(script))
	a.collision_layer = layer
	a.collision_mask = mask
	parent.add_child(a)
	return a

static func _sprite(root: Node, sf: SpriteFrames, anim: StringName, feet_offset_y: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.name = "AnimatedSprite2D"
	s.sprite_frames = sf
	s.animation = anim
	s.autoplay = String(anim)
	s.offset = Vector2(0, feet_offset_y)
	root.add_child(s)
	return s

## Khung chung cho quái có máu: HealthComponent + Hurtbox + Hitbox chạm-là-đau + phản ứng.
## body/hurt/hit: [size, center]. stomp: [size, center] hoặc [] nếu không đạp được.
static func _combat(root: Node, hp: int, hurt: Array, hit: Array, stomp: Array) -> void:
	var h := Node.new()
	h.name = "HealthComponent"
	h.set_script(load(HEALTH))
	h.set("max_hp", hp)
	root.add_child(h)
	var hb := _area(root, "Hurtbox", HURTBOX, 16, 32)
	_rect(hb, "CollisionShape2D", hurt[0], hurt[1])
	var hx := _area(root, "Hitbox", HITBOX, 64, 0)
	_rect(hx, "CollisionShape2D", hit[0], hit[1])
	if not stomp.is_empty():
		var st := _area(root, "StompBox", STOMP, 0, 2)
		_rect(st, "CollisionShape2D", stomp[0], stomp[1])
	var r := Node.new()
	r.name = "HitReaction"
	r.set_script(load(REACTION))
	root.add_child(r)

static func _save(root: Node, path: String) -> void:
	_own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err == OK:
		err = ResourceSaver.save(ps, path)
	print("wrote %s err=%d" % [path, err])
	root.free()

static func _own(root: Node, n: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(root, c)

static func _ground_body(name: String, script: String, body: Vector2) -> CharacterBody2D:
	var root := CharacterBody2D.new()
	root.name = name
	root.set_script(load(script))
	root.collision_layer = 4
	root.collision_mask = 1
	root.add_to_group("enemy", true)
	_rect(root, "CollisionShape2D", body, Vector2(0, -body.y / 2.0))
	var ray := RayCast2D.new()
	ray.name = "FloorCheck"
	ray.position = Vector2(body.x / 2.0 + 2.0, -4.0)
	ray.target_position = Vector2(0, 14)
	root.add_child(ray)
	return root

# --- Rừng ----------------------------------------------------------------------

func _opossum() -> void:
	var dir := "res://objects/enemies/opossum/"
	var strip := dir + "sprites/opossum_run.png"
	var sf := _frames([["run", strip, 6, 10.0, true], ["idle", strip, 6, 1.0, true, [0]]], dir + "sprites/opossum_frames.tres")
	var root := _ground_body("Opossum", CRITTER, Vector2(20, 13))
	root.set("mode", 0)
	root.set("speed", 42.0)
	root.set("patrol_distance", 64.0)
	_sprite(root, sf, &"run", 14.0 - _opaque_bottom(strip, 6))
	_combat(root, 1, [Vector2(24, 16), Vector2(0, -8)], [Vector2(18, 9), Vector2(0, -5)], [Vector2(22, 6), Vector2(0, -16)])
	_save(root, dir + "opossum.tscn")

func _frog() -> void:
	var dir := "res://objects/enemies/frog/"
	var idle := dir + "sprites/frog_idle.png"
	var jump := dir + "sprites/frog_jump.png"
	var sf := _frames([["idle", idle, 4, 6.0, true], ["jump", jump, 2, 1.0, false, [0]], ["fall", jump, 2, 1.0, false, [1]]], dir + "sprites/frog_frames.tres")
	var root := _ground_body("Frog", CRITTER, Vector2(18, 14))
	root.set("mode", 1)
	root.set("hop_velocity", Vector2(75, -260))
	root.set("hop_interval", 1.4)
	root.set("detect_range", 120.0)
	_sprite(root, sf, &"idle", 16.0 - _opaque_bottom(idle, 4))
	_combat(root, 1, [Vector2(22, 16), Vector2(0, -8)], [Vector2(16, 10), Vector2(0, -5)], [Vector2(20, 6), Vector2(0, -17)])
	_save(root, dir + "frog.tscn")

func _eagle() -> void:
	var dir := "res://objects/enemies/eagle/"
	var sf := _frames([["fly", dir + "sprites/eagle_fly.png", 4, 10.0, true]], dir + "sprites/eagle_frames.tres")
	var root := CharacterBody2D.new()
	root.name = "Eagle"
	root.set_script(load(FLYING))
	root.collision_layer = 4
	root.collision_mask = 1
	root.add_to_group("enemy", true)
	root.set("kind", 0)
	_rect(root, "CollisionShape2D", Vector2(18, 16), Vector2.ZERO)
	_sprite(root, sf, &"fly", 0.0)
	_combat(root, 1, [Vector2(26, 22), Vector2.ZERO], [Vector2(18, 14), Vector2(0, 2)], [Vector2(22, 6), Vector2(0, -12)])
	_save(root, dir + "eagle.tscn")

# --- Hầm Ngục ----------------------------------------------------------------

func _skeleton() -> void:
	var dir := "res://objects/enemies/skeleton/"
	var walk := dir + "sprites/skeleton_walk.png"
	var rise := dir + "sprites/skeleton_rise.png"
	var sf := _frames([["run", walk, 8, 9.0, true], ["idle", walk, 8, 1.0, true, [0]], ["rise", rise, 6, 9.0, false]], dir + "sprites/skeleton_frames.tres")
	var root := _ground_body("Skeleton", CRITTER, Vector2(14, 34))
	root.set("mode", 2)
	root.set("speed", 30.0)
	root.set("chase", true)
	root.set("chase_speed", 52.0)
	root.set("patrol_distance", 48.0)
	root.set("detect_range", 90.0)
	_sprite(root, sf, &"idle", 26.0 - _opaque_bottom(walk, 8))
	_combat(root, 2, [Vector2(18, 36), Vector2(0, -18)], [Vector2(12, 28), Vector2(0, -14)], [Vector2(18, 6), Vector2(0, -38)])
	_save(root, dir + "skeleton.tscn")

func _ghost() -> void:
	var dir := "res://objects/enemies/ghost/"
	var sf := _frames([["fly", dir + "sprites/ghost_float.png", 4, 6.0, true]], dir + "sprites/ghost_frames.tres")
	var root := CharacterBody2D.new()
	root.name = "Ghost"
	root.set_script(load(FLYING))
	root.collision_layer = 4
	root.collision_mask = 0
	root.add_to_group("enemy", true)
	root.set("kind", 1)
	root.set("speed", 34.0)
	root.set("patrol_distance", 40.0)
	root.set("detect_range", 150.0)
	root.set("sprite_faces_right", true)
	_rect(root, "CollisionShape2D", Vector2(16, 30), Vector2.ZERO)
	var s := _sprite(root, sf, &"fly", 0.0)
	s.modulate = Color(1, 1, 1, 0.92)
	_combat(root, 2, [Vector2(22, 40), Vector2(0, 0)], [Vector2(16, 32), Vector2(0, 2)], [])
	_save(root, dir + "ghost.tscn")

func _hellhound() -> void:
	var dir := "res://objects/enemies/hellhound/"
	var strip := dir + "sprites/hellhound_run.png"
	var sf := _frames([["run", strip, 4, 12.0, true], ["idle", strip, 4, 1.0, true, [0]]], dir + "sprites/hellhound_frames.tres")
	var root := _ground_body("Hellhound", CRITTER, Vector2(34, 20))
	root.set("mode", 3)
	root.set("speed", 40.0)
	root.set("detect_range", 170.0)
	root.set("charge_speed", 240.0)
	var s := _sprite(root, sf, &"idle", 0.0)
	s.scale = Vector2(0.75, 0.75)
	s.offset = Vector2(0, 26.5 - _opaque_bottom(strip, 4))
	_combat(root, 3, [Vector2(40, 24), Vector2(0, -12)], [Vector2(36, 16), Vector2(0, -8)], [Vector2(30, 6), Vector2(0, -26)])
	_save(root, dir + "hellhound.tscn")

# --- Lâu Đài: bẫy ----------------------------------------------------------------

func _crusher() -> void:
	var dir := "res://objects/traps/crusher/"
	var sf := _frames([
		["idle", dir + "sprites/idle.png", 1, 1.0, true],
		["blink", dir + "sprites/blink.png", 4, 12.0, true],
		["slam", dir + "sprites/bottom_hit.png", 4, 12.0, false],
	], dir + "sprites/crusher_frames.tres")
	var root := Area2D.new()
	root.name = "Crusher"
	root.set_script(load(dir + "crusher.gd"))
	root.collision_layer = 64
	root.collision_mask = 0
	_sprite(root, sf, &"idle", 0.0)
	_rect(root, "CollisionShape2D", Vector2(34, 36), Vector2(0, 2), true)
	_save(root, dir + "crusher.tscn")

# --- Tường nứt (cổng Dash) ---------------------------------------------------------

func _dash_wall() -> void:
	var dir := "res://objects/dash_wall/"
	var root := StaticBody2D.new()
	root.name = "DashWall"
	root.set_script(load(dir + "dash_wall.gd"))
	root.collision_layer = 1
	root.collision_mask = 0
	_rect(root, "CollisionShape2D", Vector2(16, 48), Vector2(0, -24))
	var blocks := Node2D.new()
	blocks.name = "Blocks"
	root.add_child(blocks)
	var tex: Texture2D = load(dir + "sprites/block.png")
	for i in 3:
		var sp := Sprite2D.new()
		sp.name = "Block%d" % (i + 1)
		sp.texture = tex
		sp.scale = Vector2(16.0 / 22.0, 16.0 / 22.0)
		sp.position = Vector2(0, -8 - 16 * i)
		blocks.add_child(sp)
	var det := _area(root, "Detector", "", 0, 2)
	_rect(det, "CollisionShape2D", Vector2(22, 44), Vector2(0, -24))
	_save(root, dir + "dash_wall.tscn")

# --- Trùm cuối: Hồn Ma Cai Ngục ----------------------------------------------------

func _ghost_warden() -> void:
	var dir := "res://objects/bosses/ghost_warden/"
	var sf: SpriteFrames = load("res://objects/enemies/ghost/sprites/ghost_frames.tres")
	var root := CharacterBody2D.new()
	root.name = "GhostWarden"
	root.set_script(load(dir + "ghost_warden.gd"))
	root.collision_layer = 4
	root.collision_mask = 0
	root.add_to_group("enemy", true)
	root.add_to_group("boss", true)
	_rect(root, "CollisionShape2D", Vector2(24, 50), Vector2.ZERO)
	var s := _sprite(root, sf, &"fly", 0.0)
	s.scale = Vector2(1.5, 1.5)
	var h := Node.new()
	h.name = "HealthComponent"
	h.set_script(load(HEALTH))
	h.set("max_hp", 16)
	h.set("invincibility_duration", 0.9)
	root.add_child(h)
	var hb := _area(root, "Hurtbox", HURTBOX, 16, 32)
	_rect(hb, "CollisionShape2D", Vector2(34, 66), Vector2(0, 2))
	var hx := _area(root, "Hitbox", HITBOX, 64, 0)
	_rect(hx, "CollisionShape2D", Vector2(24, 54), Vector2(0, 4))
	var sw := _area(root, "Swipe", HITBOX, 64, 0)
	_rect(sw, "CollisionShape2D", Vector2(44, 44), Vector2(0, 6), true)
	_save(root, dir + "ghost_warden.tscn")

func _soul_orb() -> void:
	var dir := "res://objects/bosses/ghost_warden/"
	var root := Area2D.new()
	root.name = "SoulOrb"
	root.set_script(load(dir + "soul_orb.gd"))
	root.collision_layer = 64
	root.collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var c := CircleShape2D.new()
	c.radius = 6.0
	cs.shape = c
	root.add_child(cs)
	var orb := Node2D.new()
	orb.name = "Orb"
	root.add_child(orb)
	orb.add_child(_circle("Glow", 9.0, Color(0.55, 0.25, 0.9, 0.45)))
	orb.add_child(_circle("Core", 6.0, Color(0.75, 0.5, 1.0, 1.0)))
	orb.add_child(_circle("Heart", 2.5, Color(1, 0.95, 1, 1)))
	var mark := Polygon2D.new()
	mark.name = "Mark"
	mark.color = Color(1.0, 0.25, 0.35, 0.9)
	mark.polygon = PackedVector2Array([Vector2(-9, 0), Vector2(-5, -2), Vector2(5, -2), Vector2(9, 0), Vector2(5, 2), Vector2(-5, 2)])
	root.add_child(mark)
	_save(root, dir + "soul_orb.tscn")

static func _circle(name: String, r: float, col: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = name
	p.color = col
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(Vector2.from_angle(TAU * i / 12.0) * r)
	p.polygon = pts
	return p
