extends Node
## Procedural SFX + M1 chiptune ambient — port of src/sound.py (no external assets).
## Headless-safe: all playback no-ops when DisplayServer is headless.

const SAMPLE_RATE := 22050
const POOL_SIZE := 8
const SFXR_RATE := 44100
const Sfxr = preload("res://scripts/audio/sfxr.gd")
const MusicDefs = preload("res://scripts/audio/music_defs.gd")

const HEAT_TENSION_THRESHOLD := 60.0

# Global SFX softening — playtest said the stock sfxr presets were "metallic /
# harsh." Roll off the brittle highs (low-pass), keep the low-end body (no
# high-pass), kill the phaser's metallic comb, and add a tiny attack so
# transients thump instead of click. Per-sound overrides still win over these.
const _WARM_SFX := {
	"p_lpf_freq": 0.45,
	"p_lpf_resonance": 0.0,
	"p_hpf_freq": 0.0,
	"p_pha_offset": 0.0,
	"p_pha_ramp": 0.0,
	"p_env_attack": 0.015,
}

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
		or message.contains("Smuggler")
		or message.contains("auto-buy")
		or message.contains("Perk auto-buy")
		or message.contains("Auto-upgrade")
		or message.contains("Raid blocked")
		or message.contains("Carl dumped")
		or message.contains("Sal caught")
		or message.contains("secured a new asset")
		or message.contains("ordered another")
		or message.contains("bought ")
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
	# Soft "tok" for the constant UI click — low and short, no brittle edge.
	_streams["click"] = _sfx("blip", 101, 0.30, {"p_base_freq": 0.40, "p_lpf_freq": 0.5, "p_env_decay": 0.10})
	# Buy: keep the coin "ding" but lower and warmer so it has body, not glare.
	_streams["purchase"] = _sfx("coin", 202, 0.40, {"p_base_freq": 0.45, "p_lpf_freq": 0.5})
	_streams["achievement"] = _sfx("powerup", 303, 0.44)
	_streams["coin"] = _sfx("coin", 404, 0.40, {"p_lpf_freq": 0.5})
	# Crit: a low downward "thwack" instead of a metallic laser zap.
	_streams["crit"] = _sfx("laser", 505, 0.50, {"p_base_freq": 0.60, "p_freq_ramp": -0.30, "p_lpf_freq": 0.40})
	_streams["buff"] = _sfx("powerup", 606, 0.46)
	_streams["manager"] = _sfx("powerup", 707, 0.44)
	_streams["territory"] = _sfx("powerup", 808, 0.46)
	# Rival eliminated: deep punchy boom with a pitch drop — proper thump.
	_streams["rival"] = _sfx("explosion", 909, 0.52, {"p_base_freq": 0.16, "p_freq_ramp": -0.18, "p_env_punch": 0.60, "p_lpf_freq": 0.38})
	_streams["rankup"] = _sfx("powerup", 112, 0.50, {"p_base_freq": 0.45, "p_arp_speed": 0.6, "p_arp_mod": 0.45})
	_streams["prestige"] = _sfx("powerup", 223, 0.55, {"p_base_freq": 0.30, "p_env_decay": 0.55, "p_arp_speed": 0.55, "p_arp_mod": 0.50})
	# Error: soft low thud with a downward drop, not a harsh noise burst.
	_streams["error"] = _sfx("hit", 334, 0.40, {"p_base_freq": 0.28, "p_freq_ramp": -0.35, "p_lpf_freq": 0.40})
	_streams["menu"] = _render_cafe_loop(_FAMIGLIA_PROG.slice(0, 4), _MENU_MELODY, MusicDefs.AMBIENT_VOL * 0.85)
	_streams["ambient"] = _render_cafe_loop(_FAMIGLIA_PROG, _FAMIGLIA_MELODY, MusicDefs.AMBIENT_VOL)
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
	for k in _WARM_SFX:
		p[k] = _WARM_SFX[k]
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


## Per-note amplitude envelope (seconds): linear attack, sustain, linear release.
## Articulates notes so voices read as a played waltz, not a sustained drone.
func _note_env(pos: float, dur: float, atk: float, rel: float) -> float:
	if pos < 0.0 or pos > dur:
		return 0.0
	if pos < atk:
		return pos / atk
	if pos > dur - rel:
		return maxf(0.0, (dur - pos) / rel)
	return 1.0


## Plucked envelope (seconds): instant attack, exponential decay (pizzicato/mandolin).
func _pluck_env(pos: float, decay: float) -> float:
	if pos < 0.0:
		return 0.0
	return exp(-pos / decay)


# Warm 8-bar nostalgic progression: C  Am  F  G  C  Am  Dm  G.
# Single key (C major) so pad/bass/melody never clash — bass semitone is relative
# to C3, triad "tones" are semitones from C4. Every melody note is a chord tone.
const _FAMIGLIA_PROG := [
	{"bass": 0, "tones": [0, 4, 7]},     # C major
	{"bass": -3, "tones": [-3, 0, 4]},   # A minor
	{"bass": 5, "tones": [5, 9, 12]},    # F major
	{"bass": 7, "tones": [7, 11, 14]},   # G major
	{"bass": 0, "tones": [0, 4, 7]},     # C major
	{"bass": -3, "tones": [-3, 0, 4]},   # A minor
	{"bass": 2, "tones": [2, 5, 9]},     # D minor
	{"bass": 7, "tones": [7, 11, 14]},   # G major
]
# Melody: [semitone from C4, beats]. Contour arches over the progression; every
# pitch is a chord tone of its bar, so the line is fully consonant and warm.
const _FAMIGLIA_MELODY := [
	[7, 2.0], [4, 1.0], [9, 2.0], [4, 1.0],
	[5, 1.5], [9, 1.5], [7, 2.0], [11, 1.0],
	[12, 2.0], [7, 1.0], [9, 1.5], [4, 1.5],
	[5, 2.0], [9, 1.0], [7, 1.5], [2, 1.5],
]


# Menu melody: one note per bar over C Am F G (G E A G), each held the full bar.
const _MENU_MELODY := [
	[7, 3.0], [4, 3.0], [9, 3.0], [7, 3.0],
]


## Karplus-Strong plucked string — a noise burst recirculated through a 1-pole
## averaging filter. Reads as a real nylon/steel string (guitar, mandolin) rather
## than a synthetic oscillator. Re-plucking rapidly at one pitch = mandolin tremolo.
class KSString:
	var buf := PackedFloat32Array()
	var pos := 0
	var n := 0
	var damp := 0.996  # <1 shortens sustain; closer to 1 = longer ring
	var gain := 1.0

	func setup(maxlen: int) -> void:
		buf.resize(maxlen)

	func pluck(freq: float, rate: int, amp: float, rng: RandomNumberGenerator) -> void:
		n = clampi(int(round(float(rate) / freq)), 2, buf.size())
		for j in n:
			buf[j] = rng.randf_range(-1.0, 1.0) * amp
		pos = 0

	func step() -> float:
		if n <= 0:
			return 0.0
		var cur := buf[pos]
		var prevp := pos - 1
		if prevp < 0:
			prevp = n - 1
		buf[pos] = damp * 0.5 * (buf[pos] + buf[prevp])
		pos += 1
		if pos >= n:
			pos = 0
		return cur * gain


## Italian-café waltz: Karplus-Strong mandolin (tremolo) + fingerpicked nylon
## guitar (oom-pah-pah) + soft musette accordion, low-passed to a warm acoustic
## tone. Single key (C major), so nothing clashes. Used for both menu and gameplay.
func _render_cafe_loop(prog: Array, melody: Array, vol: float) -> AudioStreamWAV:
	var bpm := 64.0  # slightly under ANDANTE (72) for a more relaxed café sway
	var beats_per_bar := 3
	var beat_s := 60.0 / bpm
	var bar_s := beat_s * float(beats_per_bar)
	var bars := prog.size()
	var dur_s := float(bars) * bar_s
	var n := int(SAMPLE_RATE * dur_s)
	var amp := float(32767.0 * vol)
	var samples := PackedInt32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mel_root := MusicDefs.ROOT_C4
	var bass_root := MusicDefs.ROOT_C4 * 0.5  # C3
	# Melody schedule (cumulative start beat per note).
	var mel_starts := PackedFloat32Array()
	var acc := 0.0
	for ev in melody:
		mel_starts.append(acc)
		acc += float(ev[1])
	# Voices.
	var mand := KSString.new()
	mand.setup(600)
	mand.damp = 0.991
	mand.gain = 0.5
	var gtr_lo := KSString.new()
	gtr_lo.setup(600)
	gtr_lo.damp = 0.997
	gtr_lo.gain = 0.5
	var gtr_hi := KSString.new()
	gtr_hi.setup(600)
	gtr_hi.damp = 0.996
	gtr_hi.gain = 0.32
	var trem_dt := 0.07  # mandolin re-pluck interval (~14 Hz tremolo)
	var next_trem := 0.0
	var mel_i := 0
	var last_beat := -1
	var lp := 0.0
	var lp_a := 0.4  # one-pole low-pass coefficient (lower = warmer, less buzz)
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		while mel_i + 1 < melody.size() and (t / beat_s) >= mel_starts[mel_i + 1]:
			mel_i += 1
		var beat_global := int(floor(t / beat_s))
		var bar: int = (beat_global / beats_per_bar) % bars
		var beat_in_bar := beat_global % beats_per_bar
		var chord: Dictionary = prog[bar]
		var tones: Array = chord["tones"]
		# Mandolin tremolo: re-pluck the current melody pitch every trem_dt.
		if t >= next_trem:
			next_trem += trem_dt
			mand.pluck(_hz_from_semitone(mel_root, int(melody[mel_i][0])), SAMPLE_RATE, 1.0, rng)
		# Nylon guitar oom-pah-pah: low root on beat 1, chord tones on beats 2-3.
		if beat_global != last_beat:
			last_beat = beat_global
			if beat_in_bar == 0:
				gtr_lo.pluck(_hz_from_semitone(bass_root, int(chord["bass"])), SAMPLE_RATE, 1.0, rng)
			else:
				var ti := 1 if beat_in_bar == 1 else 2
				gtr_hi.pluck(_hz_from_semitone(bass_root, int(tones[ti])), SAMPLE_RATE, 0.9, rng)
		# Soft musette accordion: detuned reed pair per chord tone, per-bar swell.
		var bar_start_beat := (beat_global / beats_per_bar) * beats_per_bar
		var bar_pos := t - float(bar_start_beat) * beat_s
		var acc_env := _note_env(bar_pos, bar_s, 0.4, 0.35)
		var accordion := 0.0
		for tn in tones:
			var f := _hz_from_semitone(bass_root, int(tn) + 12)
			accordion += _wave_square(f, t, 0.5) + _wave_square(f * 1.006, t, 0.5)
		accordion *= 0.045 * acc_env * (0.85 + 0.15 * sin(TAU * 5.0 * t))
		var s := mand.step() + gtr_lo.step() + gtr_hi.step() + accordion
		# One-pole low-pass: rounds off the digital edge into an acoustic tone.
		lp += lp_a * (s - lp)
		samples[i] = int(clampf(lp, -1.0, 1.0) * amp)
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
	# Low A pedal (relative minor of the C ambient) — adds melancholy unease that
	# sits in-key under the music rather than a dissonant white-noise hiss.
	var pedal_hz := MusicDefs.ROOT_A2
	for i in n:
		var t := float(i) / float(SAMPLE_RATE)
		var pulse := 0.6 + 0.4 * sin(TAU * 0.5 * t)
		var pedal := _wave_triangle(pedal_hz, t) * 0.5 * pulse
		var noise := noise_buf[i % 1024] * 0.06 * pulse
		var stab_mix := 0.0
		if fmod(t, 2.0) < 0.10:
			var hz := _hz_from_semitone(stab_root, int(stab[0]) - 3)
			stab_mix = _wave_triangle(hz, t) * 0.25 * _pluck_env(fmod(t, 2.0), 0.06)
		var s := pedal + noise + stab_mix
		samples[i] = int(clampf(s, -1.0, 1.0) * amp)
	return _loop_stream(samples)
