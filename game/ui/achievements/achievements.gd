## Màn Thành tựu: liệt kê 6 mốc + trạng thái đạt/chưa. Vào từ biển "Thành tựu" ở hub.
extends Control

@onready var list_box: VBoxContainer = $CenterContainer/DialogPanel/VBoxContainer/Scroll/ListBox
@onready var back_button: Button = $CenterContainer/DialogPanel/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	back_button.grab_focus()
	_populate()

func _populate() -> void:
	for child in list_box.get_children():
		child.queue_free()
	for id: String in Achievements.ACHIEVEMENTS:
		var got := SaveManager.has_achievement(id)
		var row := Label.new()
		row.text = ("[✓]  " if got else "[  ]  ") + Achievements.ACHIEVEMENTS[id]
		row.modulate = Color(1, 1, 1) if got else Color(0.55, 0.55, 0.6)
		list_box.add_child(row)

func _on_back() -> void:
	SceneTransition.goto("res://levels/hub/hub.tscn")
