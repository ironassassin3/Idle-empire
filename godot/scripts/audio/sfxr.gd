extends RefCounted
## Faithful GDScript port of DrPetter's sfxr synthesis (MIT), via grimfang4's
## SDL2 fork (ResetSample / SynthSample in sfxr main.cpp). Generates retro game
## SFX procedurally at runtime — no asset files, fits the code-drawn-only policy.
##
## render(params, mix_rate) -> mono float buffer in [-1, 1].
## to_stream(buffer, mix_rate, peak) -> stereo 16-bit AudioStreamWAV.
## preset_*(rng) -> a params Dictionary matching sfxr's generator buttons.

const MAX_SECONDS := 4.0  # safety cap on sound length


static func default_params() -> Dictionary:
	# Mirrors sfxr ResetParams() defaults.
	return {
		"wave_type": 0,
		"p_base_freq": 0.3, "p_freq_limit": 0.0, "p_freq_ramp": 0.0, "p_freq_dramp": 0.0,
		"p_duty": 0.0, "p_duty_ramp": 0.0,
		"p_vib_strength": 0.0, "p_vib_speed": 0.0,
		"p_env_attack": 0.0, "p_env_sustain": 0.3, "p_env_punch": 0.0, "p_env_decay": 0.4,
		"p_arp_mod": 0.0, "p_arp_speed": 0.0,
		"p_pha_offset": 0.0, "p_pha_ramp": 0.0,
		"p_lpf_freq": 1.0, "p_lpf_ramp": 0.0, "p_lpf_resonance": 0.0,
		"p_hpf_freq": 0.0, "p_hpf_ramp": 0.0,
		"p_repeat_speed": 0.0,
		"sound_vol": 0.5, "master_vol": 0.05,
		"seed": 0,
	}


static func render(p: Dictionary, mix_rate: int = 44100) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 0))

	var wave_type: int = int(p.get("wave_type", 0))
	var p_base_freq: float = p.get("p_base_freq", 0.3)
	var p_freq_limit: float = p.get("p_freq_limit", 0.0)
	var p_freq_ramp: float = p.get("p_freq_ramp", 0.0)
	var p_freq_dramp: float = p.get("p_freq_dramp", 0.0)
	var p_duty: float = p.get("p_duty", 0.0)
	var p_duty_ramp: float = p.get("p_duty_ramp", 0.0)
	var p_vib_strength: float = p.get("p_vib_strength", 0.0)
	var p_vib_speed: float = p.get("p_vib_speed", 0.0)
	var p_env_attack: float = p.get("p_env_attack", 0.0)
	var p_env_sustain: float = p.get("p_env_sustain", 0.3)
	var p_env_punch: float = p.get("p_env_punch", 0.0)
	var p_env_decay: float = p.get("p_env_decay", 0.4)
	var p_arp_mod: float = p.get("p_arp_mod", 0.0)
	var p_arp_speed: float = p.get("p_arp_speed", 0.0)
	var p_pha_offset: float = p.get("p_pha_offset", 0.0)
	var p_pha_ramp: float = p.get("p_pha_ramp", 0.0)
	var p_lpf_freq: float = p.get("p_lpf_freq", 1.0)
	var p_lpf_ramp: float = p.get("p_lpf_ramp", 0.0)
	var p_lpf_resonance: float = p.get("p_lpf_resonance", 0.0)
	var p_hpf_freq: float = p.get("p_hpf_freq", 0.0)
	var p_hpf_ramp: float = p.get("p_hpf_ramp", 0.0)
	var p_repeat_speed: float = p.get("p_repeat_speed", 0.0)
	var sound_vol: float = p.get("sound_vol", 0.5)
	var master_vol: float = p.get("master_vol", 0.05)

	var phase := 0
	var fperiod := 0.0
	var fmaxperiod := 0.0
	var fslide := 0.0
	var fdslide := 0.0
	var period := 0
	var square_duty := 0.0
	var square_slide := 0.0
	var env_stage := 0
	var env_time := 0
	var env_length := [0, 0, 0]
	var env_vol := 0.0
	var fphase := 0.0
	var fdphase := 0.0
	var iphase := 0
	var phaser_buffer := PackedFloat32Array()
	phaser_buffer.resize(1024)
	var ipp := 0
	var noise_buffer := PackedFloat32Array()
	noise_buffer.resize(32)
	var fltp := 0.0
	var fltdp := 0.0
	var fltw := 0.0
	var fltw_d := 0.0
	var fltdmp := 0.0
	var fltphp := 0.0
	var flthp := 0.0
	var flthp_d := 0.0
	var vib_phase := 0.0
	var vib_speed := 0.0
	var vib_amp := 0.0
	var rep_time := 0
	var rep_limit := 0
	var arp_time := 0
	var arp_limit := 0
	var arp_mod := 0.0

	# --- ResetSample(false): full reset ---
	fperiod = 100.0 / (p_base_freq * p_base_freq + 0.001)
	period = int(fperiod)
	fmaxperiod = 100.0 / (p_freq_limit * p_freq_limit + 0.001)
	fslide = 1.0 - pow(p_freq_ramp, 3.0) * 0.01
	fdslide = -pow(p_freq_dramp, 3.0) * 0.000001
	square_duty = 0.5 - p_duty * 0.5
	square_slide = -p_duty_ramp * 0.00005
	if p_arp_mod >= 0.0:
		arp_mod = 1.0 - pow(p_arp_mod, 2.0) * 0.9
	else:
		arp_mod = 1.0 + pow(p_arp_mod, 2.0) * 10.0
	arp_time = 0
	arp_limit = int(pow(1.0 - p_arp_speed, 2.0) * 20000 + 32)
	if p_arp_speed == 1.0:
		arp_limit = 0
	fltw = pow(p_lpf_freq, 3.0) * 0.1
	fltw_d = 1.0 + p_lpf_ramp * 0.0001
	fltdmp = 5.0 / (1.0 + pow(p_lpf_resonance, 2.0) * 20.0) * (0.01 + fltw)
	if fltdmp > 0.8:
		fltdmp = 0.8
	flthp = pow(p_hpf_freq, 2.0) * 0.1
	flthp_d = 1.0 + p_hpf_ramp * 0.0003
	vib_speed = pow(p_vib_speed, 2.0) * 0.01
	vib_amp = p_vib_strength * 0.5
	env_length[0] = int(p_env_attack * p_env_attack * 100000.0)
	env_length[1] = int(p_env_sustain * p_env_sustain * 100000.0)
	env_length[2] = int(p_env_decay * p_env_decay * 100000.0)
	fphase = pow(p_pha_offset, 2.0) * 1020.0
	if p_pha_offset < 0.0:
		fphase = -fphase
	fdphase = pow(p_pha_ramp, 2.0) * 1.0
	if p_pha_ramp < 0.0:
		fdphase = -fdphase
	iphase = abs(int(fphase))
	for i in 32:
		noise_buffer[i] = rng.randf() * 2.0 - 1.0
	rep_limit = int(pow(1.0 - p_repeat_speed, 2.0) * 20000 + 32)
	if p_repeat_speed == 0.0:
		rep_limit = 0

	var out := PackedFloat32Array()
	var playing := true
	var max_samples := int(mix_rate * MAX_SECONDS)
	var count := 0
	while playing and count < max_samples:
		count += 1
		rep_time += 1
		if rep_limit != 0 and rep_time >= rep_limit:
			# ResetSample(true): restart subset (frequency / duty / arpeggio only).
			rep_time = 0
			fperiod = 100.0 / (p_base_freq * p_base_freq + 0.001)
			period = int(fperiod)
			fslide = 1.0 - pow(p_freq_ramp, 3.0) * 0.01
			fdslide = -pow(p_freq_dramp, 3.0) * 0.000001
			square_duty = 0.5 - p_duty * 0.5
			square_slide = -p_duty_ramp * 0.00005
			if p_arp_mod >= 0.0:
				arp_mod = 1.0 - pow(p_arp_mod, 2.0) * 0.9
			else:
				arp_mod = 1.0 + pow(p_arp_mod, 2.0) * 10.0
			arp_time = 0
			arp_limit = int(pow(1.0 - p_arp_speed, 2.0) * 20000 + 32)
			if p_arp_speed == 1.0:
				arp_limit = 0
		arp_time += 1
		if arp_limit != 0 and arp_time >= arp_limit:
			arp_limit = 0
			fperiod *= arp_mod
		fslide += fdslide
		fperiod *= fslide
		if fperiod > fmaxperiod:
			fperiod = fmaxperiod
			if p_freq_limit > 0.0:
				playing = false
		var rfperiod := fperiod
		if vib_amp > 0.0:
			vib_phase += vib_speed
			rfperiod = fperiod * (1.0 + sin(vib_phase) * vib_amp)
		period = int(rfperiod)
		if period < 8:
			period = 8
		square_duty = clampf(square_duty + square_slide, 0.0, 0.5)
		env_time += 1
		if env_time > env_length[env_stage]:
			env_time = 0
			env_stage += 1
			if env_stage == 3:
				playing = false
		if env_stage == 0:
			env_vol = float(env_time) / maxf(1.0, float(env_length[0]))
		elif env_stage == 1:
			env_vol = 1.0 + pow(1.0 - float(env_time) / maxf(1.0, float(env_length[1])), 1.0) * 2.0 * p_env_punch
		elif env_stage == 2:
			env_vol = 1.0 - float(env_time) / maxf(1.0, float(env_length[2]))
		fphase += fdphase
		iphase = mini(abs(int(fphase)), 1023)
		if flthp_d != 0.0:
			flthp = clampf(flthp * flthp_d, 0.00001, 0.1)

		var ssample := 0.0
		for si in 8:  # 8x supersampling
			var sample := 0.0
			phase += 1
			if phase >= period:
				phase = phase % period
				if wave_type == 3:
					for i in 32:
						noise_buffer[i] = rng.randf() * 2.0 - 1.0
			var fp := float(phase) / float(period)
			match wave_type:
				0:
					sample = 0.5 if fp < square_duty else -0.5
				1:
					sample = 1.0 - fp * 2.0
				2:
					sample = sin(fp * 2.0 * PI)
				3:
					sample = noise_buffer[int(float(phase) * 32.0 / float(period)) % 32]
			# low-pass filter
			var pp := fltp
			fltw = clampf(fltw * fltw_d, 0.0, 0.1)
			if p_lpf_freq != 1.0:
				fltdp += (sample - fltp) * fltw
				fltdp -= fltdp * fltdmp
			else:
				fltp = sample
				fltdp = 0.0
			fltp += fltdp
			# high-pass filter
			fltphp += fltp - pp
			fltphp -= fltphp * flthp
			sample = fltphp
			# phaser
			phaser_buffer[ipp & 1023] = sample
			sample += phaser_buffer[(ipp - iphase + 1024) & 1023]
			ipp = (ipp + 1) & 1023
			ssample += sample * env_vol

		ssample = ssample / 8.0 * master_vol
		ssample *= 2.0 * sound_vol
		out.append(clampf(ssample, -1.0, 1.0))
	return out


## Normalize to target peak and pack as stereo 16-bit PCM.
static func to_stream(samples: PackedFloat32Array, mix_rate: int, peak: float = 0.5) -> AudioStreamWAV:
	var hi := 0.0
	for s in samples:
		hi = maxf(hi, absf(s))
	var scale: float = (peak / hi) if hi > 0.0001 else 0.0
	var n := samples.size()
	var data := PackedByteArray()
	data.resize(n * 4)
	for i in n:
		var v := int(clampf(samples[i] * scale, -1.0, 1.0) * 32767.0)
		var base := i * 4
		data[base] = v & 0xFF
		data[base + 1] = (v >> 8) & 0xFF
		data[base + 2] = v & 0xFF
		data[base + 3] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = true
	stream.data = data
	return stream


static func _frnd(rng: RandomNumberGenerator, x: float) -> float:
	return rng.randf() * x


static func _rnd(rng: RandomNumberGenerator, n: int) -> int:
	return rng.randi_range(0, n)


static func preset_coin(rng: RandomNumberGenerator) -> Dictionary:
	var p := default_params()
	p["p_base_freq"] = 0.4 + _frnd(rng, 0.5)
	p["p_env_attack"] = 0.0
	p["p_env_sustain"] = _frnd(rng, 0.1)
	p["p_env_decay"] = 0.1 + _frnd(rng, 0.4)
	p["p_env_punch"] = 0.3 + _frnd(rng, 0.3)
	if _rnd(rng, 1):
		p["p_arp_speed"] = 0.5 + _frnd(rng, 0.2)
		p["p_arp_mod"] = 0.2 + _frnd(rng, 0.4)
	return p


static func preset_laser(rng: RandomNumberGenerator) -> Dictionary:
	var p := default_params()
	var wave_type := _rnd(rng, 2)
	if wave_type == 2 and _rnd(rng, 1):
		wave_type = _rnd(rng, 1)
	p["wave_type"] = wave_type
	p["p_base_freq"] = 0.5 + _frnd(rng, 0.5)
	p["p_freq_limit"] = maxf(0.2, p["p_base_freq"] - 0.2 - _frnd(rng, 0.6))
	p["p_freq_ramp"] = -0.15 - _frnd(rng, 0.2)
	if _rnd(rng, 2) == 0:
		p["p_base_freq"] = 0.3 + _frnd(rng, 0.6)
		p["p_freq_limit"] = _frnd(rng, 0.1)
		p["p_freq_ramp"] = -0.35 - _frnd(rng, 0.3)
	if _rnd(rng, 1):
		p["p_duty"] = _frnd(rng, 0.5)
		p["p_duty_ramp"] = _frnd(rng, 0.2)
	else:
		p["p_duty"] = 0.4 + _frnd(rng, 0.5)
		p["p_duty_ramp"] = -_frnd(rng, 0.7)
	p["p_env_sustain"] = 0.1 + _frnd(rng, 0.2)
	p["p_env_decay"] = _frnd(rng, 0.4)
	if _rnd(rng, 1):
		p["p_env_punch"] = _frnd(rng, 0.3)
	if _rnd(rng, 2) == 0:
		p["p_pha_offset"] = _frnd(rng, 0.2)
		p["p_pha_ramp"] = -_frnd(rng, 0.2)
	if _rnd(rng, 1):
		p["p_hpf_freq"] = _frnd(rng, 0.3)
	return p


static func preset_explosion(rng: RandomNumberGenerator) -> Dictionary:
	var p := default_params()
	p["wave_type"] = 3
	if _rnd(rng, 1):
		p["p_base_freq"] = 0.1 + _frnd(rng, 0.4)
		p["p_freq_ramp"] = -0.1 + _frnd(rng, 0.4)
	else:
		p["p_base_freq"] = 0.2 + _frnd(rng, 0.7)
		p["p_freq_ramp"] = -0.2 - _frnd(rng, 0.2)
	p["p_base_freq"] = p["p_base_freq"] * p["p_base_freq"]
	if _rnd(rng, 4) == 0:
		p["p_freq_ramp"] = 0.0
	if _rnd(rng, 2) == 0:
		p["p_repeat_speed"] = 0.3 + _frnd(rng, 0.5)
	p["p_env_sustain"] = 0.1 + _frnd(rng, 0.3)
	p["p_env_decay"] = _frnd(rng, 0.5)
	if _rnd(rng, 1) == 0:
		p["p_pha_offset"] = -0.3 + _frnd(rng, 0.9)
		p["p_pha_ramp"] = -_frnd(rng, 0.3)
	p["p_env_punch"] = 0.2 + _frnd(rng, 0.6)
	if _rnd(rng, 1):
		p["p_vib_strength"] = _frnd(rng, 0.7)
		p["p_vib_speed"] = _frnd(rng, 0.6)
	if _rnd(rng, 2) == 0:
		p["p_arp_speed"] = 0.6 + _frnd(rng, 0.3)
		p["p_arp_mod"] = 0.8 - _frnd(rng, 1.6)
	return p


static func preset_powerup(rng: RandomNumberGenerator) -> Dictionary:
	var p := default_params()
	if _rnd(rng, 1):
		p["wave_type"] = 1
	else:
		p["p_duty"] = _frnd(rng, 0.6)
	if _rnd(rng, 1):
		p["p_base_freq"] = 0.2 + _frnd(rng, 0.3)
		p["p_freq_ramp"] = 0.1 + _frnd(rng, 0.4)
		p["p_repeat_speed"] = 0.4 + _frnd(rng, 0.4)
	else:
		p["p_base_freq"] = 0.2 + _frnd(rng, 0.3)
		p["p_freq_ramp"] = 0.05 + _frnd(rng, 0.2)
		if _rnd(rng, 1):
			p["p_vib_strength"] = _frnd(rng, 0.7)
			p["p_vib_speed"] = _frnd(rng, 0.6)
	p["p_env_sustain"] = _frnd(rng, 0.4)
	p["p_env_decay"] = 0.1 + _frnd(rng, 0.4)
	return p


static func preset_hit(rng: RandomNumberGenerator) -> Dictionary:
	var p := default_params()
	var wave_type := _rnd(rng, 2)
	if wave_type == 2:
		wave_type = 3
	p["wave_type"] = wave_type
	if wave_type == 0:
		p["p_duty"] = _frnd(rng, 0.6)
	p["p_base_freq"] = 0.2 + _frnd(rng, 0.6)
	p["p_freq_ramp"] = -0.3 - _frnd(rng, 0.4)
	p["p_env_sustain"] = _frnd(rng, 0.1)
	p["p_env_decay"] = 0.1 + _frnd(rng, 0.2)
	if _rnd(rng, 1):
		p["p_hpf_freq"] = _frnd(rng, 0.3)
	return p


static func preset_jump(rng: RandomNumberGenerator) -> Dictionary:
	var p := default_params()
	p["wave_type"] = 0
	p["p_duty"] = _frnd(rng, 0.6)
	p["p_base_freq"] = 0.3 + _frnd(rng, 0.3)
	p["p_freq_ramp"] = 0.1 + _frnd(rng, 0.2)
	p["p_env_sustain"] = 0.1 + _frnd(rng, 0.3)
	p["p_env_decay"] = 0.1 + _frnd(rng, 0.2)
	if _rnd(rng, 1):
		p["p_hpf_freq"] = _frnd(rng, 0.3)
	if _rnd(rng, 1):
		p["p_lpf_freq"] = 1.0 - _frnd(rng, 0.6)
	return p


static func preset_blip(rng: RandomNumberGenerator) -> Dictionary:
	var p := default_params()
	var wave_type := _rnd(rng, 1)
	p["wave_type"] = wave_type
	if wave_type == 0:
		p["p_duty"] = _frnd(rng, 0.6)
	p["p_base_freq"] = 0.2 + _frnd(rng, 0.4)
	p["p_env_sustain"] = 0.1 + _frnd(rng, 0.1)
	p["p_env_decay"] = _frnd(rng, 0.2)
	p["p_hpf_freq"] = 0.1
	return p
