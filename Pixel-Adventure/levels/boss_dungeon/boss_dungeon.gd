extends LevelBase
## Arena trùm Hầm Ngục: không cờ đích — thắng khi Warden chết. Giống boss_forest.

func _ready() -> void:
	super()
	Events.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated(boss_id: String) -> void:
	if boss_id != "dungeon_boss":
		return
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(player) and not player.is_dead:
		player.win()
