class_name Hurtbox
extends Area2D
## Vùng NHẬN sát thương. Bên chủ động: phát hiện Hitbox chồng lên và chuyển sát
## thương vào HealthComponent của owner.
##
## Gán `health_component` trong Inspector (từ .tscn). Collision mask phải trỏ tới
## layer chứa nguồn sát thương của phe địch (player_hitbox / enemy_hitbox — xem
## CONTRIBUTING.md). Nguồn có thể là node `Hitbox` (đọc `damage`) hoặc 1 Area2D
## bẫy thường (dùng `plain_hazard_damage`).

@export var health_component: HealthComponent
## Sát thương khi nguồn chồng lên là 1 Area2D bẫy thường (không phải node Hitbox).
@export var plain_hazard_damage: int = 1

## Phát kèm Area2D nguồn (Hitbox hoặc bẫy) để owner xử lý knockback / hiệu ứng.
## CHỈ phát khi đòn thực sự trừ được máu (không phát lúc đang bất tử / đã chết).
signal hurt(source: Area2D)

func _ready() -> void:
	monitoring = true
	monitorable = false
	# Không gán trong Inspector thì tự tìm HealthComponent anh em (bố cục chuẩn:
	# HealthComponent + Hurtbox cùng là con của owner).
	if health_component == null:
		health_component = get_parent().get_node_or_null(^"HealthComponent")
	if health_component == null:
		push_error("Hurtbox %s: không tìm thấy HealthComponent — vùng nhận đòn sẽ trơ." % get_path())
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	if health_component:
		health_component.invincibility_ended.connect(_on_invincibility_ended)

func _on_area_entered(area: Area2D) -> void:
	_apply(area)

func _on_area_exited(_area: Area2D) -> void:
	pass

## Khi hết i-frame mà player VẪN còn nằm trong 1 hazard (gai/cưa đứng yên) → trúng lại,
## thay vì phải rời rồi vào lại mới ăn đòn tiếp.
func _on_invincibility_ended() -> void:
	for area in get_overlapping_areas():
		if _apply(area):
			return

## Trả về true nếu đòn thực sự trừ được máu.
func _apply(area: Area2D) -> bool:
	if not health_component:
		return false
	var amount := (area as Hitbox).damage if area is Hitbox else plain_hazard_damage
	var landed := health_component.damage(amount, area)
	if landed:
		hurt.emit(area)
	return landed
