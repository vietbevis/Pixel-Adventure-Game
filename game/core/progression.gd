extends Node
## Autoload: quy tắc tiến trình — thắng boss nào thì mở ability/khu vực gì.
## Nghe `Events`, ghi qua `SaveManager`. Gameplay không tự biết "boss X → dash".
## Phase 6 sẽ mở rộng (world unlock, continue point...).

## boss_id -> ability id được mở khi thắng boss đó.
const BOSS_REWARDS := {
	"forest_boss": "dash",
}

func _ready() -> void:
	Events.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(boss_id: String) -> void:
	if not BOSS_REWARDS.has(boss_id):
		return
	var ability: String = BOSS_REWARDS[boss_id]
	if SaveManager.is_ability_unlocked(ability):
		return
	SaveManager.unlock_ability(ability)
	Events.ability_unlocked.emit(ability)
