class_name Critter
extends CharacterBody2D
## Quái mặt đất "chạm là đau" (khác Pig: Pig có đòn đánh riêng). Dùng chung cho
## Opossum, Ếch (Rừng) và Bộ Xương, Chó Ngục (Hầm Ngục) — mỗi loại 1 scene + 1 SpriteFrames,
## hành vi chọn bằng `mode`:
##   WALK   — đi tuần trong ±patrol_distance, quay đầu ở tường / mép vực. `chase` = thấy
##            player thì tăng tốc về phía họ (vẫn không bước khỏi mép).
##   HOP    — đứng yên, cứ `hop_interval` giây nhảy 1 cú; thấy player thì nhảy về phía họ,
##            không thì nhảy về điểm gốc. Không tự nhảy xuống vực.
##   RISE   — nằm dưới đất (vô hình, không va chạm) tới khi player lại gần → trồi lên rồi
##            đi như WALK + chase.
##   CHARGE — đứng gác; player cùng tầm cao + trong tầm → gồng `charge_windup` giây rồi lao
##            thẳng tới tường / mép vực, nghỉ, đi bộ về chỗ gác.
## Sát thương: Hitbox luôn bật (chạm là trừ tim). Có StompBox thì player đạp đầu được.

enum Mode { WALK, HOP, RISE, CHARGE }
enum Charge { GUARD, WINDUP, RUN, REST, RETURN }

@export var mode: Mode = Mode.WALK
@export var speed: float = 36.0
## Nửa quãng tuần tra quanh điểm spawn (px). 0 = chỉ quay đầu ở tường / mép.
@export var patrol_distance: float = 64.0
@export var detect_range: float = 110.0
@export var chase: bool = false
@export var chase_speed: float = 58.0
@export var hop_velocity: Vector2 = Vector2(70.0, -250.0)
@export var hop_interval: float = 1.5
@export var charge_speed: float = 230.0
@export var charge_windup: float = 0.45
@export var gravity: float = 900.0
## Sprite gốc quay sang phải? (Sunny-land + GothicVania đa số quay trái.)
@export var sprite_faces_right: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var _floor_check: RayCast2D = $FloorCheck

var _origin: Vector2
var _facing: int = -1
var _stun: float = 0.0
var _hop_timer: float = 0.0
var _hidden: bool = false
var _charge: Charge = Charge.GUARD
var _charge_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	_origin = global_position
	_hop_timer = hop_interval * randf_range(0.4, 1.0)
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	if mode == Mode.RISE:
		_set_hidden(true)
	else:
		sprite.play(&"run" if mode == Mode.WALK else &"idle")

func _physics_process(delta: float) -> void:
	if _hidden:
		var p := _player()
		if p and global_position.distance_to(p.global_position) < detect_range:
			_rise()
		return
	velocity.y = minf(velocity.y + gravity * delta, 500.0)
	if _stun > 0.0:
		_stun -= delta
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	else:
		match mode:
			Mode.WALK, Mode.RISE: _walk()
			Mode.HOP: _hop(delta)
			Mode.CHARGE: _charge_tick(delta)
	move_and_slide()
	sprite.flip_h = (_facing < 0) if sprite_faces_right else (_facing > 0)

func _walk() -> void:
	if sprite.animation == &"rise" and sprite.is_playing():
		velocity.x = 0.0
		return
	var spd := speed
	var p := _player()
	if chase and p and absf(p.global_position.y - global_position.y) < 48.0 \
			and global_position.distance_to(p.global_position) < detect_range:
		_facing = -1 if p.global_position.x < global_position.x else 1
		spd = chase_speed
	elif patrol_distance > 0.0:
		if global_position.x > _origin.x + patrol_distance:
			_facing = -1
		elif global_position.x < _origin.x - patrol_distance:
			_facing = 1
	if is_on_floor() and (_blocked_ahead() or _ledge_ahead()):
		if spd == chase_speed:
			velocity.x = 0.0  # đuổi tới mép thì đứng chờ, không tự lao xuống
			_play(&"idle")
			return
		_facing = -_facing
	velocity.x = _facing * spd
	_play(&"run")

func _hop(delta: float) -> void:
	if not is_on_floor():
		_play(&"jump" if velocity.y < 0.0 else &"fall")
		return
	velocity.x = 0.0
	_play(&"idle")
	_hop_timer -= delta
	if _hop_timer > 0.0:
		return
	_hop_timer = hop_interval
	var p := _player()
	var target_x := _origin.x
	if p and global_position.distance_to(p.global_position) < detect_range:
		target_x = p.global_position.x
	elif absf(global_position.x - _origin.x) < 4.0:
		target_x = global_position.x - _facing * 20.0  # lượn qua lại quanh chỗ đứng
	_facing = -1 if target_x < global_position.x else 1
	if _ledge_ahead() or _blocked_ahead():
		_facing = -_facing
	velocity = Vector2(_facing * hop_velocity.x, hop_velocity.y)

func _charge_tick(delta: float) -> void:
	var p := _player()
	match _charge:
		Charge.GUARD:
			velocity.x = 0.0
			_play(&"idle")
			if p and absf(p.global_position.y - global_position.y) < 28.0 \
					and absf(p.global_position.x - global_position.x) < detect_range:
				_facing = -1 if p.global_position.x < global_position.x else 1
				_charge = Charge.WINDUP
				_charge_timer = charge_windup
		Charge.WINDUP:
			velocity.x = 0.0
			_play(&"idle")
			sprite.position.x = sin(_charge_timer * 90.0) * 1.5  # rung báo hiệu
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				sprite.position.x = 0.0
				_charge = Charge.RUN
				_charge_timer = 1.6
		Charge.RUN:
			velocity.x = _facing * charge_speed
			_play(&"run")
			_charge_timer -= delta
			if _charge_timer <= 0.0 or (is_on_floor() and (_blocked_ahead() or _ledge_ahead())):
				velocity.x = 0.0
				_charge = Charge.REST
				_charge_timer = 0.9
		Charge.REST:
			velocity.x = 0.0
			_play(&"idle")
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_charge = Charge.RETURN
		Charge.RETURN:
			var dx := _origin.x - global_position.x
			if absf(dx) < 3.0 or (is_on_floor() and (_blocked_ahead() or _ledge_ahead())):
				_charge = Charge.GUARD
				velocity.x = 0.0
				return
			_facing = -1 if dx < 0.0 else 1
			velocity.x = _facing * speed
			_play(&"run")

func _ledge_ahead() -> bool:
	_floor_check.position.x = absf(_floor_check.position.x) * _facing
	_floor_check.force_raycast_update()
	return not _floor_check.is_colliding()

func _blocked_ahead() -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -_facing

func _rise() -> void:
	_set_hidden(false)
	var p := _player()
	if p:
		_facing = -1 if p.global_position.x < global_position.x else 1
	sprite.play(&"rise")

func _set_hidden(on: bool) -> void:
	_hidden = on
	sprite.visible = not on
	for shape in find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred("disabled", on)

func _on_hurt(source: Area2D) -> void:
	if not health.is_alive():
		return
	_stun = 0.25
	_charge = Charge.REST if mode == Mode.CHARGE else _charge
	_charge_timer = 0.6
	var away := 1.0 if global_position.x >= source.global_position.x else -1.0
	velocity = Vector2(away * 140.0, -90.0)

func _on_died() -> void:
	set_physics_process(false)

func _play(anim: StringName) -> void:
	if sprite.animation != anim and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func _player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
