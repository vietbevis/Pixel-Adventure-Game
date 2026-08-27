class_name EnemyBase
extends CharacterBody2D
## Quái mặt đất có AI, dùng chung cho mọi loại (Pig, Pig phục kích...). Nhóm "enemy".
##
## FSM hand-rolled (mở rộng pattern chaser_spike cũ). Thông số ở `stats` (EnemyStats
## resource); máu ở `HealthComponent` con; sát thương/chết dùng lại Hitbox / Hurtbox /
## EnemyHitReaction (xem components/). Traps (gai/cưa) KHÔNG dùng cái này.

enum Behavior {
	PATROL,  ## đi tuần giữa 2 điểm, phát hiện player thì đuổi
	GUARD,   ## đứng gác tại chỗ, đuổi khi player lại gần, quá leash thì quay về
}

enum State { PATROL, IDLE, CHASE, ATTACK, RETURN, HURT }

@export var stats: EnemyStats
## Trọng lực (px/giây²). 0 = bay (không dùng cho Pig).
@export var gravity: float = 900.0
## Quãng tuần tra tính từ vị trí spawn (chỉ trục x có tác dụng). Giữ tên cũ để
## override trong level scene carry qua.
@export var patrol_distance: Vector2 = Vector2(64, 0)
## > 0 thì ghi đè `stats.move_speed` cho lúc tuần tra (tương thích override cũ).
@export var patrol_speed: float = 0.0
@export var behavior: Behavior = Behavior.PATROL
## Bật Hitbox từ frame này của animation "attack".
@export var attack_hit_frame: int = 2
## Sprite gốc quay mặt sang phải hay trái (pig của Kings and Pigs quay trái).
@export var sprite_faces_right: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var _floor_check: RayCast2D = get_node_or_null(^"FloorCheck")

var _state: State = State.PATROL
var _origin: Vector2
var _patrol_min_x: float
var _patrol_max_x: float
var _facing: int = 1
var _attack_cd: float = 0.0
var _hurt_timer: float = 0.0
var _player: Node2D = null

func _ready() -> void:
	add_to_group("enemy")
	_origin = global_position
	_patrol_min_x = minf(global_position.x, global_position.x + patrol_distance.x)
	_patrol_max_x = maxf(global_position.x, global_position.x + patrol_distance.x)
	_facing = -1 if patrol_distance.x < 0.0 else 1
	var can_patrol := behavior == Behavior.PATROL and not is_equal_approx(patrol_distance.x, 0.0)
	_state = State.PATROL if can_patrol else State.IDLE
	if stats:
		hitbox.damage = stats.damage
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_anim_finished)
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if gravity > 0.0:
		velocity.y += gravity * delta

	match _state:
		State.PATROL: _do_patrol()
		State.IDLE: _do_idle(delta)
		State.CHASE: _do_chase()
		State.ATTACK: velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		State.RETURN: _do_return()
		State.HURT: _do_hurt(delta)

	move_and_slide()
	if _state != State.HURT:
		sprite.flip_h = (_facing < 0) if sprite_faces_right else (_facing > 0)

func _speed_patrol() -> float:
	return patrol_speed if patrol_speed > 0.0 else stats.move_speed

## Chân hụt khỏi mép platform: đang đứng đất nhưng ray phía trước không chạm đất.
func _at_ledge() -> bool:
	if _floor_check == null:
		return false
	_floor_check.position.x = absf(_floor_check.position.x) * _facing
	_floor_check.force_raycast_update()
	return is_on_floor() and not _floor_check.is_colliding()

func _do_patrol() -> void:
	velocity.x = _facing * _speed_patrol()
	_play("run")
	if is_on_wall() or _at_ledge():
		_facing = -_facing
	elif _facing > 0 and global_position.x >= _patrol_max_x:
		_facing = -1
	elif _facing < 0 and global_position.x <= _patrol_min_x:
		_facing = 1
	_check_detect()

func _do_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	_play("idle")
	_check_detect()

func _do_chase() -> void:
	if not is_instance_valid(_player):
		_end_chase()
		return
	var to_player := _player.global_position.x - global_position.x
	_facing = -1 if to_player < 0.0 else 1
	if behavior == Behavior.GUARD and global_position.distance_to(_origin) > stats.leash_range:
		_state = State.RETURN
		return
	if global_position.distance_to(_player.global_position) > stats.detect_range * 1.6:
		_end_chase()
		return
	if absf(to_player) <= stats.attack_range and _attack_cd <= 0.0 and is_on_floor():
		_start_attack()
		return
	if _at_ledge():
		velocity.x = 0.0
		_play("idle")
	else:
		velocity.x = _facing * stats.chase_speed
		_play("run")

func _do_return() -> void:
	var to_origin := _origin.x - global_position.x
	_facing = -1 if to_origin < 0.0 else 1
	if absf(to_origin) < 3.0:
		velocity.x = 0.0
		_state = State.IDLE
	else:
		velocity.x = _facing * stats.move_speed
		_play("run")
	_check_detect()

func _do_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		if is_instance_valid(_player):
			_state = State.CHASE
		else:
			_state = State.PATROL if behavior == Behavior.PATROL else State.IDLE

func _check_detect() -> void:
	var p := _find_player()
	if p and global_position.distance_to(p.global_position) <= stats.detect_range:
		_player = p
		_state = State.CHASE

func _end_chase() -> void:
	_player = null
	_state = State.RETURN if behavior == Behavior.GUARD else State.PATROL

func _start_attack() -> void:
	_state = State.ATTACK
	velocity.x = 0.0
	_attack_cd = stats.attack_cooldown
	hitbox.position = Vector2(stats.attack_range * 0.85 * _facing, 0.0)
	sprite.play("attack")

func _on_frame_changed() -> void:
	if _state == State.ATTACK and sprite.animation == "attack" and sprite.frame >= attack_hit_frame:
		hitbox.enable()

func _on_anim_finished() -> void:
	if sprite.animation != "attack":
		return
	hitbox.disable()
	if _state == State.ATTACK:
		if is_instance_valid(_player):
			_state = State.CHASE
		else:
			_state = State.RETURN if behavior == Behavior.GUARD else State.PATROL

func _on_hurt(source: Area2D) -> void:
	if not health.is_alive():
		return
	_state = State.HURT
	_hurt_timer = stats.knockback_time
	_player = _find_player()  # bị đánh thì aggro luôn sau khi hết choáng
	hitbox.disable()
	var away := 1.0 if global_position.x >= source.global_position.x else -1.0
	velocity = Vector2(away * stats.knockback_speed, -70.0)
	sprite.play("hit")

func _on_died() -> void:
	# EnemyHitReaction (con) lo freeze + fade + Events.enemy_died + queue_free.
	sprite.play("dead")
	set_physics_process(false)

func _play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)

func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
