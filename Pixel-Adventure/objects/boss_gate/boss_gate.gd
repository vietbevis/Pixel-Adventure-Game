extends StaticBody2D
## Cửa arena boss: đóng sẵn (chặn lối ra), mở khi `Events.boss_defeated`.
## Collision layer `world` (1) để player không đi xuyên.

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	_sprite.play("closed")
	Events.boss_defeated.connect(_open)

func _open(_boss_id: String) -> void:
	_shape.set_deferred("disabled", true)
	_sprite.play("opening")
