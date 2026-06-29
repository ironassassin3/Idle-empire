extends Node

## Procedural SFX for combat/planning (presentation only, handoff §18).

var _player: AudioStreamPlayer
var _streams: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_streams["click"] = _tone(440.0, 0.05, 0.25)
	_streams["hit"] = _tone(120.0, 0.08, 0.35)
	_streams["death"] = _tone(80.0, 0.15, 0.4)
	_streams["lock"] = _tone(220.0, 0.1, 0.3)
	_streams["win"] = _tone(660.0, 0.2, 0.35)
	_streams["lose"] = _tone(140.0, 0.25, 0.3)


func play(cue: String) -> void:
	var stream: AudioStream = _streams.get(cue, null)
	if stream == null:
		return
	_player.stream = stream
	_player.play()


func on_combat_event(event: Dictionary) -> void:
	match event.get("type", ""):
		"ATTACK_START":
			play("click")
		"DAMAGE":
			play("hit")
		"UNIT_DIED":
			play("death")
		"COMBAT_END":
			var outcome := int(event.get("outcome", -1))
			play("win" if outcome == SimConstants.CombatOutcome.PLAYER else "lose")


func on_phase_changed(phase: int) -> void:
	if phase == SimConstants.RunPhase.COMBAT_RESOLVE:
		play("lock")


func _tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var count := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(mix_rate)
		var env := 1.0 - (t / duration)
		var sample := int(clampf(sin(TAU * freq * t) * env * volume, -1.0, 1.0) * 32767.0)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
