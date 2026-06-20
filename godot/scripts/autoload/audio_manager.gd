extends Node
## Procedural SFX + M1 chiptune ambient — port of src/sound.py (no external assets).
## Headless-safe: all playback no-ops when DisplayServer is headless.

const SAMPLE_RATE := 22050
const POOL_SIZE := 8
const SFXR_RATE := 44100
const Sfxr = preload("res://scripts/audio/sfxr.gd")
const MusicDefs = preload("res://scripts/audio/music_defs.gd")

const HEAT_TENSION_THRESHOLD := 60.0

var _enabled := false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _pool_idx := 0
var _sfx_linear := 0.5
var _music_linear := 0.25
var _music_player: AudioStreamPlayer
var _music_layer_player: AudioStreamPlayer
var _music_mode: int = MusicDefs.MusicMode.PLAYING_AMBIENT
var _tension_active := false


func _ready() -> void:
	_enabled = not _is_headless()
	if not _enabled:
		return
	_setup_buses()
	_build_streams()
	_setup_players()
	apply_from_state(GameState)


func is_enabled() -> bool:
	return _enabled


func get_music_mode() -> int:
	return _music_mode


func set_music_mode(mode: int) -> void:
	if not _enabled or _music_player == null:
		return
	if _music_mode == mode:
		return
	_music_mode = mode
	var key := "ambient"
	if mode == MusicDefs.MusicMode.MENU:
		key = "menu"
	var stream: AudioStream = _streams.get(key, null)
	if stream == null:
		return
	if _music_player.stream != stream:
		_music_player.stream = stream
		_music_player.play()
	_sync_tension_layer()


func update_music_context(ctx: Dictionary) -> void:
	if not _enabled:
		return
	if _music_mode != MusicDefs.MusicMode.PLAYING_AMBIENT:
		_set_tension_active(false)
		return
	var heat: float = float(ctx.get("heat", 0.0))
	_set_tension_active(heat >= HEAT_TENSION_THRESHOLD)


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
	var music_db := linear_to_db(maxf(_music_linear, 0.0001)) if _music_linear > 0.0 else -80.0
	if _music_player:
		_music_player.volume_db = music_db
	if _music_layer_player:
		var layer_linear := _music_linear * (0.45 if _tension_active else 0.0)
		_music_layer_player.volume_db = (
			linear_to_db(maxf(layer_linear, 0.0001)) if layer_linear > 0.0 else -80.0
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


func _setup_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


func _setup_players() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.stream = _streams.get("menu", null)
	add_child(_music_player)
	_music_layer_player = AudioStreamPlayer.new()
	_music_layer_player.bus = &"Music"
	_music_layer_player.stream = _streams.get("tension", null)
	add_child(_music_layer_player)
	if _music_player.stream:
		_music_player.volume_db = -80.0
		_music_player.play()


func _set_tension_active(active: bool) -> void:
	if _tension_active == active:
		return
	_tension_active = active
	_sync_tension_layer()
	apply_from_state(GameState)


func _sync_tension_layer() -> void:
	if _music_layer_player == null:
		return
	var layer_on := (
		_tension_active
		and _music_mode == MusicDefs.MusicMode.PLAYING_AMBIENT
		and _music_layer_player.stream != null
	)
	if layer_on and not _music_layer_player.playing:
		_music_layer_player.play()
	elif not layer_on and _music_layer_player.playing:
		_music_layer_player.stop()


## SFX are sfxr-synthesized once at startup (deterministic per cue via a fixed
## seed). Music loops are procedural PCM from music_defs motifs.
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
	_streams["menu"] = _render_menu_loop(8.0, MusicDefs.AMBIENT_VOL * 0.85)
	_streams["ambient"] = _render_famiglia_loop(10.0, MusicDefs.AMBIENT_VOL)
	_streams["tension"] = _render_tension_layer(4.0, 0.12)


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


func _loop_stream(samples: PackedInt32Array) -> AudioStreamWAV:
	var stream := _make_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream


func _hz_from_semitone(root_hz: float, semitone: int) -> float:
	return root_hz * pow(2.0, float(semitone) / 12.0)


func _wave_triangle(freq: float, t: float) -> float:
	return asin(sin(TAU * freq * t)) * (2.0 / PI)


func _wave_square(freq: float, t: float, duty: float = 0.25) -> float:
	var phase := fmod(freq * t, 1.0)
	return 1.0 if phase < duty else -1.0


## M1 famiglia loop — pad + waltz bass + Godfather lead + mandolin arp (whole-bar math).
func _render_famiglia_loop(dur_s: float, vol: float) -> AudioStreamWAV:
	var bpm := float(MusicDefs.MusicTempo.ANDANTE)
	var beats_per_bar := 3
	var beat_s := 60.0 / bpm
	var bar_s := beat_s * float(beats_per_bar)
	var bars := maxi(1, int(round(dur_s / bar_s)))
	dur_s = float(bars) * bar_s
	var n := int(SAMPLE_RATE * dur_s)
	var amp := float(32767.0 * vol)
	var samples := PackedInt32Array()
	samples.resize(n)
	var melody := MusicDefs.MOTIF_GODFATHER
	var arp := MusicDefs.MOTIF_MANDOLIN_ARP
	var bass_pattern := MusicDefs.MOTIF_WALTZ_BASS
	var mel_root := MusicDefs.ROOT_C4
	var bass_root := MusicDefs.ROOT_A2
	var note_count := melody.size()
	var arp_rate := 4.0 / beat_s
	var lfo_hz := 0.5 * float(bars) / dur_s

	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var lfo := 0.85 + 0.15 * sin(TAU * lfo_hz * t)
		var pad := 0.0
		for k in MusicDefs.AMBIENT_ROOTS.size():
			pad += MusicDefs.AMBIENT_WEIGHTS[k] * sin(TAU * MusicDefs.AMBIENT_ROOTS[k] * t)
		pad *= 0.35 * lfo
		var beat_i := int(floor(t / beat_s))
		var beat_in_bar := beat_i % beats_per_bar
		var bass_st: int = bass_pattern[beat_in_bar % bass_pattern.size()]
		var bass_hz := _hz_from_semitone(bass_root, bass_st)
		var bass := _wave_triangle(bass_hz, t) * 0.45
		var mel_idx: int = int(floor(t / (dur_s / float(note_count)))) % note_count
		var mel_hz := _hz_from_semitone(mel_root, int(melody[mel_idx]))
		var vibrato := 0.5 + 0.5 * sin(TAU * 5.0 * t)
		var lead := _wave_square(mel_hz, t, 0.25) * 0.18 * vibrato
		var arp_i: int = int(floor(t * arp_rate)) % arp.size()
		var arp_hz := _hz_from_semitone(mel_root, int(arp[arp_i]))
		var mand := _wave_square(arp_hz, t, 0.12) * 0.08
		var s := pad + bass + lead + mand
		samples[i] = int(clampf(s, -1.0, 1.0) * amp)
	return _loop_stream(samples)


## L0 menu hook — pad swell + simplified Godfather motif.
func _render_menu_loop(dur_s: float, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur_s)
	var amp := float(32767.0 * vol)
	var samples := PackedInt32Array()
	samples.resize(n)
	var melody := MusicDefs.MOTIF_GODFATHER
	var mel_root := MusicDefs.ROOT_C4
	var note_count := melody.size()
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var lfo := 0.82 + 0.18 * sin(TAU * 0.25 * t)
		var pad := 0.0
		for k in MusicDefs.AMBIENT_ROOTS.size():
			pad += MusicDefs.AMBIENT_WEIGHTS[k] * sin(TAU * MusicDefs.AMBIENT_ROOTS[k] * t)
		pad *= 0.42 * lfo
		var mel_idx: int = int(floor(t / (dur_s / float(note_count)))) % note_count
		var mel_hz := _hz_from_semitone(mel_root, int(melody[mel_idx]))
		var lead := _wave_square(mel_hz, t, 0.22) * 0.14
		var s := pad + lead
		samples[i] = int(clampf(s, -1.0, 1.0) * amp)
	return _loop_stream(samples)


## M1 tension stub — noise grit + raid stab overlay when heat >= 60%.
func _render_tension_layer(dur_s: float, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur_s)
	var amp := float(32767.0 * vol)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7711
	var noise_buf := PackedFloat32Array()
	noise_buf.resize(1024)
	for j in 1024:
		noise_buf[j] = rng.randf_range(-1.0, 1.0)
	var samples := PackedInt32Array()
	samples.resize(n)
	var stab := MusicDefs.MOTIF_RAID_STAB
	var stab_root := MusicDefs.ROOT_C4
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var noise := noise_buf[i % 1024] * 0.25
		noise *= 0.5 + 0.5 * sin(TAU * 2.0 * t)
		var stab_mix := 0.0
		if fmod(t, 2.0) < 0.12:
			var hz := _hz_from_semitone(stab_root, int(stab[0]))
			stab_mix = _wave_square(hz, t, 0.2) * 0.35
		var s := noise + stab_mix
		samples[i] = int(clampf(s, -1.0, 1.0) * amp)
	return _loop_stream(samples)
