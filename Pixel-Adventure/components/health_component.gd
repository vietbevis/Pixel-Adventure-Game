class_name HealthComponent
extends Node
## Component máu tái sử dụng cho Player, Enemy, Boss.
##
## Thuần logic: KHÔNG biết tới Events, UI hay scene tree. Owner (player.gd,
## enemy...) tự lắng nghe signal và forward lên Events nếu cần. Nhờ vậy component
## test được độc lập và dùng lại được ở mọi nơi.
##
## Gán vào node cha, chỉnh `max_hp` / i-frame qua Inspector. Xem ROADMAP.md mục 5.1.

## Máu tối đa. Với Player = số tim (mặc định 3, khớp số icon trong ui/hud/hud.tscn).
@export var max_hp: int = 3
## Sau khi trúng đòn có bật thời gian bất tử tạm thời không (Player: có; quái: thường không).
@export var invincibility_on_hit: bool = false
## Độ dài (giây) của khoảng bất tử sau khi trúng đòn.
@export var invincibility_duration: float = 1.0

var hp: int
var _invincible: bool = false
var _dead: bool = false

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, source: Node)
signal died
signal invincibility_started(duration: float)
signal invincibility_ended

func _ready() -> void:
	hp = max_hp
	# Phát 1 lần lúc khởi tạo để HUD / mirror đồng bộ ngay, không phụ thuộc thứ tự _ready.
	health_changed.emit(hp, max_hp)

## Trừ máu. Bỏ qua nếu đang bất tử hoặc đã chết. `source` là node gây sát thương
## (Hitbox, bẫy...) — dùng cho knockback / hiệu ứng phía owner.
func damage(amount: int, source: Node = null) -> void:
	if _dead or _invincible or amount <= 0:
		return
	hp = max(hp - amount, 0)
	damaged.emit(amount, source)
	health_changed.emit(hp, max_hp)
	if hp == 0:
		_dead = true
		died.emit()
		return
	if invincibility_on_hit:
		_start_invincibility()

func heal(amount: int) -> void:
	if _dead or amount <= 0:
		return
	hp = min(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)

func heal_to_full() -> void:
	if _dead:
		return
	hp = max_hp
	health_changed.emit(hp, max_hp)

## Hồi sinh sau khi đã chết (dùng khi respawn tại checkpoint).
func revive() -> void:
	_dead = false
	_invincible = false
	hp = max_hp
	health_changed.emit(hp, max_hp)

## Bật khoảng bất tử tạm thời mà không cần trúng đòn (dùng sau khi respawn).
func grant_invincibility() -> void:
	if not _dead:
		_start_invincibility()

func is_alive() -> bool:
	return not _dead

func is_invincible() -> bool:
	return _invincible

func _start_invincibility() -> void:
	_invincible = true
	invincibility_started.emit(invincibility_duration)
	await get_tree().create_timer(invincibility_duration).timeout
	if not is_inside_tree():
		return  # node đã bị giải phóng (đổi scene) trong lúc chờ
	_invincible = false
	invincibility_ended.emit()
