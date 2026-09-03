class_name BossBase
extends CharacterBody2D
## Boss: CharacterBody2D + FSM riêng (không phải EnemyBase — FSM khác hẳn). Dùng lại
## component HealthComponent / Hurtbox / Hitbox + EnemyStats. Máu forward lên
## `Events.boss_health_changed`; đổi phase → `Events.boss_phase_changed`; chết →
## `Events.boss_defeated`.
##
## Pattern là sub-machine theo `_pattern_step` + `_step_timer` (KHÔNG coroutine dài),
## để pause / chết giữa chừng không vỡ. Pool pattern mở dần theo phase.

const GRAVITY := 900.0

const CHARGE_TELEGRAPH := 0.45
const CHARGE_SPEED := 270.0
const CHARGE_MAX_TIME := 1.3
const CHARGE_RECOVER := 0.95
const SLAM_TELEGRAPH := 0.3
const SLAM_JUMP := 380.0
const SLAM_FALL_ACCEL := 400.0
const SLAM_SHOCKWAVE_TIME := 0.16
const SLAM_RECOVER := 0.7

@export var stats: EnemyStats
@export var boss_id: String = "boss"
## Tên hiển thị trên thanh máu boss (mỗi boss đặt riêng trên instance).
@export var display_name: String = "Boss"
## Sprite gốc quay mặt phải hay trái (King Pig quay trái).
@export var sprite_faces_right: bool = false
@export var intro_time: float = 1.2
## Nghỉ giữa 2 pattern (giây) — giảm dần theo phase.
@export var think_time: float = 0.9
@export var bomb_scene: PackedScene
## Giới hạn x của arena (min, max). != ZERO thì kẹp boss trong đó (chống lao ra
## khỏi phòng lúc charge). Đặt trên instance trong scene arena.
@export var arena_bounds: Vector2 = Vector2.ZERO

enum State { INTRO, THINK, ATTACK, RECOVER, HURT, DEAD }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var _slam_hitbox: Area2D = get_node_or_null(^"SlamHitbox")
@onready var _floor_probe: RayCast2D = get_node_or_null(^"FloorProbe")

var _state: State = State.INTRO
var _timer: float = 0.0
var _step_timer: float = 0.0
var _facing: int = -1
var _lock_face: bool = false
var _player: Node2D = null
var _phase: int = 1
var _pattern: String = ""
var _pattern_step: int = 0
var _charge_dir: int = -1
var _base_think: float = 0.0
var _home: Vector2

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_home = global_position
	_base_think = think_time
	_timer = intro_time
	if stats:
		hitbox.damage = stats.damage
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	Events.boss_intro.emit(display_name, health.max_hp)
	Events.boss_health_changed.emit(health.hp, health.max_hp)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	velocity.y += GRAVITY * delta
	_timer -= delta
	_step_timer -= delta
	if not _lock_face:
		_face_player()

	match _state:
		State.INTRO:
			velocity.x = 0.0
			_play("idle")
			if _timer <= 0.0:
				_to_think()
		State.THINK:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_play("idle")
			if _check_phase():
				return
			if _timer <= 0.0:
				_start_pattern(_pick_pattern())
		State.ATTACK:
			_run_pattern(delta)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_play("idle")
			if _timer <= 0.0:
				_to_think()
		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			if _timer <= 0.0:
				_to_think()

	move_and_slide()
	if arena_bounds != Vector2.ZERO:
		global_position.x = clampf(global_position.x, arena_bounds.x, arena_bounds.y)
	# An toàn: rơi khỏi nền (charge ra khỏi mép / jump_slam trượt hố) → về chỗ spawn.
	if global_position.y > _home.y + 220.0:
		global_position = _home
		velocity = Vector2.ZERO
		if _state == State.ATTACK:
			_end_pattern(0.4)
	if _state != State.HURT:
		sprite.flip_h = (_facing < 0) if sprite_faces_right else (_facing > 0)

func _to_think() -> void:
	_state = State.THINK
	_timer = think_time
	_lock_face = false

func _pick_pattern() -> String:
	var pool: Array[String] = ["bomb_toss"]
	if _phase >= 2:
		pool.append("charge")
	if _phase >= 3:
		pool.append("jump_slam")
	return pool.pick_random()

func _start_pattern(p: String) -> void:
	_pattern = p
	_pattern_step = 0
	_state = State.ATTACK
	velocity.x = 0.0
	match p:
		"bomb_toss":
			sprite.play("attack")
		"charge":
			_step_timer = CHARGE_TELEGRAPH
			_flash()
		"jump_slam":
			_step_timer = SLAM_TELEGRAPH

func _end_pattern(recover: float) -> void:
	hitbox.disable()
	_slam_shockwave(false)
	_lock_face = false
	_state = State.RECOVER
	_timer = recover

func _run_pattern(delta: float) -> void:
	match _pattern:
		"bomb_toss":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _pattern_step == 0 and sprite.animation == "attack" and sprite.frame >= 2:
				_pattern_step = 1
				_spawn_bomb()
		"charge":
			_run_charge(delta)
		"jump_slam":
			_run_slam(delta)

func _run_charge(delta: float) -> void:
	match _pattern_step:
		0:  # rướn lùi lấy đà
			velocity.x = move_toward(velocity.x, _facing * -35.0, 500.0 * delta)
			_play("idle")
			if _step_timer <= 0.0:
				_charge_dir = _facing
				_lock_face = true
				_pattern_step = 1
				_step_timer = CHARGE_MAX_TIME
				hitbox.position = Vector2(24.0 * _charge_dir, 0.0)
				hitbox.enable()
		1:  # lao
			velocity.x = _charge_dir * CHARGE_SPEED
			_play("run")
			if is_on_wall() or _step_timer <= 0.0 or _ledge_ahead(_charge_dir):
				_pattern_step = 2
				_end_pattern(CHARGE_RECOVER)  # choáng lâu — lúc chém boss ăn nhất

func _run_slam(delta: float) -> void:
	match _pattern_step:
		0:  # khựng
			velocity.x = 0.0
			_play("idle")
			if _step_timer <= 0.0:
				velocity.y = -SLAM_JUMP
				velocity.x = _facing * 70.0  # trôi nhẹ về phía player (map đã lấp hố)
				_lock_face = true
				_pattern_step = 1
		1:  # bay lên
			_play("jump")
			if velocity.y >= 0.0:
				_pattern_step = 2
		2:  # rơi (nặng)
			_play("fall")
			velocity.y = minf(velocity.y + SLAM_FALL_ACCEL * delta, 1200.0)
			if is_on_floor():
				_pattern_step = 3
				_step_timer = SLAM_SHOCKWAVE_TIME
				_play("land")
				_slam_shockwave(true)
		3:  # tiếp đất + shockwave
			velocity.x = 0.0
			if _step_timer <= 0.0:
				_end_pattern(SLAM_RECOVER)

## Hụt nền phía trước theo hướng `dir` (đang đứng đất nhưng ray trước mặt không chạm).
func _ledge_ahead(dir: int) -> bool:
	if _floor_probe == null:
		return false
	_floor_probe.position.x = absf(_floor_probe.position.x) * dir
	_floor_probe.force_raycast_update()
	return is_on_floor() and not _floor_probe.is_colliding()

func _slam_shockwave(on: bool) -> void:
	if _slam_hitbox and _slam_hitbox.get_child_count() > 0:
		_slam_hitbox.get_child(0).set_deferred("disabled", not on)

func _on_anim_finished() -> void:
	if _state == State.ATTACK and _pattern == "bomb_toss" and sprite.animation == "attack":
		_end_pattern(think_time)

func _spawn_bomb() -> void:
	if bomb_scene == null or not is_instance_valid(_player):
		return
	var bomb: Bomb = bomb_scene.instantiate()
	get_parent().add_child(bomb)
	bomb.global_position = global_position + Vector2(12.0 * _facing, -16.0)
	var to := _player.global_position - bomb.global_position
	# Ném xa thì bay lâu hơn → cung nhẹ, dễ đọc, không "phi" ngang qua arena.
	var t := clampf(to.length() / 200.0, 0.7, 1.8)
	bomb.launch(Vector2(to.x / t, to.y / t - 0.5 * Bomb.GRAVITY * t), t)

## true nếu vừa đổi phase (đang roar — bỏ qua phần còn lại của THINK).
func _check_phase() -> bool:
	var pct := float(health.hp) / float(health.max_hp)
	var want := 1
	if pct <= 0.33:
		want = 3
	elif pct <= 0.66:
		want = 2
	if want == _phase:
		return false
	_phase = want
	think_time = maxf(_base_think - 0.15 * (_phase - 1), 0.4)
	Events.boss_phase_changed.emit(_phase)
	# Roar: đứng gầm + bất tử ngắn (không cheese được lúc chuyển phase).
	_state = State.HURT
	_timer = 0.7
	health.grant_invincibility()
	sprite.play("hit")
	_flash()
	return true

func _face_player() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player):
		_facing = -1 if _player.global_position.x < global_position.x else 1

func _on_health_changed(current: int, maximum: int) -> void:
	Events.boss_health_changed.emit(current, maximum)

func _on_hurt(source: Area2D) -> void:
	if not health.is_alive():
		return
	# Chỉ bị gián đoạn khi đang nghỉ; đang tung pattern thì "lì".
	if _state == State.THINK or _state == State.RECOVER:
		_state = State.HURT
		_timer = 0.25
		sprite.play("hit")
	var away := 1.0 if global_position.x >= source.global_position.x else -1.0
	velocity.x = away * 70.0
	_flash()

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(6, 6, 6), 0.04)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func _on_died() -> void:
	_state = State.DEAD
	velocity = Vector2.ZERO
	set_physics_process(false)
	for s in find_children("*", "CollisionShape2D", true, false):
		s.set_deferred("disabled", true)
	sprite.play("dead")
	Events.boss_defeated.emit(boss_id)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	await tw.finished
	queue_free()

func _play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)
