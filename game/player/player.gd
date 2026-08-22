extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -320.0
const GRAVITY := 900.0
const MAX_FALL_SPEED := 500.0
const MAX_JUMPS := 2
const WALL_JUMP_PUSH := 180.0
const WALL_SLIDE_SPEED := 60.0
## Thời gian (giây) sau wall-jump mà input trái/phải bị khoá, để lực đẩy WALL_JUMP_PUSH
## thực sự đưa player ra xa tường. Không có khoá này, nếu người chơi vẫn giữ phím đi
## về hướng tường thì mỗi frame lại "bám tường" và nhảy tiếp được ngay lập tức, leo
## tường vô hạn và vọt ra ngoài map (kể cả trèo qua đỉnh tường biên).
const WALL_JUMP_LOCK_DURATION := 0.18
## Thời gian bất tử (giây) ngay sau khi bị trúng đòn, tránh mất nhiều tim cùng lúc
const INVINCIBILITY_DURATION := 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var jumps_left: int = MAX_JUMPS
var wall_jump_lock_timer: float = 0.0
## true khi đang trong màn thua/thắng (khoá input, không xử lý va chạm nữa)
var is_dead: bool = false
## true trong lúc vừa bị mất 1 tim, tạm miễn nhiễm sát thương để không bị trừ tim liên tục
var is_invincible: bool = false

func _ready() -> void:
	add_to_group("player")
	_apply_sprite_frames()
	global_position = GameManager.respawn_position
	sprite.play("idle")

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
		elif on_wall and wall_jump_lock_timer <= 0.0:
			velocity.y = JUMP_VELOCITY
			velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
			jumps_left = MAX_JUMPS - 1
			wall_jump_lock_timer = WALL_JUMP_LOCK_DURATION
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
	if is_dead or is_invincible:
		return

	GameManager.hearts -= 1
	sprite.play("hit")

	if GameManager.hearts > 0:
		# Còn tim: chỉ bị đánh dấu bất tử tạm thời rồi chơi tiếp, không cần hồi sinh
		if force_reposition:
			global_position = GameManager.respawn_position
			velocity = Vector2.ZERO
		_start_invincibility()
		return

	# Hết tim: đây mới là "chết" thật sự
	is_dead = true
	velocity = Vector2.ZERO

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
	GameManager.hearts = GameManager.MAX_HEARTS
	global_position = GameManager.respawn_position
	velocity = Vector2.ZERO
	is_dead = false
	sprite.play("idle")
	_start_invincibility()

## Bật trạng thái bất tử tạm thời kèm hiệu ứng nhấp nháy để người chơi biết
## vừa mất tim, tránh bị trừ liên tiếp khi còn đứng cạnh bẫy.
func _start_invincibility() -> void:
	is_invincible = true
	var blink_tween := create_tween()
	blink_tween.set_loops(int(INVINCIBILITY_DURATION / 0.1))
	blink_tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
	blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.05)
	await get_tree().create_timer(INVINCIBILITY_DURATION).timeout
	is_invincible = false
	sprite.modulate.a = 1.0

func win() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	GameManager.last_result = "win"
	SceneTransition.goto("res://ui/end_screen/end_screen.tscn")
