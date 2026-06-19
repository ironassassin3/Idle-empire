extends Node
## Procedural SFX — port of src/sound.py (no external assets).
## Headless-safe: all playback no-ops when DisplayServer is headless.

const SAMPLE_RATE := 22050
const POOL_SIZE := 8
const SFXR_RATE := 44100
const Sfxr = preload("res://scripts/audio/sfxr.gd")

var _enabled := false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _sfx_linear := 0.5
var _music_linear := 0.25
var _music_player: AudioStreamPlayer


func _ready() -> void:
	_enabled = not _is_headless()
	if not _enabled:
		return
	_build_streams()
	_setup_players()
	apply_from_state(GameState)


func is_enabled() -> bool:
	return _enabled


func apply_from_state(state) -> void:
	if not _enabled:
		return
	if state.mute_all:
		_sfx_linear = 0.0
		_music_linear = 0.0
	else:
		_sfx_linear = clampf(state.master_volume * state.sfx_volume, 0.0, 1.0)
		_music_linear = clampf(state.master_volume * state.music_volume, 0.0, 1.0)
	var sfx_db := linear_to_db(maxf(_sfx_linear, 0.0001)) if _sfx_linear > 0.0 else -80.0
	for p in _players:
		p.volume_db = sfx_db
	if _music_player:
		_music_player.volume_db = (
			linear_to_db(maxf(_music_linear, 0.0001)) if _music_linear > 0.0 else -80.0
		)


func play(name: String) -> void:
	if not _enabled or not _streams.has(name):
		return
	var player := _players[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _players.size()
	player.stream = _streams[name]
	player.play()


func cue_for_notification(message: String, color: Color) -> String:
	if message.is_empty():
		return ""
	if message == "Critical hit!":
		return "crit"
	if message.begins_with("HUSTLE ACTIVE"):
		return "buff"
	if message.begins_with("FRENZY!") or message.begins_with("CLICK STORM!"):
		return "buff"
	if message.begins_with("Achievement:"):
		return "achievement"
	if message.begins_with("Prestige!"):
		return "prestige"
	if message.begins_with("Hired "):
		return "manager"
	if message.begins_with("Upgrade:"):
		return "purchase"
	if message.begins_with("Purchased"):
		return "purchase"
	if message.begins_with("ELIMINATED"):
		return "rival"
	if message.contains("FAILED"):
		return "error"
	if message.contains("started — collect"):
		return "purchase"
	if (
		message.contains("Seized ")
		or message.contains("Bribed your way")
		or message.contains("Negotiated control")
		or message.contains("Sabotaged them out")
	):
		return "territory"
	if message.contains("Sal caught a golden coin"):
		return "coin"
	if message.contains("Lucky!"):
		return "coin"
	if is_autobuy_message(message):
		return "purchase"
	if _is_goal_message(message, color):
		return "achievement"
	return ""


func is_autobuy_message(message: String) -> bool:
	return (
		message.contains("Mechanic")
		or message.contains("Accountant")
		or message.contains("Smuggler:")
		or message.contains("auto-buy")
		or message.contains("secured a new asset")
	)


func _is_goal_message(message: String, color: Color) -> bool:
	if color != GameTheme.GOLD_BRIGHT or not message.contains("\n"):
		return false
	var parts: PackedStringArray = message.split("\n", false, 1)
	return parts.size() == 2 and parts[1].begins_with("+")


func _setup_players() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.stream = _streams.get("ambient", null)
	if _music_player.stream:
		_music_player.volume_db = -80.0
		add_child(_music_player)
		_music_player.play()


## SFX are sfxr-synthesized once at startup (deterministic per cue via a fixed
## seed). `ambient` stays the looping noir drone — sfxr is for one-shots.
func _build_streams() -> void:
	_streams["click"] = _sfx("blip", 101, 0.30)
	_streams["purchase"] = _sfx("coin", 202, 0.40)
	_streams["achievement"] = _sfx("powerup", 303, 0.44)
	_streams["coin"] = _sfx("coin", 404, 0.40)
	_streams["crit"] = _sfx("laser", 505, 0.50)
	_streams["buff"] = _sfx("powerup", 606, 0.46)
	_streams["manager"] = _sfx("powerup", 707, 0.44)
	_streams["territory"] = _sfx("powerup", 808, 0.46)
	_streams["rival"] = _sfx("explosion", 909, 0.52)
	_streams["rankup"] = _sfx("powerup", 112, 0.50, {"p_base_freq": 0.45, "p_arp_speed": 0.6, "p_arp_mod": 0.45})
	_streams["prestige"] = _sfx("powerup", 223, 0.55, {"p_base_freq": 0.30, "p_env_decay": 0.55, "p_arp_speed": 0.55, "p_arp_mod": 0.50})
	_streams["error"] = _sfx("hit", 334, 0.40)
	_streams["ambient"] = _ambient(4.0, 0.22)


## Build one sfxr cue: seed an RNG, apply a preset (+ optional param overrides),
## render, and normalize to `peak`. Seeds are fixed so a cue sounds identical
## every play and across sessions; reroll a seed to audition alternatives.
func _sfx(preset: String, seed: int, peak: float, overrides: Dictionary = {}) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var p: Dictionary
	match preset:
		"coin": p = Sfxr.preset_coin(rng)
		"laser": p = Sfxr.preset_laser(rng)
		"explosion": p = Sfxr.preset_explosion(rng)
		"powerup": p = Sfxr.preset_powerup(rng)
		"hit": p = Sfxr.preset_hit(rng)
		"jump": p = Sfxr.preset_jump(rng)
		"blip": p = Sfxr.preset_blip(rng)
		_: p = Sfxr.default_params()
	for k in overrides:
		p[k] = overrides[k]
	p["seed"] = seed
	return Sfxr.to_stream(Sfxr.render(p, SFXR_RATE), SFXR_RATE, peak)


func _is_headless() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for arg in OS.get_cmdline_user_args():
		if arg == "--headless":
			return true
	for arg in OS.get_cmdline_args():
		if arg == "--headless":
			return true
	return false


func _make_stream(samples: PackedInt32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = true
	var data := PackedByteArray()
	data.resize(samples.size() * 4)
	for i in samples.size():
		var v := clampi(samples[i], -32767, 32767)
		var base := i * 4
		data[base] = v & 0xFF
		data[base + 1] = (v >> 8) & 0xFF
		data[base + 2] = v & 0xFF
		data[base + 3] = (v >> 8) & 0xFF
	stream.data = data
	return stream


## Seamless ambient drone for the Music bus. Frequencies and the LFO complete
## whole cycles over dur_s, so the loop has no boundary click.
func _ambient(dur_s: float, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur_s)
	var amp := float(32767.0 * vol)
	var freqs := [110.0, 165.0, 220.0]  # A2, E3, A3 noir drone
	var weights := [1.0, 0.55, 0.4]
	var samples := PackedInt32Array()
	samples.resize(n)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var lfo := 0.85 + 0.15 * sin(TAU * 0.5 * t)  # slow swell, 2 cycles / 4s
		var s := 0.0
		for k in freqs.size():
			s += weights[k] * sin(TAU * freqs[k] * t)
		samples[i] = int(amp * (s / 2.0) * lfo)
	var stream := _make_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = n
	return stream
