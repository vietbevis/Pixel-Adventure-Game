class_name GameIds
extends RefCounted
## Nguồn DUY NHẤT cho các hằng/id dùng chéo nhiều hệ thống — tránh lệch chuỗi
## (vd id boss ghi 2 kiểu ở 2 file rồi "world không bao giờ mở" mà không báo lỗi).
## Không autoload — dùng như LevelData / WorldData (class_name tĩnh).

## Máu tối đa GỐC của player. Phải khớp HealthComponent.max_hp mặc định trên player.tscn.
const PLAYER_BASE_HP: int = 3

## Ability ids (khớp InputMap action + SaveManager.unlocked_abilities).
const ABILITY_DASH: String = "dash"

## Boss ids — PHẢI khớp thuộc tính `boss_id` trong king_pig.tscn / warden.tscn.
const BOSS_FOREST: String = "forest_boss"
const BOSS_DUNGEON: String = "dungeon_boss"

## 3 mảnh Vương Ấn (diamond) giấu trong Rừng. Nhặt đủ 3 → +1 tim tối đa.
const FOREST_SECRETS: Array[String] = [
	"diamond_forest_1", "diamond_forest_2", "diamond_forest_3",
]
