extends Node
## Autoload: nhạc nền theo world + SFX. Nghe `Events` cho phần lớn SFX; player.gd
## gọi thẳng `AudioManager.play_sfx("jump"/"attack")` cho hành động của player.
## Bus: Master → Music, SFX. Nhạc nền và hiệu ứng chỉnh âm lượng RIÊNG (setting
## "music_volume" / "sfx_volume") — trước chỉ có 1 setting "volume" trên Master nên muốn
## nhỏ nhạc là mất luôn tiếng nhảy/đánh. Master giữ 0 dB.

const MUSIC := {
	"": "res://audio/music/hub.ogg",
	"forest": "res://audio/music/forest.ogg",
	"castle": "res://audio/music/castle.ogg",
	"dungeon": "res://audio/music/dungeon.ogg",
}
const SFX_PATHS := {
	"jump": "res://audio/sfx/jump.ogg",
	"attack": "res://audio/sfx/attack.ogg",
	"hurt": "res://audio/sfx/hurt.ogg",
	"enemy_die": "res://audio/sfx/enemy_die.ogg",
	"pickup": "res://audio/sfx/pickup.ogg",
	## fruit/step: tổng hợp bằng tools/audio/gen_sfx.py (không pack nào có sẵn).
	"fruit": "res://audio/sfx/fruit.wav",
	"step": "res://audio/sfx/step.wav",
	## Sting kết quả: .wav (máy dev không có bộ mã hoá ogg; Godot import wav native).
	"game_over": "res://audio/sfx/game_over.wav",
	"victory": "res://audio/sfx/victory.wav",
	"final_victory": "res://audio/sfx/final_victory.wav",
}
const POOL_SIZE := 6

## Bus → key setting lưu âm lượng 0..1 của bus đó.
const VOLUME_KEYS := {"Music": "music_volume", "SFX": "sfx_volume"}
const DEFAULT_VOLUME := 0.8

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _current_track: String = "<none>"
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)

	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)

	# Áp thôi, không lưu: giá trị vừa đọc từ save, ghi lại chỉ tốn 1 lần IO mỗi lần mở game.
	for bus_name: String in VOLUME_KEYS:
		apply_volume(bus_name, get_volume(bus_name))

	Events.player_damaged.connect(func(_a: int) -> void: play_sfx("hurt"))
	Events.enemy_died.connect(func(_n: Node, _p: Vector2) -> void: play_sfx("enemy_die"))
	Events.ability_unlocked.connect(func(_id: String) -> void: play_sfx("pickup"))
	Events.fruit_collected.connect(func(_t: int) -> void: play_sfx("fruit"))
	Events.collectible_collected.connect(func(_id: String, _k: String) -> void: play_sfx("pickup"))
	Events.checkpoint_activated.connect(func(_p: Vector2) -> void: play_sfx("pickup"))
	Events.max_hp_increased.connect(func(_m: int) -> void: play_sfx("pickup"))

func play_music(world: String) -> void:
	var path: String = MUSIC.get(world, MUSIC[""])
	if path == _current_track and _music.playing:
		return
	_current_track = path
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	_music.stream = stream
	_music.play()

func stop_music() -> void:
	_music.stop()
	_current_track = "<none>"

func play_sfx(name: String, pitch_var: float = 0.06) -> void:
	if not _sfx_cache.has(name):
		var path: String = SFX_PATHS.get(name, "")
		_sfx_cache[name] = load(path) if (path != "" and ResourceLoader.exists(path)) else null
	var stream: AudioStream = _sfx_cache[name]
	if stream == null:
		return
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return

## Sting kết quả (thắng/thua): tắt nhạc nền rồi phát 1 lần, KHÔNG lệch cao độ —
## sting là một câu giai điệu, pitch_var làm nó nghe sai nốt.
## AudioManager là autoload nên tiếng vẫn ngân tiếp qua lúc đổi scene.
func play_sting(sting_name: String) -> void:
	stop_music()
	play_sfx(sting_name, 0.0)

## Âm lượng đã lưu của 1 bus (0..1). Save cũ chỉ có "volume" chung → dùng nó làm
## mặc định cho cả hai để người chơi không bị đổi mức sau khi cập nhật.
func get_volume(bus_name: String) -> float:
	var legacy: float = float(SaveManager.get_setting("volume", DEFAULT_VOLUME))
	return float(SaveManager.get_setting(VOLUME_KEYS[bus_name], legacy))

## Áp âm lượng lên bus NGAY mà không ghi đĩa. value 0..1 (0 = tắt tiếng).
## Tách khỏi `set_volume` để lúc kéo/bấm liên tục không ghi file mỗi bước —
## `SaveManager.set_setting` gọi `save_data()` mỗi lần.
func apply_volume(bus_name: String, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if value <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(value, 0.0, 1.0)))

## Áp + lưu. Gọi khi người chơi đã chốt giá trị.
func set_volume(bus_name: String, value: float) -> void:
	apply_volume(bus_name, value)
	SaveManager.set_setting(VOLUME_KEYS[bus_name], value)
