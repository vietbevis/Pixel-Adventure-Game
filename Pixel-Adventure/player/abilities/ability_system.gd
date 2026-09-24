class_name AbilitySystem
extends Node
## Node con của Player. Giữ trạng thái "ability nào đã mở" (query SaveManager).
## Logic từng ability nằm trong player.gd (dash) — hiện chỉ 1 ability nên chưa cần
## tách module. Xem core/progression.gd (nơi mở khoá) + ROADMAP Phase 5.

## Bật để test khi chưa thắng boss.
@export var dev_unlock_all: bool = false

func is_unlocked(id: String) -> bool:
	return dev_unlock_all or SaveManager.is_ability_unlocked(id)
