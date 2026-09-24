extends LevelBase
## Hub / làng: đi bộ, chọn world qua Portal, biển "Levels" để chơi lẻ. Không có
## enemy / cờ đích / checkpoint. NPC + thoại thêm ở Phase 7b.

func _enter_tree() -> void:
	GameManager.has_checkpoint = false
	GameManager.current_level_id = "hub"
	super()
