extends Area2D
## Quạt đẩy: cột gió phía trên miệng quạt nâng người chơi lên (chống lại trọng lực)
## tới một tốc độ bay tối đa. Không gây sát thương. Dùng cho các đoạn leo dọc.

@export var lift_accel: float = 1400.0
## Tốc độ bay lên tối đa (px/s, hướng lên nên âm khi so sánh).
@export var max_rise_speed: float = 180.0
@export var active: bool = true

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _players: Array[Node] = []

func _ready() -> void:
	_sprite.play("on" if active else "off")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not active:
		return
	for body: Node in _players:
		var player := body as CharacterBody2D
		if player and player.velocity.y > -max_rise_speed:
			player.velocity.y = maxf(player.velocity.y - lift_accel * delta, -max_rise_speed)

func set_active(value: bool) -> void:
	active = value
	_sprite.play("on" if active else "off")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body not in _players:
		_players.append(body)

func _on_body_exited(body: Node2D) -> void:
	_players.erase(body)
