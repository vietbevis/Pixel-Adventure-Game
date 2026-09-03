extends LevelBase
## Arena boss: không có cờ đích — thắng khi boss chết. Kế thừa LevelBase (spawn,
## camera, pause, rơi hố). Bố cục terrain lấy nền castle, chỉnh trong editor.

func _ready() -> void:
	super()
	Events.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(boss_id: String) -> void:
	if boss_id != GameIds.BOSS_FOREST:
		return
	# time_scale có thể còn 0.05 từ hit-stop của đòn kết liễu → reset trước khi chờ.
	Engine.time_scale = 1.0
	await get_tree().create_timer(1.4, true, false, true).timeout
	if is_instance_valid(player) and not player.is_dead:
		player.win()
