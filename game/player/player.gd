extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -320.0
const GRAVITY := 900.0
const MAX_FALL_SPEED := 500.0
const MAX_JUMPS := 2
const WALL_JUMP_PUSH := 180.0
const WALL_SLIDE_SPEED := 60.0
## Thời gian (giây) sau wall-jump mà input trái/phải bị khoá, để lực đẩy WALL_JUMP_PUSH
## đưa player ra xa tường trước khi input kéo lại. Riêng khoá này KHÔNG đủ chống leo
## tường vô hạn (giữ phím hướng tường + spam nhảy thì lock hết hạn là bám lại nhảy
## tiếp) — phải kết hợp với last_wall_jump_dir bên dưới.
const WALL_JUMP_LOCK_DURATION := 0.18
## Freeze frame ngắn khi đòn đánh trúng (giây thực, không theo Engine.time_scale).
const HIT_STOP_DURATION := 0.05

## Ability Dash (mở khoá sau khi thắng Forest Boss — xem core/progression.gd).
const DASH_SPEED := 340.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.5

const ATTACK_ANIM := &"attack"
const DASH_DUST := preload("res://objects/fx/dust.tscn")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
## Nguồn thật của số tim + trạng thái bất tử. Xem components/health_component.gd.
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox
@onready var abilities: AbilitySystem = $AbilitySystem

var jumps_left: int = MAX_JUMPS
var wall_jump_lock_timer: float = 0.0
## Hướng nhìn (-1 trái / +1 phải), cập nhật khi có input trái/phải. Dùng đặt Hitbox.
var facing: int = 1
## true trong lúc animation "attack" đang chạy (khoá tái kích hoạt + khoá _update_animation).
var is_attacking: bool = false
var _hit_stop_active: bool = false
## Hướng pháp tuyến (sign của get_wall_normal().x: -1 / +1) của lần wall-jump gần nhất.
## Chặn wall-jump lại CÙNG một mặt tường cho tới khi chạm đất hoặc chạm mặt tường
## đối diện — nhờ đó không leo vô hạn trên 1 bức tường, nhưng vẫn zig-zag được giữa
## 2 tường của khe hẹp. 0 = chưa wall-jump lần nào kể từ lúc chạm đất.
var last_wall_jump_dir: float = 0.0
## true khi đang trong màn thua/thắng (khoá input, không xử lý va chạm nữa)
var is_dead: bool = false

var is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: int = 1

func _ready() -> void:
	add_to_group("player")
	_apply_sprite_frames()
	global_position = GameManager.respawn_position
	sprite.play("idle")
	health.died.connect(_on_health_died)
	health.health_changed.connect(_on_health_changed)
	health.invincibility_started.connect(_on_invincibility_started)
	health.invincibility_ended.connect(_on_invincibility_ended)
	Events.checkpoint_activated.connect(_on_checkpoint_activated)
	hurtbox.hurt.connect(_on_hurt)
	hitbox.hit_landed.connect(_on_hit_landed)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	# Đồng bộ mirror + HUD ngay lúc vào màn (HealthComponent._ready đã emit trước khi ta connect).
	_on_health_changed(health.hp, health.max_hp)

## player.tscn bake sẵn SpriteFrames của King (nhân vật đầu roster) làm preview
## editor. Ở đây đổi sang bộ SpriteFrames + offset của nhân vật người chơi chọn —
## xem core/characters.gd. Offset bù chênh lệch kích thước frame giữa các nhân vật
## để chân khớp với collision dùng chung.
func _apply_sprite_frames() -> void:
	var character := GameManager.selected_character
	sprite.sprite_frames = load(CharacterData.get_frames_path(character))
	sprite.offset = CharacterData.get_offset(character)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if is_dashing:
		_dash_timer -= delta
		velocity = Vector2(_dash_dir * DASH_SPEED, 0.0)  # lướt ngang, bỏ qua trọng lực
		if _dash_timer <= 0.0:
			is_dashing = false
		move_and_slide()
		return

	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 \
			and not is_attacking and abilities.is_unlocked("dash"):
		_start_dash()
		return

	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	wall_jump_lock_timer = max(wall_jump_lock_timer - delta, 0.0)

	var on_wall := is_on_wall() and not is_on_floor()
	if on_wall and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jumps_left = MAX_JUMPS - 1
		elif on_wall and wall_jump_lock_timer <= 0.0 and signf(get_wall_normal().x) != last_wall_jump_dir:
			velocity.y = JUMP_VELOCITY
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
			jumps_left = MAX_JUMPS - 1
			wall_jump_lock_timer = WALL_JUMP_LOCK_DURATION
			last_wall_jump_dir = signf(get_wall_normal().x)
			sprite.play("wall_jump")
		elif jumps_left > 0:
			velocity.y = JUMP_VELOCITY
			jumps_left -= 1
			sprite.play("double_jump")

	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		facing = -1 if direction < 0 else 1
	if wall_jump_lock_timer > 0.0:
		# Đang trong lúc bị đẩy ra khỏi tường sau wall-jump: bỏ qua input trái/phải
		# để lực đẩy có tác dụng, tránh bị kéo dính ngược lại tường ngay lập tức.
		pass
	elif direction != 0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if is_on_floor():
		jumps_left = MAX_JUMPS
		last_wall_jump_dir = 0.0

	move_and_slide()
	_update_animation(on_wall)

func _update_animation(on_wall: bool) -> void:
	# Giữ nguyên anim "attack" cho tới khi phát xong. Điều kiện kèm `animation == attack`
	# để nếu đòn bị anim khác cắt ngang (vd trúng đòn → "hit") thì không kẹt.
	if is_attacking and sprite.animation == ATTACK_ANIM:
		return
	# Chỉ giữ nguyên khung hình "hit" trong lúc animation đang chạy; phát xong rồi
	# thì phải nhả ra cho các animation khác (idle/run/...) vì giờ trúng bẫy không
	# còn chắc chắn dẫn tới chết nữa (còn tim thì vẫn chơi tiếp được).
	if sprite.animation == "hit" and sprite.is_playing():
		return
	if sprite.animation in ["double_jump", "wall_jump"] and sprite.is_playing():
		return
	if is_on_floor():
		sprite.play("run" if abs(velocity.x) > 10.0 else "idle")
	elif on_wall:
		sprite.play("wall_jump")
	elif velocity.y < 0:
		sprite.play("jump")
	else:
		sprite.play("fall")

## --- Đòn đánh ---
## Hitbox (con của Player) được đặt trước mặt theo `facing`, bật/tắt theo frame của
## animation "attack" (mỗi nhân vật có bộ attack riêng — xem CharacterData). Hitbox
## KHÔNG tự gây damage: Hurtbox của quái tự phát hiện và áp. Xem components/hitbox.gd.
func _start_attack() -> void:
	is_attacking = true
	var character := GameManager.selected_character
	hitbox.damage = CharacterData.get_attack_damage(character)
	hitbox.position = Vector2(CharacterData.get_attack_reach(character) * facing, 0.0)
	sprite.flip_h = facing < 0
	sprite.play(ATTACK_ANIM)

func _on_sprite_frame_changed() -> void:
	# Bật Hitbox từ frame thứ 2 của đòn đánh (lúc vũ khí thực sự quét tới).
	if is_attacking and sprite.animation == ATTACK_ANIM and sprite.frame >= 1:
		hitbox.enable()

func _on_sprite_animation_finished() -> void:
	if sprite.animation == ATTACK_ANIM:
		_end_attack()

## Kết thúc đòn đánh / dash (phát xong, hoặc bị cắt ngang do trúng đòn / chết).
func _end_attack() -> void:
	is_attacking = false
	is_dashing = false
	hitbox.disable()

## --- Dash ---
func _start_dash() -> void:
	_end_attack()  # huỷ đòn đánh đang dở (phải gọi TRƯỚC khi bật is_dashing)
	is_dashing = true
	_dash_timer = DASH_DURATION
	_dash_cooldown = DASH_COOLDOWN
	_dash_dir = facing
	sprite.flip_h = facing < 0
	sprite.play("jump")
	var dust := DASH_DUST.instantiate()
	get_parent().add_child(dust)
	dust.global_position = global_position + Vector2(-_dash_dir * 8.0, 8.0)
	dust.scale.x = -_dash_dir

## Khựng hình cực ngắn khi đòn trúng — làm cú đánh "đã tay" hơn.
func _on_hit_landed(_target: Hurtbox) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.05
	# ignore_time_scale = true → timer đếm theo giây thực, không bị time_scale làm chậm.
	await get_tree().create_timer(HIT_STOP_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false

## Trừ 1 tim "từ ngoài" — hiện chỉ dùng cho rơi khỏi map (level_base gọi mỗi frame
## trong lúc rơi). Sát thương do chạm bẫy/quái giờ đi qua Hurtbox → _on_hurt.
## `force_reposition`: rơi khỏi map thì dù còn tim vẫn bung ngay về respawn, tránh
## bị gọi liên tục mỗi frame trong lúc rơi tự do.
func hit(force_reposition: bool = false) -> void:
	if is_dead or health.is_invincible():
		return

	health.damage(1)
	if is_dead:
		# HealthComponent vừa phát `died` (xử lý đồng bộ) → _on_health_died đã tiếp quản.
		return

	_end_attack()
	sprite.play("hit")
	if force_reposition:
		# Rơi khỏi map: còn tim vẫn phải bung ngay về respawn, tránh gọi hit() mỗi frame.
		global_position = GameManager.respawn_position
		velocity = Vector2.ZERO

## GameManager.hearts giờ chỉ là mirror của HealthComponent (nguồn thật), giữ để HUD
## và code cũ chưa chuyển vẫn chạy — sẽ dọn ở Phase 6.
func _on_health_changed(current: int, maximum: int) -> void:
	GameManager.hearts = current
	Events.player_health_changed.emit(current, maximum)

func _on_checkpoint_activated(_position: Vector2) -> void:
	health.heal_to_full()

## Hurtbox vừa chạm bẫy/quái — sát thương đã được chuyển vào HealthComponent, ở đây
## chỉ phản ứng hình ảnh (nếu đòn chí mạng thì _on_health_died đã lo, is_dead = true).
func _on_hurt(_source: Area2D) -> void:
	if not is_dead:
		_end_attack()
		sprite.play("hit")

## Hết tim: chết thật. Có checkpoint → bung lại tại đó; không thì sang màn Game Over.
func _on_health_died() -> void:
	is_dead = true
	_end_attack()
	velocity = Vector2.ZERO
	sprite.play("hit")
	Events.player_died.emit()

	if GameManager.has_checkpoint:
		await get_tree().create_timer(0.4).timeout
		_respawn_at_checkpoint()
	else:
		GameManager.last_result = "lose"
		await get_tree().create_timer(0.6).timeout
		SceneTransition.goto("res://ui/end_screen/end_screen.tscn")

## Bung lại tại vị trí checkpoint gần nhất, đầy lại tim, cho chơi tiếp ngay
## trong màn hiện tại (không đổi scene, không qua màn Game Over).
func _respawn_at_checkpoint() -> void:
	health.revive()
	global_position = GameManager.respawn_position
	velocity = Vector2.ZERO
	is_dead = false
	is_dashing = false
	sprite.play("idle")
	health.grant_invincibility()

## Nhấp nháy sprite trong lúc bất tử tạm thời để người chơi biết vừa mất tim.
func _on_invincibility_started(duration: float) -> void:
	var blink_tween := create_tween()
	blink_tween.set_loops(int(duration / 0.1))
	blink_tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

func _on_invincibility_ended() -> void:
	sprite.modulate.a = 1.0

func win() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	GameManager.last_result = "win"
	SceneTransition.goto("res://ui/end_screen/end_screen.tscn")
