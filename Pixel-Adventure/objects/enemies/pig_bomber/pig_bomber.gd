extends EnemyBase

const BOMB := preload("res://objects/bomb/bomb.tscn")

@export var throw_speed: float = 150.0

var _thrown: bool = false

func _start_attack() -> void:
	_state = State.ATTACK
	velocity.x = 0.0
	_attack_cd = stats.attack_cooldown
	_play(&"throw")

func _on_frame_changed() -> void:
	if _state == State.ATTACK and sprite.animation == &"throw" and sprite.frame >= 3 and not _thrown:
		_thrown = true
		var b := BOMB.instantiate()
		get_parent().add_child(b)
		b.global_position = global_position + Vector2(0, -8)
		var dir := signf((_player.global_position.x if _player else global_position.x + _facing) - global_position.x)
		b.launch(Vector2(dir * throw_speed, -190.0))
	super()

func _on_anim_finished() -> void:
	if sprite.animation == &"throw":
		_thrown = false
		if _state == State.ATTACK:
			if is_instance_valid(_player):
				_state = State.CHASE
			else:
				_state = State.RETURN if behavior == Behavior.GUARD else State.PATROL
	super()
