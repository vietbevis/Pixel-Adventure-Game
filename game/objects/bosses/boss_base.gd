class_name BossBase
extends CharacterBody2D
## Boss: CharacterBody2D + FSM riêng (không phải EnemyBase — FSM khác hẳn). Dùng lại
## component HealthComponent / Hurtbox / Hitbox + EnemyStats. Máu forward lên
## `Events.boss_health_changed`; đổi phase → `Events.boss_phase_changed`; chết →
## `Events.boss_defeated`.
##
## P4a: 1 pattern (bomb_toss). P4b thêm charge / jump_slam + phase pool.

const GRAVITY := 900.0

@export var stats: EnemyStats
@export var boss_id: String = "boss"
## Sprite gốc quay mặt phải hay trái (King Pig quay trái).
@export var sprite_faces_right: bool = false
@export var intro_time: float = 1.2
## Nghỉ giữa 2 pattern (giây) — giảm dần theo phase.
@export var think_time: float = 0.9
@export var bomb_scene: PackedScene

enum State { INTRO, THINK, ATTACK, RECOVER, HURT, DEAD }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox

var _state: State = State.INTRO
var _timer: float = 0.0
var _facing: int = -1
var _player: Node2D = null
var _phase: int = 1
var _pattern: String = ""
var _pattern_step: int = 0
var _base_think: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss")
	_base_think = think_time
	_timer = intro_time
	if stats:
		hitbox.damage = stats.damage
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	health.health_changed.connect(_on_health_changed)
	Events.boss_health_changed.emit(health.hp, health.max_hp)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	velocity.y += GRAVITY * delta
	_timer -= delta
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
			_check_phase()
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
	if _state != State.HURT:
		sprite.flip_h = (_facing < 0) if sprite_faces_right else (_facing > 0)

func _to_think() -> void:
	_state = State.THINK
	_timer = think_time

func _pick_pattern() -> String:
	return "bomb_toss"

func _start_pattern(p: String) -> void:
	_pattern = p
	_pattern_step = 0
	_state = State.ATTACK
	velocity.x = 0.0
	sprite.play("attack")

func _run_pattern(delta: float) -> void:
	match _pattern:
		"bomb_toss":
			if _pattern_step == 0 and sprite.animation == "attack" and sprite.frame >= 2:
				_pattern_step = 1
				_spawn_bomb()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

func _on_anim_finished() -> void:
	if _state == State.ATTACK and sprite.animation == "attack":
		_state = State.RECOVER
		_timer = think_time

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

func _check_phase() -> void:
	var pct := float(health.hp) / float(health.max_hp)
	var want := 1
	if pct <= 0.33:
		want = 3
	elif pct <= 0.66:
		want = 2
	if want != _phase:
		_phase = want
		think_time = maxf(_base_think - 0.2 * (_phase - 1), 0.35)
		Events.boss_phase_changed.emit(_phase)

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
