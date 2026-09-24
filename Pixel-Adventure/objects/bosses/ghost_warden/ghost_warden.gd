extends CharacterBody2D
## TRÙM CUỐI · HỒN MA CAI NGỤC. Khác hẳn Vua Heo (trùm mặt đất húc/dậm/ném bom): đây là
## trùm BAY, xuyên tường, người chơi phải canh lúc nó hạ thấp mới chém tới.
## Không kế thừa BossBase (FSM di chuyển khác hoàn toàn) nhưng phát đúng các signal
## Events.boss_* nên thanh máu, tiến trình, thành tựu vẫn chạy như trùm cũ.
##
## Đòn (mở dần theo phase — ≤66% và ≤33% máu):
##   swoop  — bay lên một góc, loé đỏ báo hiệu, lao chéo xuống chỗ người chơi rồi LƠ
##            LỬNG THẤP một nhịp (lúc chém ăn nhất)
##   summon — gọi 2 bộ xương trồi lên ở hai đầu phòng (tối đa 2 con cùng lúc)
##   rain   — (phase 2+) bay lên giữa trần, thả chuỗi quả cầu hồn; mỗi quả có vệt báo
##            trước trên sàn
##   blink  — (phase 3) tan biến, hiện ra sau lưng người chơi rồi quét lồng đèn
## Không có coroutine dài: mỗi đòn là chuỗi bước theo `_step` + `_t` để pause/chết giữa
## chừng không vỡ.

const SKELETON := preload("res://objects/enemies/skeleton/skeleton.tscn")
const ORB := preload("res://objects/bosses/ghost_warden/soul_orb.tscn")

@export var boss_id: String = "dungeon_boss"
@export var display_name: String = "CAI NGỤC"
## Vùng bay (px, toạ độ global): x = trái, y = trần bay, end.y = mặt sàn.
@export var arena: Rect2 = Rect2(40, 60, 560, 250)
@export var intro_time: float = 1.4

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var _swipe: Hitbox = $Swipe

var _pattern: String = "intro"
var _step: int = 0
var _t: float = 0.0
var _phase: int = 1
var _target: Vector2
var _dir: Vector2
var _facing: int = -1
var _bob: float = 0.0
var _minions: Array[Node] = []
var _orbs_left: int = 0
var _last: String = ""
var _dead: bool = false

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_t = intro_time
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	health.health_changed.connect(func(c: int, m: int) -> void: Events.boss_health_changed.emit(c, m))
	Events.boss_intro.emit.call_deferred(boss_id, display_name)
	Events.boss_health_changed.emit.call_deferred(health.hp, health.max_hp)
	_swipe.disable()
	sprite.play(&"fly")
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, intro_time)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t -= delta
	_bob += delta
	var p := _player()
	if p and _pattern != "swoop":
		_facing = -1 if p.global_position.x < global_position.x else 1
	sprite.flip_h = _facing < 0
	match _pattern:
		"intro":
			if _t <= 0.0:
				_think()
		"think":
			_float_to(Vector2(clampf(p.global_position.x if p else arena.get_center().x, arena.position.x + 40, arena.end.x - 40), _hover_y()), 70.0, delta)
			if _check_phase():
				return
			if _t <= 0.0:
				_start(_pick())
		"roar":
			sprite.position.x = sin(_t * 70.0) * 2.0
			if _t <= 0.0:
				sprite.position.x = 0.0
				_think()
		"swoop": _run_swoop(delta, p)
		"summon": _run_summon(delta)
		"rain": _run_rain(delta, p)
		"blink": _run_blink(delta, p)

# --- chọn đòn ------------------------------------------------------------------------

func _think() -> void:
	_pattern = "think"
	_t = [1.2, 0.9, 0.65][_phase - 1]

func _pick() -> String:
	var alive: Array[Node] = []
	for m in _minions:
		if is_instance_valid(m):
			alive.append(m)
	_minions = alive
	var pool: Array[String] = ["swoop", "swoop"]
	if _minions.size() < 2 and _last != "summon":
		pool.append("summon")
	if _phase >= 2:
		pool.append_array(["rain", "swoop"])
	if _phase >= 3:
		pool.append_array(["blink", "blink"])
	# Tránh lặp lại đúng đòn vừa đánh (trừ khi chỉ còn đòn đó).
	var fresh := pool.filter(func(x: String) -> bool: return x != _last)
	return (fresh if not fresh.is_empty() else pool).pick_random()

func _start(p: String) -> void:
	_pattern = p
	_last = p
	_step = 0
	_t = 0.0

func _check_phase() -> bool:
	var pct := float(health.hp) / float(health.max_hp)
	var want := 3 if pct <= 0.33 else (2 if pct <= 0.66 else 1)
	if want == _phase:
		return false
	_phase = want
	Events.boss_phase_changed.emit(_phase)
	health.grant_invincibility()
	_flash(Color(2.5, 0.6, 2.5))
	_pattern = "roar"
	_t = 0.9
	return true

# --- swoop ---------------------------------------------------------------------------

func _run_swoop(delta: float, p: Node2D) -> void:
	match _step:
		0:  # bay lên góc xa người chơi
			var side := arena.position.x + 30.0 if (p and p.global_position.x > arena.get_center().x) else arena.end.x - 30.0
			_target = Vector2(side, arena.position.y + 10.0)
			_step = 1
		1:
			if _float_to(_target, 230.0, delta):
				_step = 2
				_t = [0.55, 0.45, 0.35][_phase - 1]
				sprite.modulate = Color(2.2, 0.7, 0.7)
		2:  # loé đỏ báo hiệu
			if _t <= 0.0:
				sprite.modulate = Color.WHITE
				var aim := (p.global_position + Vector2(0, -8)) if p else arena.get_center()
				_dir = (aim - global_position).normalized()
				_facing = -1 if _dir.x < 0.0 else 1
				_step = 3
				_t = 1.6
		3:  # lao
			global_position += _dir * [250.0, 290.0, 330.0][_phase - 1] * delta
			if _t <= 0.0 or global_position.y >= arena.end.y - 22.0 \
					or global_position.x < arena.position.x or global_position.x > arena.end.x:
				global_position.x = clampf(global_position.x, arena.position.x, arena.end.x)
				global_position.y = minf(global_position.y, arena.end.y - 22.0)
				_step = 4
				_t = [1.1, 0.9, 0.7][_phase - 1]
		4:  # lơ lửng thấp — sơ hở
			global_position.y += sin(_bob * 3.0) * 0.2
			if _t <= 0.0:
				_think()

# --- summon --------------------------------------------------------------------------

func _run_summon(delta: float) -> void:
	match _step:
		0:
			_float_to(Vector2(arena.get_center().x, _hover_y() - 20.0), 120.0, delta)
			sprite.modulate = Color(0.7, 1.6, 1.0)
			_t = 0.8
			_step = 1
		1:
			if _t <= 0.0:
				sprite.modulate = Color.WHITE
				for x in [arena.position.x + 30.0, arena.end.x - 30.0]:
					var s := SKELETON.instantiate()
					s.set("detect_range", 999.0)
					s.set("chase_speed", 46.0 + 8.0 * _phase)
					# Gán vị trí TRƯỚC add_child để _ready của bộ xương lấy đúng điểm gốc.
					s.position = get_parent().to_local(Vector2(x, arena.end.y))
					get_parent().add_child(s)
					_minions.append(s)
				_t = 0.6
				_step = 2
		2:
			if _t <= 0.0:
				_think()

# --- rain ----------------------------------------------------------------------------

func _run_rain(delta: float, p: Node2D) -> void:
	match _step:
		0:
			if _float_to(Vector2(arena.get_center().x, arena.position.y), 200.0, delta):
				_orbs_left = 5 if _phase == 2 else 7
				_t = 0.2
				_step = 1
		1:
			if _t <= 0.0:
				var x := clampf((p.global_position.x if p else arena.get_center().x) + randf_range(-40.0, 40.0), arena.position.x + 8.0, arena.end.x - 8.0)
				var orb := ORB.instantiate()
				orb.set("floor_y", arena.end.y)
				orb.position = get_parent().to_local(Vector2(x, arena.position.y - 10.0))
				get_parent().add_child(orb)
				_orbs_left -= 1
				_t = 0.38 if _phase == 2 else 0.3
				if _orbs_left <= 0:
					_step = 2
					_t = 0.8
		2:
			if _t <= 0.0:
				_think()

# --- blink ---------------------------------------------------------------------------

func _run_blink(_delta: float, p: Node2D) -> void:
	match _step:
		0:
			_set_tangible(false)
			create_tween().tween_property(sprite, "modulate:a", 0.0, 0.35)
			_t = 0.6
			_step = 1
		1:
			if _t <= 0.0 and p:
				var behind := -1.0 if p.get("facing") == null else -float(p.get("facing"))
				global_position = Vector2(clampf(p.global_position.x + behind * 36.0, arena.position.x, arena.end.x), p.global_position.y - 6.0)
				_facing = -1 if p.global_position.x < global_position.x else 1
				create_tween().tween_property(sprite, "modulate:a", 1.0, 0.25)
				_t = 0.4
				_step = 2
		2:  # hiện hình — kịp thấy rồi mới quét
			if _t <= 0.0:
				_set_tangible(true)
				_swipe.position.x = 18.0 * _facing
				_swipe.enable()
				_flash(Color(2.2, 0.7, 0.7))
				_t = 0.25
				_step = 3
		3:
			if _t <= 0.0:
				_swipe.disable()
				_t = 0.8
				_step = 4
		4:
			if _t <= 0.0:
				_think()

# --- tiện ích ------------------------------------------------------------------------

func _hover_y() -> float:
	return arena.position.y + 34.0 + sin(_bob * 1.6) * 8.0

## Bay về `to`; true khi đã tới.
func _float_to(to: Vector2, speed: float, delta: float) -> bool:
	global_position = global_position.move_toward(to, speed * delta)
	return global_position.distance_to(to) < 2.0

func _set_tangible(on: bool) -> void:
	hurtbox.get_node("CollisionShape2D").set_deferred("disabled", not on)
	hitbox.get_node("CollisionShape2D").set_deferred("disabled", not on)

func _flash(c: Color) -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", c, 0.05)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func _on_hurt(_source: Area2D) -> void:
	if health.is_alive():
		_flash(Color(6, 6, 6))

func _on_died() -> void:
	_dead = true
	_swipe.disable()
	_set_tangible(false)
	for m in _minions:
		if is_instance_valid(m):
			m.queue_free()
	Events.boss_defeated.emit(boss_id)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(4, 4, 4), 0.15)
	tw.tween_property(sprite, "scale", sprite.scale * 1.6, 1.1)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 1.1)
	await tw.finished
	queue_free()

func _player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
