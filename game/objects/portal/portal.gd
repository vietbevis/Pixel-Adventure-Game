extends Area2D
## Cổng vào 1 world từ hub. Player đứng trong vùng + bấm `interact` (E / nút touch)
## → cửa mở (animation) → player bước vào → đổi màn. World khoá thì cửa xám + 🔒,
## không mở được (xem core/world_data.gd).

@export var world_id: String = "forest"

@onready var _name_label: Label = $NameLabel
@onready var _prompt: Label = $Prompt
@onready var _door: AnimatedSprite2D = $Door
@onready var _glow: PointLight2D = $Glow

var _player_near: bool = false
var _entering: bool = false

func _ready() -> void:
	_prompt.visible = false
	_door.play("closed")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh()
	# Hạ boss ở world khác có thể mở world này.
	Events.boss_defeated.connect(func(_id: String) -> void: _refresh())

func _process(_delta: float) -> void:
	if _entering or Dialogue.is_blocking_interact():
		return
	if _player_near and _is_open() and Input.is_action_just_pressed("interact"):
		_enter()

func _is_open() -> bool:
	return WorldData.is_world_unlocked(world_id)

func _refresh() -> void:
	var unlocked := _is_open()
	var wname: String = WorldData.get_world(world_id).get("name", world_id)
	_name_label.text = wname if unlocked else "%s  🔒" % wname
	_door.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.56)
	_glow.visible = unlocked
	if _player_near:
		_prompt.visible = unlocked

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_prompt.visible = _is_open()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_prompt.visible = false

func _enter() -> void:
	_entering = true
	_prompt.visible = false

	_door.play("opening")
	await _door.animation_finished
	_door.play("open")

	var lvl := WorldData.first_level(world_id)
	GameManager.current_world = world_id
	GameManager.start_new_run(lvl)

	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("play_enter_door"):
		var wait: float = player.call("play_enter_door")
		if wait > 0.0:
			await get_tree().create_timer(wait).timeout
	SceneTransition.goto(LevelData.get_scene_path(lvl))
