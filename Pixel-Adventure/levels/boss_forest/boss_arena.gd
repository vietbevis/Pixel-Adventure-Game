extends LevelBase
## Arena boss: không có cờ đích — thắng khi boss chết. Kế thừa LevelBase (spawn,
## camera, pause, rơi hố). Bố cục terrain tạm lấy từ level_1, chỉnh trong editor.

func _ready() -> void:
	super()
	Events.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(_boss_id: String) -> void:
	await get_tree().create_timer(1.4).timeout
	if is_instance_valid(player) and not player.is_dead:
		player.win()
