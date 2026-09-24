extends CPUParticles2D
## Bụi 1 nhịp (dash, tiếp đất...). Owner set `scale.x` để đổi hướng phun.
## Tự huỷ sau khi phun xong.

func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.2).timeout
	queue_free()
