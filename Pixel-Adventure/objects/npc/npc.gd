extends Area2D
## NPC ở hub: có hành vi riêng (FSM nhỏ) + thoại thay đổi theo tiến trình đã lưu.
## Đứng gần + bấm `interact` (E) → mở hộp thoại (Dialogue autoload). Bong bóng "Hello"
## của Kings and Pigs nổi trên đầu lúc đang nói; bong bóng "?" / "!" (Crusty Crew) khi NPC
## để ý thấy player / hoảng sợ.
##
## FSM hand-rolled theo đúng pattern `EnemyBase` (không dùng plugin state machine).
## NPC là `Area2D` không có vật lý — sàn hub phẳng nên chỉ cần dịch `global_position.x`;
## `wander_range` / `leash_extra` giữ NPC không trôi ra khỏi sàn hay đè lên portal.
##
## Ba hành vi (xem PLAN.md mục 7):
##   STATIONARY — đứng yên, lúc rảnh quay về portal mục tiêu, cảnh báo khi player đứng ở cổng khoá
##   WANDER     — đi tuần, chạy ra đón player, bám theo, tâm trạng đổi theo tiến trình
##   SKITTISH   — nhát gan: bỏ chạy khi bị doạ, lòng tin tăng dần mỗi lần được trấn an
##
## AI phải NHÌN THẤY được mà không cần bấm E: mỗi lần đổi trạng thái NPC "bark" một câu
## ngắn trên đầu (`_bark`). SKITTISH hoảng thì phát `alarmed`, NPC anh em trong tầm nghe
## ngó sang. F3 bật overlay debug (tên trạng thái + bán kính nhận biết) cho cả 3 NPC.

## SKITTISH vừa hoảng — NPC anh em trong `hear_radius` quay sang nhìn.
signal alarmed(source: Node2D)

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
## WANDER: lần đầu player vào bán kính này (mỗi lần vào hub) thì chạy ra đón.
@export var greet_radius: float = 220.0
## SKITTISH: bán kính hoảng sợ.
@export var flee_radius: float = 70.0
## SKITTISH: player phải đứng yên trong `flee_radius` đủ lâu (giây) thì NPC mới bình tĩnh.
@export var calm_time: float = 1.2
## Nới thêm bao nhiêu px ngoài `wander_range` khi bám theo player / bỏ chạy. Giữ đủ nhỏ
## để NPC không lấn vào vùng `interact` của portal bên cạnh (portal rộng 40px).
@export var leash_extra: float = 40.0
## Nghe thấy NPC anh em hoảng (`alarmed`) trong bán kính này thì ngó sang.
@export var hear_radius: float = 380.0

@export_group("Hiển thị")
## SpriteFrames của NPC (cần anim `idle` + `run`, đáy khung = chân). Mặc định là Pig để scene
## gốc có hình trong editor; NPC ở hub đặt bộ riêng (objects/npc/sprites/<tên>/) trên instance.
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
## Câu lẩm bẩm lúc nghỉ tay, theo bậc tâm trạng — để người xem đọc được tâm trạng mà không cần mở thoại.
const MOOD_IDLE_BARKS := [
	["Tiếng gì thế...?", "Heo... có phải heo không?", "Mong ngài về sớm..."],
	["Ruộng năm nay chắc được mùa.", "Hôm nay yên ắng ghê.", "Sửa xong mái nhà là đẹp."],
	["Hôm nay trời đẹp ghê!", "La la la~", "Tối nay đốt lửa trại!"],
]
## Màu áo theo bậc tâm trạng — nhân với `modulate` gốc đặt trên instance.
const MOOD_TINTS: Array[Color] = [
	Color(0.72, 0.76, 0.92),
	Color(0.95, 0.95, 0.95),
	Color(1.0, 1.0, 0.88),
]
## Tốc độ đi bộ theo bậc tâm trạng (nhân với `walk_speed`): sợ thì lấm lét, vui thì nhanh nhẹn.
const MOOD_SPEED_SCALE: Array[float] = [0.7, 1.0, 1.25]

## Mách nước về world đang là mục tiêu (kẻ đào ngũ biết quân Vua Heo bố trí thế nào).
const WORLD_TIPS := {
	"forest": "Rừng không phải chỗ của bọn tôi — chỉ có opossum, ếch với đại bàng. Đại bàng mà khựng lại trên đầu ngài là sắp bổ nhào đấy, né sang bên!",
	"castle": "Cổng lâu đài có khối đá nghiền. Nó chớp mắt là sắp rơi — nhử cho rơi rồi chạy qua lúc nó đang kéo lên. Còn cổng gỗ mục thì cứ LƯỚT mà phá.",
	"dungeon": "Dưới hầm có chó ngục, thấy ngài ngang tầm là lao như tên bắn. Nhảy lên cao là nó lao hụt — rồi đạp đầu nó.",
	"": "Hết chuyện để mách rồi. Tôi về làm ruộng đây.",
}
## SKITTISH: bark theo đúng lý do bị doạ — cho thấy NPC nhận ra player đang làm gì.
const FLEE_BARKS := {
	"attack": "Á! Cất kiếm đi!",
	"dash": "Đừng lao vào tôi!",
	"run": "Chậm thôi! Tôi sợ!",
}
## Câu khi nghe NPC anh em hoảng, theo `Behavior`.
const NEIGHBOUR_BARKS: Array[String] = ["Lại hoảng rồi...", "Chuyện gì thế?!", ""]

## Player được coi là "hung hăng" khi chạy nhanh hơn ngưỡng này (px/giây).
const THREAT_SPEED := 60.0
## STATIONARY: bao lâu thì liếc về phía portal mục tiêu một lần.
const GLANCE_INTERVAL := 3.5
## STATIONARY: sau khi liếc, trạng thái "chỉ đường" kéo dài bao lâu (cho overlay debug).
const POINT_TIME := 1.5
## STATIONARY: player cách tâm portal khoá bao nhiêu px (trục x) thì bị coi là đang đứng ở cổng.
## Vùng `interact` của portal rộng 40px.
const LOCKED_PORTAL_RANGE := 22.0
## STATIONARY: không cảnh báo cổng khoá lại trong khoảng này (giây).
const WARN_COOLDOWN := 5.0
## WANDER: chạy ra đón nhanh hơn đi tuần, và được đi xa hơn dây xích thường.
const GREET_SPEED_SCALE := 1.9
const GREET_LEASH := 160.0
## SKITTISH: số lần trấn an để NPC tin hẳn (hết sợ player chạy).
const TRUST_MAX := 3
## Bong bóng cảm xúc ("?" / "!") hiện bao lâu trước khi tắt.
const EMOTE_TIME := 1.1
## Bark hiện bao lâu, và tối thiểu cách nhau bao lâu (chống spam).
const BARK_TIME := 2.2
const BARK_GAP := 0.8
## Bark dài hơn bề rộng này (px) thì xuống dòng.
const BARK_MAX_WIDTH := 150.0
## Ngó sang NPC anh em đang hoảng bao lâu.
const LOOK_TIME := 1.6

## Overlay debug dùng chung cho mọi NPC; F3 bật/tắt.
static var debug_view: bool = false
## Mọi NPC cùng nhận một phím F3 trong cùng frame — chỉ NPC đầu tiên được đảo cờ.
static var _debug_toggle_frame: int = -1

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _bubble: AnimatedSprite2D = $Bubble
@onready var _prompt: Label = $Prompt
@onready var _bark_label: Label = $Bark
@onready var _debug_label: Label = $Debug

var _near: bool = false
var _talking: bool = false
var _player: CharacterBody2D = null
var _origin: Vector2
var _facing: int = 1
var _base_modulate: Color = Color.WHITE
var _sprite_base_y: float = 0.0
var _head_y: float = -28.0
## Đáy khung bark (ngay trên chữ "Nhấn E"); khung mọc lên trên theo số dòng.
var _bark_bottom: float = -58.0
## Player đang trong `notice_radius` (để chỉ bật "?" lúc vừa bước vào, không bật mỗi frame).
var _noticed: bool = false
var _emote_timer: float = 0.0
## Tên trạng thái hiện tại — chỉ để hiển thị trên overlay debug.
var _state: String = ""
var _bark_tween: Tween
var _bark_gap: float = 0.0
var _debug_drawn: bool = false
# Ngó sang NPC anh em đang hoảng
var _look_source: Node2D = null
var _look_timer: float = 0.0

# STATIONARY
var _glance_timer: float = GLANCE_INTERVAL - 1.0
var _point_line: int = 0
var _greeted_player: bool = false
var _warned_portal: Node2D = null
var _warn_timer: float = 0.0

# WANDER
var _wander_target: float = 0.0
var _idle_timer: float = 0.0
var _mood: int = 0
## Đã chạy ra đón trong lần vào hub này chưa (NPC sinh lại mỗi lần vào hub).
var _greeted: bool = false
var _greet_running: bool = false

# SKITTISH
var _scared: bool = false
var _calm_timer: float = 0.0
var _calm_by_player: bool = false
var _flee_dir: int = 1

func _ready() -> void:
	_origin = global_position
	_base_modulate = modulate
	_sprite.sprite_frames = idle_frames
	_sprite.play("idle")
	_fit_to_frames()
	_bubble.visible = false
	_bubble.animation_finished.connect(_on_bubble_animation_finished)
	_prompt.visible = false
	_bark_label.visible = false
	_debug_label.visible = false
	_wander_target = _origin.x
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	Dialogue.finished.connect(_on_dialogue_finished)
	for node: Node in get_parent().get_children():
		if node != self and node.has_signal("alarmed"):
			node.connect("alarmed", _on_neighbour_alarmed)
	if behavior == Behavior.WANDER:
		_apply_mood()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F3:
		return
	var frame := Engine.get_process_frames()
	if frame != _debug_toggle_frame:
		_debug_toggle_frame = frame
		debug_view = not debug_view

func _process(delta: float) -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_tick_emote(delta)
	_bark_gap = maxf(_bark_gap - delta, 0.0)
	_warn_timer = maxf(_warn_timer - delta, 0.0)
	_tick_ai(delta)
	_apply_bob()
	_update_debug()

func _tick_ai(delta: float) -> void:
	# Đang nói chuyện: đứng im, quay mặt về player, nhường toàn bộ input cho Dialogue.
	if _talking:
		if Dialogue.is_open:
			_state = "NÓI CHUYỆN"
			_stand()
			_face_player()
			return
		_talking = false

	_update_prompt()
	if _near and not Dialogue.is_open and _can_talk() and Input.is_action_just_pressed("interact"):
		_start_dialogue()
		return

	# Vừa nghe NPC anh em hoảng: đứng lại ngó sang một nhịp rồi mới làm tiếp việc của mình.
	if _look_timer > 0.0:
		_look_timer -= delta
		_state = "NGÓ SANG"
		_stand()
		if is_instance_valid(_look_source):
			_set_facing(1 if _look_source.global_position.x > global_position.x else -1)
		return

	match behavior:
		Behavior.STATIONARY:
			_tick_stationary(delta)
		Behavior.WANDER:
			_tick_wander(delta)
		Behavior.SKITTISH:
			_tick_skittish(delta)

# --- Hành vi 1: Cố vấn (đứng yên, chỉ đường, cảnh báo cổng khoá) --------------

## Ưu tiên: cảnh báo cổng khoá > tiếp chuyện player ở gần > định kỳ quay về portal mục
## tiêu và nói to cổng nào đang chờ.
func _tick_stationary(delta: float) -> void:
	_stand()
	var locked := _locked_portal_under_player()
	if locked != null:
		_state = "CẢNH BÁO"
		_face_player()
		if locked != _warned_portal and _warn_timer <= 0.0:
			_warn_locked(locked)
		_warned_portal = locked
		return
	_warned_portal = null

	if _check_notice():
		_state = "TIẾP CHUYỆN"
		_glance_timer = 0.0
		_face_player()
		if not _greeted_player:
			_greeted_player = true
			_bark("Thưa Đức Vua! Lại đây, ta có tin.")
		return

	_glance_timer += delta
	_state = "CHỈ ĐƯỜNG" if _glance_timer < POINT_TIME and _objective_portal() != null else "CHỜ"
	if _glance_timer < GLANCE_INTERVAL:
		return
	_glance_timer = 0.0
	var portal := _objective_portal()
	if portal == null:
		return
	var dir := 1 if portal.global_position.x > global_position.x else -1
	_set_facing(dir)
	if _on_screen():
		var arrow := "»»" if dir > 0 else "««"
		var wname := _world_name(String(portal.get("world_id")))
		var lines: Array[String] = ["%s Cổng %s đang chờ ngài!" % [arrow, wname], "Đi %s đi, thưa ngài! %s" % [wname, arrow]]
		_bark(lines[_point_line])
		_point_line = 1 - _point_line

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

## Portal khoá mà player đang đứng trước cửa (null nếu không có).
func _locked_portal_under_player() -> Node2D:
	if not is_instance_valid(_player):
		return null
	for node: Node in get_parent().get_children():
		if not (node is Node2D) or node.get("world_id") == null:
			continue
		var portal := node as Node2D
		if WorldData.is_world_unlocked(String(portal.get("world_id"))):
			continue
		var d := _player.global_position - portal.global_position
		if absf(d.x) <= LOCKED_PORTAL_RANGE and absf(d.y) < 64.0:
			return portal
	return null

## Cố vấn đứng tít đầu làng nên cổng khoá thường nằm ngoài màn hình của ông ta: khi đó
## "gọi với" qua Toast để lời cảnh báo vẫn tới được người chơi.
func _warn_locked(portal: Node2D) -> void:
	_warn_timer = WARN_COOLDOWN
	var locked_name := _world_name(String(portal.get("world_id")))
	var goal_name := _world_name(String(Progression.next_objective()["world"]))
	var text := "Cổng %s còn khoá!" % locked_name
	if goal_name != "":
		text += " Hãy tới %s trước." % goal_name
	_emote("alert")
	if _on_screen():
		_bark(text, true)
	else:
		Toast.say("%s (gọi với): %s" % [speaker, text])

# --- Hành vi 2: Dân làng (chạy ra đón, đi tuần, bám theo) ---------------------

func _tick_wander(delta: float) -> void:
	var speed := walk_speed * MOOD_SPEED_SCALE[_mood]
	var distance := _player_distance()

	# Mỗi lần vào hub: thấy player từ xa thì reo lên và chạy ra đón.
	if not _greeted and distance <= greet_radius:
		_greeted = true
		_greet_running = true
		_emote("alert")
		_bark(_greeting_line(), true)
	if _greet_running:
		var dir := 1 if _player.global_position.x > global_position.x else -1
		if absf(_player.global_position.x - global_position.x) > follow_distance and _within_leash(dir, GREET_LEASH):
			_state = "CHẠY RA ĐÓN"
			_walk(dir, speed * GREET_SPEED_SCALE, delta)
			return
		_greet_running = false

	# Player lại gần → dừng tuần, quay mặt, và bám theo ở khoảng cách lịch sự.
	if _check_notice():
		_face_player()
		var gap: float = absf(_player.global_position.x - global_position.x)
		if gap > follow_distance and _within_leash(_facing):
			_state = "BÁM THEO"
			_walk(_facing, speed * 0.85, delta)
		else:
			_state = "NHÌN NGÀI"
			_stand()
		return

	# Ra khỏi quãng tuần (vì vừa bám theo / chạy ra đón) → đi về.
	if global_position.x < _min_x() or global_position.x > _max_x():
		_state = "VỀ CHỖ"
		_walk(1 if global_position.x < _min_x() else -1, speed, delta)
		return

	# Đi tuần: tới mốc thì nghỉ một nhịp (làm việc vặt) rồi chọn mốc mới.
	if _idle_timer > 0.0:
		_state = "VIỆC VẶT"
		_idle_timer -= delta
		_stand()
		return
	if absf(global_position.x - _wander_target) < 4.0:
		_idle_timer = randf_range(0.8, 2.2)
		_wander_target = randf_range(_min_x(), _max_x())
		_on_chore_pause()
		return
	_state = "ĐI TUẦN"
	_walk(1 if _wander_target > global_position.x else -1, speed, delta)

## Nghỉ tay: thỉnh thoảng lẩm bẩm theo tâm trạng; đang sợ thì giật mình ngoái lại.
func _on_chore_pause() -> void:
	if randf() > 0.5 or not _on_screen():
		return
	if _mood == 0:
		_set_facing(-_facing)
		_emote("ask")
	var barks: Array = MOOD_IDLE_BARKS[_mood]
	_bark(String(barks.pick_random()))

## Câu đón theo lượt chơi vừa rồi. World lấy từ level vừa chơi chứ không từ
## `GameManager.current_world` — vào màn qua Level Select thì portal không set biến đó.
func _greeting_line() -> String:
	var wname := _world_name(WorldData.world_of(GameManager.hub_came_from))
	match GameManager.last_result:
		"win":
			return "Ngài về rồi! Thắng ở %s rồi phải không?" % wname if wname != "" else "Ngài về rồi! Thắng rồi phải không?"
		"lose":
			return "Ngài bị thương à? Nghỉ chút đã rồi hẵng đi."
	return "Ơ! Đức Vua ghé làng kìa!"

## Bậc tâm trạng 0..2 theo tiến trình đã lưu.
func _mood_tier() -> int:
	if SaveManager.is_boss_defeated("dungeon_boss"):
		return 2
	if SaveManager.is_boss_defeated("forest_boss") or SaveManager.is_ability_unlocked("dash"):
		return 1
	return 0

## Nhân với `modulate` đặt sẵn trên instance thay vì ghi đè, để không mất màu áo riêng.
func _apply_mood() -> void:
	_mood = _mood_tier()
	modulate = _base_modulate * MOOD_TINTS[_mood]

## Vui (bậc 2) thì đi nhún nhảy — tâm trạng đọc được từ dáng đi.
func _apply_bob() -> void:
	var bob := 0.0
	if behavior == Behavior.WANDER and _mood == 2 and _sprite.animation == &"run":
		bob = absf(sin(Time.get_ticks_msec() * 0.012)) * 3.0
	_sprite.position.y = _sprite_base_y - bob

# --- Hành vi 3: Kẻ đào ngũ (nhát gan, lòng tin tích luỹ dần) ------------------

func _tick_skittish(delta: float) -> void:
	var distance := _player_distance()
	var threat := _threat_reason() if distance <= flee_radius else ""

	if threat != "":
		if not _scared:
			_emote("alert")
			_bark(FLEE_BARKS[threat], true)
			alarmed.emit(self)
		_scared = true
		_calm_timer = 0.0
		_flee_dir = -1 if _player.global_position.x > global_position.x else 1

	if not _scared:
		if distance <= notice_radius:
			_state = "TIN NGÀI" if _trust() >= TRUST_MAX else "DÈ CHỪNG"
			_stand()
			_face_player()
		elif absf(global_position.x - _origin.x) > 4.0:
			# Lảng về chỗ đứng cũ sau khi bỏ chạy.
			_state = "VỀ CHỖ"
			_walk(1 if _origin.x > global_position.x else -1, walk_speed, delta)
		else:
			_state = "ĐỨNG GÁC"
			_stand()
		return

	# Đang sợ: player đứng yên gần đó đủ lâu thì mới chịu bình tĩnh lại ("đổi lòng tin").
	if distance <= flee_radius and threat == "":
		_calm_timer += delta
		_calm_by_player = true
	elif distance > flee_radius * 1.8:
		_calm_timer += delta * 0.5  # player bỏ đi cũng dần yên tâm, nhưng chậm hơn
		_calm_by_player = false
	else:
		_calm_timer = 0.0
	if _calm_timer >= calm_time:
		_scared = false
		_calm_timer = 0.0
		if _calm_by_player:
			if not _gain_trust():
				_bark("...Được rồi. Ngài không định đánh tôi.", true)
		else:
			_bark("Hú hồn...", true)
		return

	# Chạy ra xa, nhưng không quá `wander_range` để khỏi trôi khỏi sàn hub.
	if _within_leash(_flee_dir):
		_state = "BỎ CHẠY"
		_walk(_flee_dir, walk_speed * 2.2, delta)
	else:
		_state = "TRẤN TĨNH" if _calm_timer > 0.0 else "NÉP GÓC"
		_stand()
		_face_player()

## Lý do player đang doạ NPC ("" = không doạ). Tin hẳn rồi thì chạy ngang không còn đáng sợ,
## chỉ vung kiếm / lướt mới làm hoảng.
func _threat_reason() -> String:
	if _player == null:
		return ""
	if bool(_player.get("is_attacking")):
		return "attack"
	if bool(_player.get("is_dashing")):
		return "dash"
	if _trust() < TRUST_MAX and absf(_player.velocity.x) > THREAT_SPEED:
		return "run"
	return ""

## Lòng tin sống trong GameManager (runtime) để không mất khi NPC sinh lại mỗi lần vào hub.
func _trust() -> int:
	return int(GameManager.npc_trust.get(String(name), 0))

## +1 lòng tin. Trả về true nếu vừa đạt mức tin hẳn (đã bark câu riêng cho mốc đó).
func _gain_trust() -> bool:
	var t := _trust()
	if t >= TRUST_MAX:
		return false
	GameManager.npc_trust[String(name)] = t + 1
	queue_redraw()
	if t + 1 < TRUST_MAX:
		return false
	_emote("alert")
	_bark("Tôi tin ngài rồi, thưa Đức Vua.", true)
	return true

# --- Nghe thấy nhau -----------------------------------------------------------

func _on_neighbour_alarmed(source: Node2D) -> void:
	if _talking or global_position.distance_to(source.global_position) > hear_radius:
		return
	_look_source = source
	_look_timer = LOOK_TIME
	_emote("ask")
	_bark(NEIGHBOUR_BARKS[behavior], true)

# --- Di chuyển / hướng nhìn ---------------------------------------------------

func _min_x() -> float:
	return _origin.x - wander_range

func _max_x() -> float:
	return _origin.x + wander_range

## Còn được phép đi thêm về hướng `dir` không (dây xích quanh vị trí đặt trong scene).
## Bám theo player / bỏ chạy được nới rộng hơn quãng tuần thêm `extra` (mặc định `leash_extra`).
func _within_leash(dir: int, extra: float = -1.0) -> bool:
	var leash := wander_range + (leash_extra if extra < 0.0 else extra)
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

func _on_screen() -> bool:
	return get_viewport_rect().has_point(get_global_transform_with_canvas().origin)

func _world_name(world_id: String) -> String:
	return String(WorldData.get_world(world_id).get("name", ""))

# --- Hiển thị ----------------------------------------------------------------

## Đặt sprite sao cho đáy khung nằm ở gốc (chân), rồi đưa bong bóng + chữ "Nhấn E" + bark
## lên ngay trên đầu — mỗi bộ SpriteFrames cao khác nhau nên không thể để số cứng trong scene.
func _fit_to_frames() -> void:
	var tex := idle_frames.get_frame_texture(&"idle", 0)
	if tex == null:
		return
	var h := float(tex.get_height())
	_head_y = -h
	_sprite_base_y = -h * 0.5
	_sprite.position = Vector2(0, _sprite_base_y)
	_bubble.position = Vector2(10, -h - 6)
	_prompt.offset_top = -h - 30
	_prompt.offset_bottom = -h - 12
	_bark_bottom = -h - 30

## Bật "?" đúng lúc player vừa bước vào `notice_radius`. Trả về player có đang ở gần không.
func _check_notice() -> bool:
	var near := _player_distance() <= notice_radius
	if near and not _noticed:
		_emote("ask")
	_noticed = near
	return near

## Bong bóng cảm xúc ngắn; nhường chỗ cho bong bóng "Hello" lúc đang nói chuyện.
func _emote(kind: String) -> void:
	if _talking:
		return
	_bubble.visible = true
	_bubble.play(kind + "_in")
	_emote_timer = EMOTE_TIME

func _tick_emote(delta: float) -> void:
	if _emote_timer <= 0.0:
		return
	_emote_timer -= delta
	if _emote_timer <= 0.0 and not _talking:
		_bubble.play(String(_bubble.animation).replace("_in", "_out"))

func _on_bubble_animation_finished() -> void:
	if String(_bubble.animation).ends_with("out"):
		_bubble.visible = false

## Câu ngắn nổi trên đầu, tự mờ đi. `urgent` bỏ qua khoảng chống spam (phản ứng với sự kiện
## thật như bị doạ / cảnh báo) — câu lẩm bẩm định kỳ thì không.
func _bark(text: String, urgent: bool = false) -> void:
	if _talking or text == "" or (_bark_gap > 0.0 and not urgent):
		return
	_bark_gap = BARK_GAP
	_bark_label.text = text
	_layout_bark()
	_bark_label.modulate.a = 0.0
	_bark_label.visible = true
	if _bark_tween:
		_bark_tween.kill()
	_bark_tween = create_tween()
	_bark_tween.tween_property(_bark_label, "modulate:a", 1.0, 0.15)
	_bark_tween.tween_interval(BARK_TIME)
	_bark_tween.tween_property(_bark_label, "modulate:a", 0.0, 0.4)
	_bark_tween.tween_callback(_bark_label.hide)

## Khung nền ôm vừa chữ: câu ngắn thì khung hẹp, câu dài thì xuống dòng ở BARK_MAX_WIDTH.
## Chiều cao để 0 — Label tự nới tới chiều cao tối thiểu, và `grow_vertical = BEGIN`
## trong scene làm nó nới lên trên nên đáy khung luôn nằm ngay trên đầu NPC.
func _layout_bark() -> void:
	var font := _bark_label.get_theme_font(&"font")
	var font_size := _bark_label.get_theme_font_size(&"font_size")
	var style := _bark_label.get_theme_stylebox(&"normal")
	var w := font.get_string_size(_bark_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	w = minf(w + style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) + 2.0, BARK_MAX_WIDTH)
	_bark_label.offset_left = -w * 0.5
	_bark_label.offset_right = w * 0.5
	_bark_label.offset_bottom = _bark_bottom
	_bark_label.offset_top = _bark_bottom

func _hide_bark() -> void:
	if _bark_tween:
		_bark_tween.kill()
	_bark_label.visible = false

func _update_debug() -> void:
	_debug_label.visible = debug_view
	if debug_view:
		var text := "%s\n%s" % [speaker, _state]
		match behavior:
			Behavior.WANDER:
				text += "\ntâm trạng %d/2" % _mood
			Behavior.SKITTISH:
				text += "\nlòng tin %d/%d" % [_trust(), TRUST_MAX]
		_debug_label.text = text
		queue_redraw()
	elif _debug_drawn:
		queue_redraw()

## Vẽ bằng `_draw` thay vì thêm node: thanh lòng tin (SKITTISH) và, khi bật F3, các bán kính
## nhận biết + quãng đi tuần.
func _draw() -> void:
	_debug_drawn = debug_view
	if behavior == Behavior.SKITTISH:
		var trust := _trust()
		for i in TRUST_MAX:
			var p := Vector2((i - 1) * 8.0, _head_y - 4.0)
			if i < trust:
				draw_circle(p, 2.5, Color(1.0, 0.82, 0.3))
			else:
				draw_arc(p, 2.5, 0.0, TAU, 12, Color(1, 1, 1, 0.55), 1.0)
	if not debug_view:
		return
	draw_arc(Vector2.ZERO, notice_radius, 0.0, TAU, 48, Color(0.4, 0.8, 1.0, 0.7), 1.0)
	match behavior:
		Behavior.WANDER:
			draw_arc(Vector2.ZERO, greet_radius, 0.0, TAU, 64, Color(1.0, 0.9, 0.3, 0.5), 1.0)
			var left := _min_x() - global_position.x
			var right := _max_x() - global_position.x
			draw_line(Vector2(left, 2), Vector2(right, 2), Color(0.5, 1.0, 0.5, 0.8), 2.0)
		Behavior.SKITTISH:
			draw_arc(Vector2.ZERO, flee_radius, 0.0, TAU, 48, Color(1.0, 0.35, 0.35, 0.8), 1.0)

# --- Thoại --------------------------------------------------------------------

## Kẻ đào ngũ đang hoảng thì không nói chuyện được — đó chính là câu đố nhỏ của NPC này.
func _can_talk() -> bool:
	return not (behavior == Behavior.SKITTISH and _scared)

func _update_prompt() -> void:
	if not _near:
		_prompt.visible = false
		return
	_prompt.visible = true
	_prompt.text = "Nhấn E" if _can_talk() else "Đứng yên..."

func _start_dialogue() -> void:
	# Hai NPC đứng sát nhau cùng bắt một cú nhấn: chỉ NPC mở được hộp thoại mới được
	# coi là đang nói, NPC kia không được bật bong bóng / đứng đơ chờ `finished`.
	if not Dialogue.open(_build_lines(), speaker):
		return
	_talking = true
	_emote_timer = 0.0
	_prompt.visible = false
	_hide_bark()
	_face_player()
	if behavior == Behavior.WANDER:
		_apply_mood()  # tâm trạng có thể đã đổi kể từ lần nói chuyện trước
	_bubble.visible = true
	_bubble.play("in")

func _build_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for line: String in [line_1, line_2, line_3]:
		if line != "":
			lines.append(line)
	if behavior == Behavior.SKITTISH and _trust() >= TRUST_MAX:
		lines.append("Ngài là người tốt. Tôi kể hết những gì tôi biết.")
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

## Mọi NPC đều nghe `Dialogue.finished`, chỉ NPC đang nói mới thu bong bóng về. Ẩn bong
## bóng nằm ở `_on_bubble_animation_finished` thay vì `await` — await sẽ bắt nhầm anim
## "in" của lần nói kế tiếp nếu player mở lại thoại trước khi "out" chạy xong.
func _on_dialogue_finished() -> void:
	if not _talking:
		return
	_talking = false
	_bubble.play("out")
	# Chịu nghe kẻ đào ngũ kể hết chuyện cũng là một lần tạo lòng tin.
	if behavior == Behavior.SKITTISH:
		_gain_trust()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false
