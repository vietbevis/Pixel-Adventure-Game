extends Area2D

@export var ability_id: String = "dash"

var _taken: bool = false

@onready var _polygon: Polygon2D = $Polygon2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if SaveManager.is_ability_unlocked(ability_id):
		queue_free()
		return
	
	body_entered.connect(_on_body_entered)
	
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_polygon, "modulate:a", 0.3, 0.8)
	tween.tween_property(_polygon, "modulate:a", 1.0, 0.8)

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	
	_taken = true
	SaveManager.unlock_ability(ability_id)
	Events.ability_unlocked.emit(ability_id)
	_collision.set_deferred("disabled", true)
	
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_polygon, "scale", Vector2(1.8, 1.8), 0.18)
	tween.tween_property(_polygon, "modulate:a", 0.0, 0.18)
	tween.tween_property(_polygon, "position:y", _polygon.position.y - 12.0, 0.18)
	
	await tween.finished
	queue_free()
