extends Node
## Autoload: event bus toàn cục. CHỈ chứa signal — không giữ state, không có logic.
##
## Quy tắc: hệ thống gameplay chỉ `Events.emit_signal(...)` (hoặc `Events.xxx.emit(...)`)
## mà KHÔNG cần biết ai đang lắng nghe. HUD, SaveManager, achievements... `connect`
## vào đây. Nhờ vậy gameplay không phụ thuộc trực tiếp vào UI/Save.
##
## Xem ROADMAP.md mục 5.5.

# --- Player ---
signal player_health_changed(current: int, maximum: int)
## Số tim tối đa vừa tăng vĩnh viễn (heart container). new_max = max_hp mới.
signal max_hp_increased(new_max: int)
signal player_damaged(amount: int)
signal player_died

# --- Enemy / Boss ---
signal enemy_died(enemy: Node, position: Vector2)
signal boss_health_changed(current: int, maximum: int)
## Tên hiển thị + máu tối đa của boss — boss phát khi vào trận để thanh máu đặt nhãn đúng.
signal boss_intro(display_name: String, max_hp: int)
signal boss_phase_changed(phase: int)
signal boss_defeated(boss_id: String)

# --- Collectible / Progression ---
signal fruit_collected(total: int)
signal collectible_collected(id: String, kind: String)
signal checkpoint_activated(position: Vector2)
signal ability_unlocked(id: String)
signal achievement_unlocked(id: String, title: String)

# --- Flow ---
signal level_started(level_id: String)
signal level_completed(level_id: String)
