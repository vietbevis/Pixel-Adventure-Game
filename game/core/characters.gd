class_name CharacterData
extends RefCounted
## Nhân vật chơi được. Mỗi nhân vật là 1 folder trong player/sprites/<Tên>/ chứa
## các spritesheet + <ten>_frames.tres (SpriteFrames bake sẵn) + portrait.png.
## Thêm nhân vật = thêm folder + 1 entry vào CHARACTERS + tên vào NAMES.

## Thứ tự hiện ở màn chọn nhân vật.
const NAMES: Array[String] = ["King", "Captain"]

## display: tên hiển thị. offset: dịch AnimatedSprite2D cho khớp chân với collision
## dùng chung của player (kích thước frame mỗi nhân vật khác nhau) — canh trong editor.
const CHARACTERS := {
	"King": {
		"display": "King",
		"offset": Vector2(0, 6),
	},
	"Captain": {
		"display": "Captain",
		"offset": Vector2(0, 9),
	},
}

## 4 nhân vật Pixel Adventure cũ (Ninja Frog...) không có animation attack nên đã
## rút khỏi roster khi game chuyển sang hướng combat; folder sprite vẫn giữ để có
## thể làm skin unlock sau. Xem ROADMAP.md Phase 1.5.

static func get_folder(character_name: String) -> String:
	return "res://player/sprites/%s/" % character_name

## Đường dẫn SpriteFrames đã bake của nhân vật (player/sprites/<Tên>/<ten>_frames.tres).
static func get_frames_path(character_name: String) -> String:
	var file_name := character_name.to_lower().replace(" ", "_") + "_frames.tres"
	return get_folder(character_name) + file_name

static func get_portrait_path(character_name: String) -> String:
	return get_folder(character_name) + "portrait.png"

static func get_offset(character_name: String) -> Vector2:
	if CHARACTERS.has(character_name):
		return CHARACTERS[character_name].get("offset", Vector2.ZERO)
	return Vector2.ZERO

static func get_display(character_name: String) -> String:
	if CHARACTERS.has(character_name):
		return CHARACTERS[character_name]["display"]
	return character_name
