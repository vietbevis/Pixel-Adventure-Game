extends Node
## Autoload: nhạc nền theo world + SFX. Nghe `Events` cho phần lớn SFX; player.gd
## gọi thẳng `AudioManager.play_sfx("jump"/"attack")` cho hành động của player.
## Bus: Master → Music, SFX. Âm lượng Master lưu qua SaveManager setting "volume".

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
}
const POOL_SIZE := 6

var _music: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _current_track: String = ""
var _sfx_cache: Dictionary = {}
var _music_cache: Dictionary = {}

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

	apply_master_volume(SaveManager.get_setting("volume", 0.8))

	Events.player_damaged.connect(func(_a: int) -> void: play_sfx("hurt"))
	Events.enemy_died.connect(func(_n: Node, _p: Vector2) -> void: play_sfx("enemy_die"))
	Events.ability_unlocked.connect(func(_id: String) -> void: play_sfx("pickup"))
	Events.collectible_collected.connect(func(_id: String, _k: String) -> void: play_sfx("pickup"))
	Events.checkpoint_activated.connect(func(_p: Vector2) -> void: play_sfx("pickup"))
	Events.max_hp_increased.connect(func(_m: int) -> void: play_sfx("pickup"))

func play_music(world: String) -> void:
	var path: String = MUSIC.get(world, MUSIC[""])
	if path == _current_track and _music.playing:
		return
	_current_track = path
	if not _music_cache.has(path):
		var loaded: AudioStream = load(path) if ResourceLoader.exists(path) else null
		# duplicate() để set loop trên bản riêng, không mutate resource dùng chung.
		if loaded:
			loaded = loaded.duplicate()
			if loaded is AudioStreamOggVorbis or loaded is AudioStreamMP3:
				loaded.loop = true
		_music_cache[path] = loaded
	_music.stream = _music_cache[path]
	if _music.stream:
		_music.play()

func stop_music() -> void:
	_music.stop()
	_current_track = ""

func play_sfx(sfx_name: String, pitch_var: float = 0.06) -> void:
	if not _sfx_cache.has(sfx_name):
		var path: String = SFX_PATHS.get(sfx_name, "")
		_sfx_cache[sfx_name] = load(path) if (path != "" and ResourceLoader.exists(path)) else null
	var stream: AudioStream = _sfx_cache[sfx_name]
	if stream == null:
		return
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return

## Áp âm lượng NGAY (không ghi đĩa) — gọi liên tục khi kéo slider được.
## value 0..1 → Master bus dB (0 = tắt tiếng, 1 = 0dB).
func apply_master_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if value <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(value, 0.0, 1.0)))

## Áp + LƯU (gọi 1 lần khi thả slider), tránh ghi file mỗi frame kéo.
func set_master_volume(value: float) -> void:
	apply_master_volume(value)
	SaveManager.set_setting("volume", value)
