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
const FOREST_SECRETS: Array[String] = ["diamond_forest_1", "diamond_forest_2", "diamond_forest_3"]
const MAX_HP_BASE := 3

## Chuỗi mục tiêu của người chơi, theo đúng thứ tự phải hoàn thành. Mỗi mốc:
##   check — hàm trả về true khi mốc này ĐÃ xong
##   world — world_id mà người chơi cần tới (NPC Cố vấn quay mặt về portal này)
##   text  — câu mô tả mục tiêu
## Lưu ý: Dash KHÔNG đến từ boss mà nhặt ở `objects/ability_relic/` cuối level_2,
## nên mốc đầu tiên nói về việc vượt hết Rừng chứ không phải hạ boss.
const OBJECTIVES: Array[Dictionary] = [
	{
		"world": "forest",
		"text": "Băng qua Rừng Ranh Giới. Di vật Lướt nằm ở cuối rừng, và Cổng Lâu Đài chỉ mở khi ngài vượt hết khu Rừng.",
	},
	{
		"world": "castle",
		"text": "Vào Lâu Đài Thất Thủ, hạ Vua Heo. Hạ được hắn thì đường xuống Hầm Ngục Cổ mới lộ ra.",
	},
	{
		"world": "dungeon",
		"text": "Xuống Hầm Ngục Cổ, hạ Cai Ngục — Vương Miện đang nằm trong tay hắn.",
	},
]
const OBJECTIVE_DONE := {
	"world": "",
	"text": "Vương Miện đã trở về. Ngài lại là Vua, thưa Đức Vua.",
}

## Mục tiêu kế tiếp suy ra từ save. Dùng bởi NPC Cố vấn (hub) và màn Tiến trình —
## giữ ở đây để hai nơi không tự suy luận tiến trình theo hai kiểu khác nhau.
func next_objective() -> Dictionary:
	if not SaveManager.is_level_completed("level_2"):
		return OBJECTIVES[0]
	if not SaveManager.is_boss_defeated("forest_boss"):
		return OBJECTIVES[1]
	if not SaveManager.is_boss_defeated("dungeon_boss"):
		return OBJECTIVES[2]
	return OBJECTIVE_DONE

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
	Events.max_hp_increased.emit(MAX_HP_BASE + SaveManager.get_max_hp_bonus())
