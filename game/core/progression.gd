extends Node
## Autoload: quy tắc tiến trình — thắng boss nào thì mở ability/khu vực gì.
## Nghe `Events`, ghi qua `SaveManager`. Gameplay không tự biết "boss X → dash".
## Phase 6 sẽ mở rộng (world unlock, continue point...).

## boss_id -> ability id được mở khi thắng boss đó.
## Dash KHÔNG còn từ boss — giờ nhặt ở `objects/ability_relic/` cuối Rừng (level_2).
## Hạ King Pig chỉ mark defeated → mở world Hầm Ngục (WorldData.unlock_boss).
## Ability #2 (boss Hầm Ngục) sẽ thêm vào đây ở v1.1.
const BOSS_REWARDS := {}

## Nhặt đủ toàn bộ Diamond của Forest → +1 tim tối đa (heart container).
## Danh sách + máu gốc: xem core/game_ids.gd (nguồn duy nhất).
const FOREST_SECRETS := GameIds.FOREST_SECRETS

func _ready() -> void:
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.collectible_collected.connect(_on_collectible_collected)

func _on_boss_defeated(boss_id: String) -> void:
	SaveManager.mark_boss_defeated(boss_id)
	if not BOSS_REWARDS.has(boss_id):
		return
	var ability: String = BOSS_REWARDS[boss_id]
	if SaveManager.is_ability_unlocked(ability):
		return
	SaveManager.unlock_ability(ability)
	Events.ability_unlocked.emit(ability)

## Nhặt Diamond: khi đủ trọn bộ Forest và chưa từng nhận thưởng → +1 tim tối đa.
func _on_collectible_collected(_id: String, kind: String) -> void:
	if kind != "diamond" or SaveManager.get_max_hp_bonus() > 0:
		return
	for secret_id: String in FOREST_SECRETS:
		if not SaveManager.is_secret_collected(secret_id):
			return
	SaveManager.add_max_hp_bonus(1)
	Events.max_hp_increased.emit(GameIds.PLAYER_BASE_HP + SaveManager.get_max_hp_bonus())
