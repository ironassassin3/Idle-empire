extends Node
## Procedural SFX — port of src/sound.py (no external assets).
## Headless-safe: all playback no-ops when DisplayServer is headless.

const SAMPLE_RATE := 22050
const POOL_SIZE := 8

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


func _build_streams() -> void:
	_streams["click"] = _sine(440.0, 40, 0.28, 20)
	_streams["purchase"] = _two_tone(520.0, 660.0, 60, 80, 0.38)
	_streams["achievement"] = _two_tone(660.0, 880.0, 80, 120, 0.42)
	_streams["coin"] = _two_tone(880.0, 1100.0, 60, 100, 0.38)
	_streams["crit"] = _two_tone(660.0, 1320.0, 45, 120, 0.52)
	_streams["buff"] = _two_tone(523.0, 784.0, 90, 150, 0.46)
	_streams["manager"] = _arpeggio([[392.0, 70], [523.0, 70], [659.0, 130]], 0.42)
	_streams["territory"] = _arpeggio([[523.0, 70], [659.0, 70], [784.0, 150]], 0.46)
	_streams["rival"] = _arpeggio([[523.0, 70], [659.0, 70], [784.0, 70], [1047.0, 190]], 0.52)
	_streams["rankup"] = _arpeggio([[659.0, 60], [784.0, 60], [988.0, 60], [1319.0, 200]], 0.50)
	_streams["prestige"] = _arpeggio(
		[[330.0, 110], [440.0, 110], [523.0, 120], [659.0, 140], [880.0, 320]], 0.55
	)
	_streams["error"] = _noise(60, 0.18)
	_streams["ambient"] = _ambient(4.0, 0.22)


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


func _sine(freq: float, dur_ms: int, vol: float, fade_ms: int) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur_ms / 1000.0)
	var fn := int(SAMPLE_RATE * fade_ms / 1000.0)
	var amp := int(32767.0 * vol)
	var samples := PackedInt32Array()
	samples.resize(n)
	for i in n:
		var envelope := 1.0
		if fn > 0 and i >= n - fn:
			envelope = float(n - i) / float(fn)
		var s := int(float(amp) * envelope * sin(TAU * freq * float(i) / float(SAMPLE_RATE)))
		samples[i] = s
	return _make_stream(samples)


func _two_tone(f1: float, f2: float, d1_ms: int, d2_ms: int, vol: float) -> AudioStreamWAV:
	var n1 := int(SAMPLE_RATE * d1_ms / 1000.0)
	var n2 := int(SAMPLE_RATE * d2_ms / 1000.0)
	var amp := int(32767.0 * vol)
	var total := n1 + n2
	var samples := PackedInt32Array()
	samples.resize(total)
	var idx := 0
	for i in n1:
		var fade := float(n1 - i) / float(n1)
		samples[idx] = int(float(amp) * fade * sin(TAU * f1 * float(i) / float(SAMPLE_RATE)))
		idx += 1
	for i in n2:
		var fade := float(n2 - i) / float(n2)
		samples[idx] = int(float(amp) * fade * sin(TAU * f2 * float(i) / float(SAMPLE_RATE)))
		idx += 1
	return _make_stream(samples)


func _arpeggio(notes: Array, vol: float) -> AudioStreamWAV:
	var amp := int(32767.0 * vol)
	var samples := PackedInt32Array()
	for note in notes:
		var freq: float = note[0]
		var dur_ms: int = int(note[1])
		var n := int(SAMPLE_RATE * dur_ms / 1000.0)
		var prev := samples.size()
		samples.resize(prev + n)
		for i in n:
			var fade := float(n - i) / float(n)
			samples[prev + i] = int(
				float(amp) * fade * sin(TAU * freq * float(i) / float(SAMPLE_RATE))
			)
	return _make_stream(samples)


func _noise(dur_ms: int, vol: float) -> AudioStreamWAV:
	var n := int(SAMPLE_RATE * dur_ms / 1000.0)
	var amp := int(32767.0 * vol)
	var samples := PackedInt32Array()
	samples.resize(n)
	for i in n:
		var fade := float(n - i) / float(n)
		samples[i] = int(float(amp) * fade * randf_range(-1.0, 1.0))
	return _make_stream(samples)


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
