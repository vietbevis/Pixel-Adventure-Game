extends Area2D
## Cổng vào 1 world từ hub. Player đứng trong vùng + bấm `interact` (E / nút touch)
## → vào màn đầu world, nếu world đã mở khoá (xem core/world_data.gd). Khoá thì xám + 🔒.

@export var world_id: String = "forest"

@onready var _name_label: Label = $NameLabel
@onready var _prompt: Label = $Prompt

var _player_near: bool = false

func _ready() -> void:
	_prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_refresh()
	# Hạ boss ở world khác có thể mở world này.
	Events.boss_defeated.connect(func(_id: String) -> void: _refresh())

func _process(_delta: float) -> void:
	if _player_near and _is_open() and Input.is_action_just_pressed("interact"):
		_enter()

func _is_open() -> bool:
	return WorldData.is_world_unlocked(world_id)

func _refresh() -> void:
	var wname: String = WorldData.get_world(world_id).get("name", world_id)
	_name_label.text = wname if _is_open() else "%s  🔒" % wname
	modulate = Color.WHITE if _is_open() else Color(0.55, 0.55, 0.6)
	if _player_near:
		_prompt.visible = _is_open()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_prompt.visible = _is_open()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		_prompt.visible = false

func _enter() -> void:
	var lvl := WorldData.first_level(world_id)
	GameManager.current_world = world_id
	GameManager.start_new_run(lvl)
	SceneTransition.goto(LevelData.get_scene_path(lvl))
