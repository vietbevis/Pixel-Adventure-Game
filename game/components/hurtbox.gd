class_name Hurtbox
extends Area2D
## Vùng NHẬN sát thương. Bên chủ động: phát hiện Hitbox chồng lên và chuyển sát
## thương vào HealthComponent của owner.
##
## Gán `health_component` trong Inspector (từ .tscn). Collision mask phải trỏ tới
## layer chứa Hitbox của phe địch (player_hitbox / enemy_hitbox — xem CONTRIBUTING.md).

## HealthComponent sẽ nhận sát thương khi Hurtbox này trúng Hitbox.
@export var health_component: HealthComponent

## Phát kèm Hitbox vừa trúng, để owner xử lý knockback / hiệu ứng.
signal hurt(hitbox: Hitbox)

func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox and health_component:
		health_component.damage(area.damage, area)
		hurt.emit(area)
