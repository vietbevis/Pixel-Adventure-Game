extends Area2D
## NPC ở hub: có hành vi riêng (FSM nhỏ) + thoại thay đổi theo tiến trình đã lưu.
## Đứng gần + bấm `interact` (E) → mở hộp thoại (Dialogue autoload). Bong bóng "Hello"
## của Kings and Pigs nổi trên đầu lúc đang nói.
##
## FSM hand-rolled theo đúng pattern `EnemyBase` (không dùng plugin state machine).
## NPC là `Area2D` không có vật lý — sàn hub phẳng nên chỉ cần dịch `global_position.x`;
## `wander_range` / `follow_leash` giữ NPC không trôi ra khỏi sàn hay đè lên portal.
##
## Ba hành vi (xem PLAN.md mục 7):
##   STATIONARY — đứng yên, lúc rảnh quay mặt về portal của world đang là mục tiêu
##   WANDER     — đi tuần, tò mò bám theo player, tâm trạng đổi theo tiến trình
##   SKITTISH   — nhát gan: player lao tới thì bỏ chạy, phải đứng yên mới chịu nói

enum Behavior {
	STATIONARY,  ## đứng một chỗ (cố vấn bên bàn đồ)
	WANDER,      ## đi tuần trong `wander_range`, bám theo player khi player lại gần
	SKITTISH,    ## bỏ chạy khi player lại gần một cách hung hăng
}

## Dòng thoại tính động, nối vào cuối line_1..3 (ngoài `report_abilities`).
enum DynamicLine {
	NONE,
	NEXT_OBJECTIVE,  ## mục tiêu kế tiếp (Progression.next_objective)
	MOOD,            ## tâm trạng theo tiến trình
	WORLD_TIP,       ## mách về quái ở world đang là mục tiêu
}

@export_multiline var line_1: String = ""
@export_multiline var line_2: String = ""
@export_multiline var line_3: String = ""
@export var speaker: String = ""
## Nếu bật: append 1 dòng về các ability người chơi đã mở khoá (dựng từ SaveManager).
@export var report_abilities: bool = false
@export var dynamic_line: DynamicLine = DynamicLine.NONE

@export_group("Hành vi")
@export var behavior: Behavior = Behavior.STATIONARY
## Nửa biên độ đi tuần tính từ vị trí đặt trong scene (chỉ trục x). 0 = không đi.
@export var wander_range: float = 0.0
@export var walk_speed: float = 26.0
## Player vào bán kính này thì NPC để ý (dừng lại, quay mặt, hiện bong bóng).
@export var notice_radius: float = 70.0
## WANDER: khoảng cách muốn giữ khi bám theo player.
@export var follow_distance: float = 34.0
## SKITTISH: bán kính hoảng sợ.
@export var flee_radius: float = 70.0
## SKITTISH: player phải đứng yên trong `flee_radius` đủ lâu (giây) thì NPC mới bình tĩnh.
@export var calm_time: float = 1.2
## Nới thêm bao nhiêu px ngoài `wander_range` khi bám theo player / bỏ chạy. Giữ đủ nhỏ
## để NPC không lấn vào vùng `interact` của portal bên cạnh (portal rộng 40px).
@export var leash_extra: float = 40.0

@export_group("Hiển thị")
## SpriteFrames cho dáng đứng NPC — mặc định là Pig. Đổi trên instance nếu muốn NPC khác.
@export var idle_frames: SpriteFrames = preload("res://objects/enemies/pig/sprites/pig_frames.tres")
## Hướng nhìn mặc định của sprite: false = quay trái (Kings and Pigs), true = quay phải (Pixel Frog).
@export var sprite_faces_right: bool = false

## Tên hiển thị của từng ability trong dòng report (khớp DISPLAY của Toast).
const ABILITY_NAMES := {"dash": "Lướt (Dash)"}

## Tâm trạng dân làng theo tiến trình (chỉ số = bậc tâm trạng).
const MOOD_LINES: Array[String] = [
	"Đêm nào tôi cũng nghe tiếng heo ngoài hàng rào. Ngài đi cẩn thận đấy.",
	"Nghe nói ngài đã lấy lại được sức mạnh của các hiệp sĩ xưa. Bọn tôi bắt đầu dám ra đồng rồi.",
	"Vương Miện về rồi! Tối nay cả làng đốt lửa ăn mừng, ngài nhớ ghé.",
]
## Màu áo theo bậc tâm trạng — nhân với `modulate` gốc đặt trên instance.
const MOOD_TINTS: Array[Color] = [
	Color(0.82, 0.84, 0.9),
	Color(0.95, 0.95, 0.95),
	Color(1.0, 1.0, 0.92),
]
## Tốc độ đi bộ theo bậc tâm trạng (nhân với `walk_speed`): sợ thì lấm lét, vui thì nhanh nhẹn.
const MOOD_SPEED_SCALE: Array[float] = [0.7, 1.0, 1.25]

## Mách nước về world đang là mục tiêu (heo đào ngũ biết quân mình bố trí thế nào).
const WORLD_TIPS := {
	"forest": "Trong rừng có lũ heo cầm chuỳ đi tuần. Chúng chỉ nhìn về phía trước — vòng ra sau lưng là xong.",
	"castle": "Trong lâu đài lão cho gác pháo ở sân. Pháo bắn thẳng một đường, nấp sau bục đá mà tiến.",
	"dungeon": "Dưới hầm là bọn ném bom. Đừng đứng yên một chỗ, bom rơi đúng chỗ ngài vừa đứng đấy.",
	"": "Hết chuyện để mách rồi. Tôi về làm ruộng đây.",
}

## Player được coi là "hung hăng" khi chạy nhanh hơn ngưỡng này (px/giây).
const THREAT_SPEED := 60.0
## STATIONARY: bao lâu thì liếc về phía portal mục tiêu một lần.
const GLANCE_INTERVAL := 3.5

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _bubble: AnimatedSprite2D = $Bubble
@onready var _prompt: Label = $Prompt

var _near: bool = false
var _talking: bool = false
var _player: CharacterBody2D = null
var _origin: Vector2
var _facing: int = 1
var _base_modulate: Color = Color.WHITE

# WANDER
var _wander_target: float = 0.0
var _idle_timer: float = 0.0

# SKITTISH
var _scared: bool = false
var _calm_timer: float = 0.0
var _flee_dir: int = 1

# STATIONARY
var _glance_timer: float = 0.0

func _ready() -> void:
	_origin = global_position
	_base_modulate = modulate
	_sprite.sprite_frames = idle_frames
	_sprite.play("idle")
	_bubble.visible = false
	_prompt.visible = false
	_wander_target = _origin.x
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Dialogue.finished.connect(_on_dialogue_finished)
	if behavior == Behavior.WANDER:
		_apply_mood()

func _process(delta: float) -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	# Đang nói chuyện: đứng im, quay mặt về player, nhường toàn bộ input cho Dialogue.
	if _talking:
		if Dialogue.is_open:
			_stand()
			_face_player()
			return
		_talking = false

	_update_prompt()
	if _near and not Dialogue.is_open and _can_talk() and Input.is_action_just_pressed("interact"):
		_start_dialogue()
		return

	match behavior:
		Behavior.STATIONARY:
			_tick_stationary(delta)
		Behavior.WANDER:
			_tick_wander(delta)
		Behavior.SKITTISH:
			_tick_skittish(delta)

# --- Hành vi 1: Cố vấn (đứng yên, chỉ đường bằng ánh mắt) ---------------------

## Player gần thì quay mặt về player; rảnh thì định kỳ liếc về portal của world
## đang là mục tiêu — chỉ đường mà không cần một dòng thoại nào.
func _tick_stationary(delta: float) -> void:
	_stand()
	if _player_distance() <= notice_radius:
		_glance_timer = 0.0
		_face_player()
		return
	_glance_timer += delta
	if _glance_timer >= GLANCE_INTERVAL:
		_glance_timer = 0.0
		var portal := _objective_portal()
		if portal != null:
			_set_facing(1 if portal.global_position.x > global_position.x else -1)

## Tìm portal của world đang là mục tiêu trong cùng scene. Portal không thuộc group
## nào nên nhận diện qua property `world_id` (`get` trả null với node khác).
func _objective_portal() -> Node2D:
	var world_id: String = Progression.next_objective()["world"]
	if world_id == "":
		return null
	for node: Node in get_parent().get_children():
		if node is Node2D and node.get("world_id") == world_id:
			return node as Node2D
	return null

# --- Hành vi 2: Dân làng (đi tuần + tò mò bám theo) ---------------------------

func _tick_wander(delta: float) -> void:
	var speed := walk_speed * MOOD_SPEED_SCALE[_mood_tier()]
	var distance := _player_distance()

	# Player lại gần → dừng tuần, quay mặt, và bám theo ở khoảng cách lịch sự.
	if distance <= notice_radius:
		_face_player()
		var gap: float = absf(_player.global_position.x - global_position.x)
		if gap > follow_distance and _within_leash(_facing):
			_walk(_facing, speed * 0.85, delta)
		else:
			_stand()
		return

	# Ra khỏi quãng tuần (vì vừa bám theo player) → đi về.
	if global_position.x < _min_x() or global_position.x > _max_x():
		_walk(1 if global_position.x < _min_x() else -1, speed, delta)
		return

	# Đi tuần: tới mốc thì nghỉ một nhịp (làm việc vặt) rồi chọn mốc mới.
	if _idle_timer > 0.0:
		_idle_timer -= delta
		_stand()
		return
	if absf(global_position.x - _wander_target) < 4.0:
		_idle_timer = randf_range(0.8, 2.2)
		_wander_target = randf_range(_min_x(), _max_x())
		return
	_walk(1 if _wander_target > global_position.x else -1, speed, delta)

## Bậc tâm trạng 0..2 theo tiến trình đã lưu.
func _mood_tier() -> int:
	if SaveManager.is_boss_defeated("dungeon_boss"):
		return 2
	if SaveManager.is_boss_defeated("forest_boss") or SaveManager.is_ability_unlocked("dash"):
		return 1
	return 0

## Nhân với `modulate` đặt sẵn trên instance thay vì ghi đè, để không mất màu áo riêng.
func _apply_mood() -> void:
	modulate = _base_modulate * MOOD_TINTS[_mood_tier()]

# --- Hành vi 3: Heo đào ngũ (nhát gan, phải tạo lòng tin) ---------------------

func _tick_skittish(delta: float) -> void:
	var distance := _player_distance()

	if distance <= flee_radius and _player_is_threatening():
		_scared = true
		_calm_timer = 0.0
		_flee_dir = -1 if _player.global_position.x > global_position.x else 1

	if not _scared:
		if distance <= notice_radius:
			_stand()
			_face_player()
		elif absf(global_position.x - _origin.x) > 4.0:
			# Lảng về chỗ đứng cũ sau khi bỏ chạy.
			_walk(1 if _origin.x > global_position.x else -1, walk_speed, delta)
		else:
			_stand()
		return

	# Đang sợ: player đứng yên gần đó đủ lâu thì mới chịu bình tĩnh lại ("đổi lòng tin").
	if distance <= flee_radius and not _player_is_threatening():
		_calm_timer += delta
	elif distance > flee_radius * 1.8:
		_calm_timer += delta * 0.5  # player bỏ đi cũng dần yên tâm, nhưng chậm hơn
	else:
		_calm_timer = 0.0
	if _calm_timer >= calm_time:
		_scared = false
		_calm_timer = 0.0
		return

	# Chạy ra xa, nhưng không quá `wander_range` để khỏi trôi khỏi sàn hub.
	if _within_leash(_flee_dir):
		_walk(_flee_dir, walk_speed * 2.2, delta)
	else:
		_stand()
		_face_player()

func _player_is_threatening() -> bool:
	if _player == null:
		return false
	if bool(_player.get("is_attacking")) or bool(_player.get("is_dashing")):
		return true
	return absf(_player.velocity.x) > THREAT_SPEED

# --- Di chuyển / hướng nhìn ---------------------------------------------------

func _min_x() -> float:
	return _origin.x - wander_range

func _max_x() -> float:
	return _origin.x + wander_range

## Còn được phép đi thêm về hướng `dir` không (dây xích quanh vị trí đặt trong scene).
## Bám theo player / bỏ chạy được nới rộng hơn quãng tuần thêm `leash_extra`.
func _within_leash(dir: int) -> bool:
	var leash := wander_range + leash_extra
	var next_x := global_position.x + dir
	return next_x > _origin.x - leash and next_x < _origin.x + leash

func _walk(dir: int, speed: float, delta: float) -> void:
	global_position.x += dir * speed * delta
	_set_facing(dir)
	if _sprite.animation != &"run":
		_sprite.play("run")

func _stand() -> void:
	if _sprite.animation != &"idle":
		_sprite.play("idle")

func _set_facing(dir: int) -> void:
	_facing = dir
	_sprite.flip_h = (dir > 0) != sprite_faces_right

func _face_player() -> void:
	if is_instance_valid(_player):
		_set_facing(1 if _player.global_position.x > global_position.x else -1)

func _player_distance() -> float:
	if not is_instance_valid(_player):
		return INF
	return global_position.distance_to(_player.global_position)

# --- Thoại --------------------------------------------------------------------

## Heo đào ngũ đang hoảng thì không nói chuyện được — đó chính là câu đố nhỏ của NPC này.
func _can_talk() -> bool:
	return not (behavior == Behavior.SKITTISH and _scared)

func _update_prompt() -> void:
	if not _near:
		_prompt.visible = false
		return
	_prompt.visible = true
	_prompt.text = "Press E" if _can_talk() else "Đứng yên..."

func _start_dialogue() -> void:
	_talking = true
	_face_player()
	if behavior == Behavior.WANDER:
		_apply_mood()  # tâm trạng có thể đã đổi kể từ lần nói chuyện trước
	_bubble.visible = true
	_bubble.play("in")
	Dialogue.open(_build_lines(), speaker)

func _build_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for line: String in [line_1, line_2, line_3]:
		if line != "":
			lines.append(line)
	var extra := _dynamic_line_text()
	if extra != "":
		lines.append(extra)
	if report_abilities:
		lines.append(_ability_line())
	return lines

func _dynamic_line_text() -> String:
	match dynamic_line:
		DynamicLine.NEXT_OBJECTIVE:
			return String(Progression.next_objective()["text"])
		DynamicLine.MOOD:
			return MOOD_LINES[_mood_tier()]
		DynamicLine.WORLD_TIP:
			var world_id: String = Progression.next_objective()["world"]
			return String(WORLD_TIPS.get(world_id, WORLD_TIPS[""]))
		_:
			return ""

func _ability_line() -> String:
	var unlocked: Array = SaveManager.get_unlocked_abilities()
	if unlocked.is_empty():
		return "Ngươi chưa có sức mạnh nào. Di vật của các hiệp sĩ xưa vẫn nằm đâu đó trong Rừng."
	var names: PackedStringArray = []
	for id: String in unlocked:
		names.append(String(ABILITY_NAMES.get(id, id.capitalize())))
	return "Sức mạnh ngươi đã có: %s." % ", ".join(names)

func _on_dialogue_finished() -> void:
	if _bubble.visible:
		_bubble.play("out")
		await _bubble.animation_finished
		_bubble.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false
