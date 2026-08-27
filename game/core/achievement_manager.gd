extends Node
## Autoload: thành tựu. Nghe `Events`, khi đủ điều kiện thì `SaveManager.unlock_achievement`
## + `Events.achievement_unlocked` (Toast hiện thông báo). Giữ nhỏ — 6 mốc, không có UI riêng.

const ACHIEVEMENTS := {
	"first_steps": "Bước Chân Đầu Tiên",
	"the_dash": "Lướt Như Gió",
	"king_returns": "Vua Trở Về",
	"royal_seal": "Vương Ấn Toàn Vẹn",
	"pig_purge": "Sạch Bóng Heo",
	"the_crown": "Vương Miện",
}
const PIG_PURGE_TARGET := 40

var _kills: int = 0

func _ready() -> void:
	Events.level_completed.connect(_on_level_completed)
	Events.ability_unlocked.connect(_on_ability_unlocked)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.max_hp_increased.connect(func(_m: int) -> void: _grant("royal_seal"))
	Events.enemy_died.connect(_on_enemy_died)

func _on_level_completed(level_id: String) -> void:
	if level_id == "level_1":
		_grant("first_steps")
	elif level_id == "level_6":
		_grant("the_crown")

func _on_ability_unlocked(id: String) -> void:
	if id == "dash":
		_grant("the_dash")

func _on_boss_defeated(boss_id: String) -> void:
	if boss_id == "forest_boss":
		_grant("king_returns")

func _on_enemy_died(_enemy: Node, _pos: Vector2) -> void:
	_kills += 1
	if _kills >= PIG_PURGE_TARGET:
		_grant("pig_purge")

func _grant(id: String) -> void:
	if not ACHIEVEMENTS.has(id) or SaveManager.has_achievement(id):
		return
	SaveManager.unlock_achievement(id)
	Events.achievement_unlocked.emit(id, ACHIEVEMENTS[id])
