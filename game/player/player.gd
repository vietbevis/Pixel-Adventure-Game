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

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
## Nguồn thật của số tim + trạng thái bất tử. Xem components/health_component.gd.
@onready var health: HealthComponent = $HealthComponent

var jumps_left: int = MAX_JUMPS
var wall_jump_lock_timer: float = 0.0
## Hướng pháp tuyến (sign của get_wall_normal().x: -1 / +1) của lần wall-jump gần nhất.
## Chặn wall-jump lại CÙNG một mặt tường cho tới khi chạm đất hoặc chạm mặt tường
## đối diện — nhờ đó không leo vô hạn trên 1 bức tường, nhưng vẫn zig-zag được giữa
## 2 tường của khe hẹp. 0 = chưa wall-jump lần nào kể từ lúc chạm đất.
var last_wall_jump_dir: float = 0.0
## true khi đang trong màn thua/thắng (khoá input, không xử lý va chạm nữa)
var is_dead: bool = false

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
	# Đồng bộ mirror + HUD ngay lúc vào màn (HealthComponent._ready đã emit trước khi ta connect).
	_on_health_changed(health.hp, health.max_hp)

## player.tscn đã bake sẵn SpriteFrames của Ninja Frog (nhân vật mặc định) làm
## preview trong editor. Ở đây chỉ đổi sang bộ SpriteFrames đã bake sẵn của nhân
## vật người chơi thực sự chọn — xem core/characters.gd (get_frames_path) và
## player/sprites/<character>/<character>_frames.tres.
func _apply_sprite_frames() -> void:
	var character := GameManager.selected_character
	sprite.sprite_frames = load(CharacterData.get_frames_path(character))

func _physics_process(delta: float) -> void:
	if is_dead:
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

	var direction := Input.get_axis("move_left", "move_right")
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

## Player trúng bẫy (gai, cưa, rơi hố...). Trừ 1 tim; hết tim mới thực sự "chết":
## - Nếu đã có checkpoint: tự bung lại tại checkpoint (không hiện màn Game Over).
## - Nếu chưa có checkpoint: hiện màn Game Over như bình thường.
## `force_reposition`: dùng cho trường hợp rơi khỏi map (không thể đứng lại tại
## chỗ như gai/cưa) nên dù còn tim vẫn phải bung ngay về điểm respawn gần nhất,
## tránh bị gọi hit() liên tục mỗi frame trong lúc rơi tự do.
func hit(force_reposition: bool = false) -> void:
	if is_dead or health.is_invincible():
		return

	health.damage(1)
	if is_dead:
		# HealthComponent vừa phát `died` (xử lý đồng bộ) → _on_health_died đã tiếp quản.
		return

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

## Hết tim: chết thật. Có checkpoint → bung lại tại đó; không thì sang màn Game Over.
func _on_health_died() -> void:
	is_dead = true
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
