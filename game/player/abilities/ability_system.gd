class_name AbilitySystem
extends Node
## Node con của Player. Giữ trạng thái "ability nào đã mở" (query SaveManager).
## Logic từng ability nằm trong player.gd (dash) — hiện chỉ 1 ability nên chưa cần
## tách module. Xem core/progression.gd (nơi mở khoá) + ROADMAP Phase 5.

## Bật để test khi chưa mở ability. CHỈ có tác dụng trong bản debug (chạy từ editor) —
## export release luôn bỏ qua, tránh lỡ commit `true` rồi ship bản mở hết ability.
@export var dev_unlock_all: bool = false

func is_unlocked(id: String) -> bool:
	if dev_unlock_all and OS.is_debug_build():
		return true
	return SaveManager.is_ability_unlocked(id)
