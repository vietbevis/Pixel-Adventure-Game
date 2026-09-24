class_name StompBox
extends Area2D
## Vùng trên đầu quái: player rơi từ trên xuống chạm vào → quái mất máu, player nảy lên
## (cú "đạp đầu" kinh điển). Đặt cao hơn Hitbox chạm-là-đau vài px để khi rơi, player
## chạm StompBox trước — rồi Hitbox của quái được tắt một nhịp để không trừ tim ngược lại.
## Mask = layer "player" (2). Tự tìm HealthComponent / Hitbox anh em nếu không gán.

@export var health_component: HealthComponent
@export var hitbox: Hitbox
@export var damage: int = 1

func _ready() -> void:
	if health_component == null:
		health_component = get_parent().get_node_or_null(^"HealthComponent")
	if hitbox == null:
		hitbox = get_parent().get_node_or_null(^"Hitbox")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or not body.has_method("bounce"):
		return
	var falling: bool = body.velocity.y > 0.0
	if not falling or body.global_position.y > global_position.y:
		return
	if hitbox:
		hitbox.disable()
		get_tree().create_timer(0.25).timeout.connect(func() -> void:
			if is_instance_valid(hitbox) and health_component and health_component.is_alive():
				hitbox.enable())
	body.bounce()
	if health_component:
		health_component.damage(damage, self)
