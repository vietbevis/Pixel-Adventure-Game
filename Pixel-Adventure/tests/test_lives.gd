extends SceneTree
## Chạy: tests/run_tests.sh tests/test_lives.gd
## Hồi quy: đã chạm checkpoint thì vẫn phải thua được khi hết mạng (trước đây hồi sinh vô hạn).

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS ", name)
	else:
		_fails += 1
		printerr("FAIL ", name)


func wait_ms(ms: int) -> void:
	var end := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < end:
		await process_frame


func find_checkpoint(node: Node) -> Node:
	var script: Script = node.get_script()
	if script and script.resource_path == "res://objects/checkpoint/checkpoint.gd":
		return node
	for child in node.get_children():
		var found := find_checkpoint(child)
		if found:
			return found
	return null


func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.start_new_run("level_1")

	var level: Node = load("res://levels/level_1/level_1.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await wait_ms(200)
	var player: CharacterBody2D = level.get_node("Player")
	var health: HealthComponent = player.health
	var hud_lives: Label = level.find_child("LivesLabel", true, false)

	check(gm.lives == 3, "new run starts with 3 lives")
	check(hud_lives != null and hud_lives.visible and hud_lives.text == "Mạng: x3", "HUD shows lives")

	# Chết trước checkpoint: còn mạng → bung lại ở đầu màn, không Game Over.
	var start: Vector2 = gm.respawn_position
	player.global_position += Vector2(40, 0)
	health.damage(health.hp)
	await wait_ms(600)
	check(gm.lives == 2 and not player.is_dead and health.hp == health.max_hp, "death without checkpoint -> respawn at start")
	check(player.global_position.distance_to(start) < 24.0, "respawned at StartMarker")
	await wait_ms(1100)  # hết i-frame sau hồi sinh

	var cp: Node = find_checkpoint(level)
	check(cp != null, "level_1 has a checkpoint")
	cp._on_body_entered(player)
	check(gm.has_checkpoint and health.hp == health.max_hp and gm.lives == 2, "checkpoint heals, keeps lives")

	health.damage(health.hp)
	await wait_ms(600)
	check(gm.lives == 1 and not player.is_dead, "death after checkpoint with lives left -> respawn")
	check(player.global_position.distance_to(cp.global_position) < 24.0, "respawned at checkpoint")
	await wait_ms(1100)

	health.damage(health.hp)
	await wait_ms(600)
	check(gm.lives == 0 and player.is_dead, "last life lost -> no respawn even with checkpoint")
	check(gm.last_result == "lose", "last life lost -> lose")
	await wait_ms(2500)
	check(current_scene != null and current_scene.scene_file_path == "res://ui/end_screen/end_screen.tscn", "last life lost -> end screen")

	var arena: Node = load("res://levels/boss_forest/boss_forest.tscn").instantiate()
	check(arena.max_lives == 1, "boss_forest keeps one life")
	arena.free()
	arena = load("res://levels/boss_dungeon/boss_dungeon.tscn").instantiate()
	check(arena.max_lives == 1, "boss_dungeon keeps one life")
	arena.free()

	print("ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)
