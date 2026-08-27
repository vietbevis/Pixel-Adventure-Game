extends Node
## Autoload: event bus toàn cục. CHỈ chứa signal — không giữ state, không có logic.
##
## Quy tắc: hệ thống gameplay chỉ `Events.emit_signal(...)` (hoặc `Events.xxx.emit(...)`)
## mà KHÔNG cần biết ai đang lắng nghe. HUD, SaveManager, achievements... `connect`
## vào đây. Nhờ vậy gameplay không phụ thuộc trực tiếp vào UI/Save.
##
## Xem ROADMAP.md mục 5.5. Ở Phase 0 chưa nơi nào emit/connect — đây là khung rỗng
## để các phase sau cắm vào mà không phải refactor chéo.

# Các signal bên dưới chưa được emit ở Phase 0 (cố ý). Tắt cảnh báo unused cho cả file.
@warning_ignore_start("unused_signal")

# --- Player ---
signal player_health_changed(current: int, maximum: int)
signal player_damaged(amount: int)
signal player_healed(amount: int)
signal player_died
signal player_respawned(position: Vector2)

# --- Enemy / Boss ---
signal enemy_died(enemy: Node, position: Vector2)
signal boss_health_changed(current: int, maximum: int)
signal boss_phase_changed(phase: int)
signal boss_defeated(boss_id: String)

# --- Collectible / Progression ---
signal fruit_collected(total: int)
signal collectible_collected(id: String, kind: String)
signal checkpoint_activated(position: Vector2)
signal ability_unlocked(id: String)

# --- Flow ---
signal level_started(level_id: String)
signal level_completed(level_id: String)

@warning_ignore_restore("unused_signal")
