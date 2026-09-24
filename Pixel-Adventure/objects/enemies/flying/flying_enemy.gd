class_name FlyingEnemy
extends CharacterBody2D
## Quái bay, chạm là đau. Hai kiểu:
##   SWOOP (Đại bàng — Rừng): lượn ngang quanh điểm spawn, bồng bềnh lên xuống; khi player
##          ở phía dưới trong tầm → khựng lại báo hiệu rồi bổ nhào tới vị trí player lúc đó,
##          sau đó bay ngược về độ cao cũ. Va tường/đất thì dừng bổ nhào.
##   HAUNT  (Hồn ma — Hầm Ngục): trôi chậm về phía player xuyên tường; cứ vài giây lại mờ
##          đi (không đánh được, cũng không gây sát thương) rồi hiện lại. Ra khỏi vùng
##          `leash` thì trôi về chỗ cũ.

enum Kind { SWOOP, HAUNT }
enum St { PATROL, TELEGRAPH, DIVE, CLIMB }

@export var kind: Kind = Kind.SWOOP
@export var patrol_distance: float = 80.0
@export var speed: float = 40.0
@export var detect_range: float = 130.0
@export var dive_speed: float = 190.0
@export var leash: float = 200.0
@export var sprite_faces_right: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox

var _origin: Vector2
var _facing: int = -1
var _t: float = 0.0
var _st: St = St.PATROL
var _timer: float = 0.0
var _dive_dir: Vector2
var _cooldown: float = 0.0
var _faded: bool = false
var _fade_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	_origin = global_position
	_t = randf() * TAU
	_fade_timer = randf_range(2.0, 3.5)
	sprite.play(&"fly")
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(func() -> void: set_physics_process(false))
	if kind == Kind.HAUNT:
		collision_mask = 0  # hồn ma xuyên tường

func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if kind == Kind.SWOOP:
		_swoop(delta)
	else:
		_haunt(delta)
	move_and_slide()
	sprite.flip_h = (_facing < 0) if sprite_faces_right else (_facing > 0)

func _swoop(delta: float) -> void:
	var p := _player()
	match _st:
		St.PATROL:
			if global_position.x > _origin.x + patrol_distance:
				_facing = -1
			elif global_position.x < _origin.x - patrol_distance:
				_facing = 1
			var target_y := _origin.y + sin(_t * 2.4) * 6.0
			velocity = Vector2(_facing * speed, (target_y - global_position.y) * 4.0)
			if p and _cooldown <= 0.0:
				var d := p.global_position - global_position
				if d.y > 16.0 and d.y < detect_range and absf(d.x) < detect_range * 0.7:
					_st = St.TELEGRAPH
					_timer = 0.4
					_facing = -1 if d.x < 0.0 else 1
		St.TELEGRAPH:
			velocity = Vector2(0.0, -30.0)  # hất nhẹ lên — báo sắp bổ nhào
			_timer -= delta
			if _timer <= 0.0:
				var aim := (p.global_position + Vector2(0, -6)) if p else global_position + Vector2(0, 80)
				_dive_dir = (aim - global_position).normalized()
				_st = St.DIVE
				_timer = 1.1
		St.DIVE:
			velocity = _dive_dir * dive_speed
			_timer -= delta
			if _timer <= 0.0 or is_on_floor() or is_on_wall() or is_on_ceiling():
				_st = St.CLIMB
		St.CLIMB:
			var back := Vector2(clampf(global_position.x, _origin.x - patrol_distance, _origin.x + patrol_distance), _origin.y)
			var to := back - global_position
			if to.length() < 4.0:
				_st = St.PATROL
				_cooldown = 1.2
				velocity = Vector2.ZERO
			else:
				velocity = to.normalized() * speed * 1.6
				_facing = -1 if to.x < 0.0 else 1

func _haunt(delta: float) -> void:
	_fade_timer -= delta
	if _fade_timer <= 0.0:
		_set_faded(not _faded)
		_fade_timer = 1.3 if _faded else randf_range(2.5, 3.5)
	var p := _player()
	var target := _origin + Vector2(sin(_t * 0.8) * patrol_distance, sin(_t * 1.7) * 8.0)
	var spd := speed * 0.6
	if p and p.global_position.distance_to(global_position) < detect_range \
			and p.global_position.distance_to(_origin) < leash:
		target = p.global_position + Vector2(0, -6)
		spd = speed
	var to := target - global_position
	velocity = to.normalized() * spd if to.length() > 2.0 else Vector2.ZERO
	if absf(to.x) > 2.0:
		_facing = -1 if to.x < 0.0 else 1

func _set_faded(on: bool) -> void:
	_faded = on
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.25 if on else 1.0, 0.35)
	hitbox.get_node("CollisionShape2D").set_deferred("disabled", on)
	hurtbox.get_node("CollisionShape2D").set_deferred("disabled", on)

func _on_hurt(source: Area2D) -> void:
	if not health.is_alive():
		return
	var away := (global_position - source.global_position).normalized()
	global_position += away * 10.0
	if kind == Kind.SWOOP:
		_st = St.CLIMB

func _player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
