class_name Hurtbox
extends Area2D
## Vùng NHẬN sát thương. Bên chủ động: phát hiện Hitbox chồng lên và chuyển sát
## thương vào HealthComponent của owner.
##
## Gán `health_component` trong Inspector (từ .tscn). Collision mask phải trỏ tới
## layer chứa nguồn sát thương của phe địch (player_hitbox / enemy_hitbox — xem
## CONTRIBUTING.md). Nguồn có thể là node `Hitbox` (đọc `damage`) hoặc 1 Area2D
## bẫy thường (mặc định sát thương 1).

@export var health_component: HealthComponent

## Phát kèm Area2D nguồn (Hitbox hoặc bẫy) để owner xử lý knockback / hiệu ứng.
signal hurt(source: Area2D)

func _ready() -> void:
	monitoring = true
	monitorable = false
	# Không gán trong Inspector thì tự tìm HealthComponent anh em (bố cục chuẩn:
	# HealthComponent + Hurtbox cùng là con của owner).
	if health_component == null:
		health_component = get_parent().get_node_or_null(^"HealthComponent")
	if health_component == null:
		push_warning("Hurtbox %s: không tìm thấy HealthComponent" % get_path())
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if not health_component:
		return
	var amount := (area as Hitbox).damage if area is Hitbox else 1
	health_component.damage(amount, area)
	hurt.emit(area)
