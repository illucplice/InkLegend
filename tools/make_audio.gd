extends SceneTree
## Synthesises the game's sound effects and music into res://audio/ as 16-bit mono
## WAVs. Everything is generated from code (noise, oscillators and simple filters), so
## there are no outside assets. Run: godot --headless --path . -s tools/make_audio.gd

const RATE := 22050


func _initialize() -> void:
	var sfx := {
		"hit_body": _hit_body(),
		"hit_head": _hit_head(),
		"splat": _splat(),
		"gore": _gore(),
		"gush": _gush(),
		"slice": _slice(),
		"crunch": _crunch(),
		"punch": _punch(),
		"cheer": _cheer(),
		"clang": _clang(),
		"zap": _zap(),
		"boom": _boom(),
		"voice_hurt": _voice_hurt(),
		"voice_die": _voice_die(),
		"voice_charge": _voice_charge(),
		"voice_laugh": _voice_laugh(),
	}
	for name: String in sfx:
		_save("res://audio/sfx/%s.wav" % name, sfx[name], 0.9)
	_save("res://audio/music/battle.wav", _battle(132.0, 0, [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], "square", "pluck"), 0.8)
	# Bamboo Dojo: a pentatonic tune, lighter and plucked.
	_save("res://audio/music/battle_east.wav", _battle(118.0, 2, [[48, 55, 60], [45, 52, 57], [43, 50, 55], [45, 52, 60]], "triangle", "pluck"), 0.8)
	# Graveyard and Lava Forge: slower, darker, in D minor.
	_save("res://audio/music/battle_dark.wav", _battle(108.0, -7, [[57, 60, 64], [53, 57, 60], [55, 58, 62], [52, 56, 59]], "saw", "saw"), 0.8)
	# Frozen Peaks and Sky Islands: bright and quick, in C major.
	_save("res://audio/music/battle_bright.wav", _battle(144.0, 3, [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], "triangle", "square"), 0.8)
	_save("res://audio/music/menu.wav", _menu(), 0.75)
	print("audio written")
	quit()


# --- building blocks ---

func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


## One-pole low-pass coefficient for cutoff `hz`.
func _lp(hz: float) -> float:
	return 1.0 - exp(-TAU * hz / RATE)


## Adds `src` into `dst` starting at `at` seconds, scaled by `gain`.
func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float) -> void:
	var start := int(at * RATE)
	for i in src.size():
		var j := start + i
		if j >= dst.size():
			break
		dst[j] += src[i] * gain


## Noise through a low-pass whose cutoff slides from `from_hz` to `to_hz`, with an
## exponential decay. high = true keeps what the filter removes (a high-pass).
func _noise(seconds: float, from_hz: float, to_hz: float, decay: float, high: bool = false) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var y := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		var a := _lp(lerpf(from_hz, to_hz, t))
		var x := randf_range(-1.0, 1.0)
		y += a * (x - y)
		b[i] = (x - y if high else y) * exp(-t * decay)
	return b


## A sine whose pitch slides from `from_hz` to `to_hz`, decaying.
func _tone(seconds: float, from_hz: float, to_hz: float, decay: float) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / b.size()
		phase += TAU * lerpf(from_hz, to_hz, t * t) / RATE
		b[i] = sin(phase) * exp(-t * decay)
	return b


# --- sound effects ---

## A meaty thwack: a low thump under a burst of soft noise.
func _hit_body() -> PackedFloat32Array:
	var b := _buffer(0.32)
	_mix(b, _tone(0.3, 160.0, 55.0, 7.0), 0.0, 0.9)
	_mix(b, _noise(0.18, 2600.0, 500.0, 9.0), 0.0, 0.8)
	return b


## A hard bonk with a crack on top.
func _hit_head() -> PackedFloat32Array:
	var b := _buffer(0.45)
	_mix(b, _tone(0.4, 420.0, 140.0, 6.0), 0.0, 0.7)
	_mix(b, _noise(0.06, 9000.0, 3000.0, 12.0, true), 0.0, 0.7)
	_mix(b, _tone(0.3, 140.0, 60.0, 8.0), 0.0, 0.6)
	return b


## A wet splat: a squelchy noise burst sliding down, a thud, and drips after.
func _splat() -> PackedFloat32Array:
	var b := _buffer(0.6)
	_mix(b, _noise(0.3, 3000.0, 250.0, 6.0), 0.0, 1.0)
	_mix(b, _tone(0.2, 120.0, 50.0, 9.0), 0.0, 0.6)
	for k in 4:
		_mix(b, _tone(0.05, randf_range(900.0, 1500.0), randf_range(500.0, 800.0), 20.0), 0.25 + k * 0.08, 0.25)
	return b


## Gore: a crunch of bone with a wet tear around it.
func _gore() -> PackedFloat32Array:
	var b := _buffer(0.7)
	_mix(b, _crunch(), 0.0, 0.8)
	_mix(b, _noise(0.5, 2200.0, 300.0, 5.0), 0.02, 0.9)
	_mix(b, _tone(0.35, 90.0, 40.0, 6.0), 0.0, 0.8)
	return b


## Blood pumping out in spurts, fading.
func _gush() -> PackedFloat32Array:
	var b := _buffer(1.5)
	for spurt in 4:
		var n := _noise(0.32, 1800.0, 600.0, 4.0)
		_mix(b, n, spurt * 0.34, 0.9 * pow(0.75, spurt))
	return b


## A blade slicing the air and flesh: a fast bright sweep and a ring.
func _slice() -> PackedFloat32Array:
	var b := _buffer(0.4)
	_mix(b, _noise(0.22, 9000.0, 1800.0, 6.0, true), 0.0, 0.9)
	_mix(b, _tone(0.35, 2400.0, 2100.0, 9.0), 0.02, 0.25)
	_mix(b, _noise(0.15, 1500.0, 400.0, 8.0), 0.08, 0.5)
	return b


## Bones cracking: a rattle of sharp clicks.
func _crunch() -> PackedFloat32Array:
	var b := _buffer(0.35)
	for k in 7:
		_mix(b, _noise(0.025, 7000.0, 2500.0, 18.0, true), k * 0.035 + randf_range(0.0, 0.01), randf_range(0.5, 0.9))
	return b


## A heavy punch: deep thump with a slap on top.
func _punch() -> PackedFloat32Array:
	var b := _buffer(0.35)
	_mix(b, _tone(0.32, 110.0, 42.0, 6.0), 0.0, 1.0)
	_mix(b, _noise(0.08, 5000.0, 1200.0, 10.0), 0.0, 0.7)
	return b



## A crowd roaring: a swell of filtered noise, scattered claps and a few rising "woo"s.
func _cheer() -> PackedFloat32Array:
	var b := _buffer(2.4)
	var y := 0.0
	var a := _lp(1400.0)
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.25) * exp(-maxf(0.0, t - 0.5) * 1.6)
		y += a * (randf_range(-1.0, 1.0) - y)
		b[i] = y * env * 1.6
	for k in 70:
		_mix(b, _noise(0.03, 7000.0, 3000.0, 14.0, true), randf_range(0.05, 1.8), randf_range(0.15, 0.35))
	for k in 6:
		var start := randf_range(0.0, 0.5)
		var voice := _note(randf_range(62.0, 72.0), randf_range(0.5, 0.9), "saw", 0.08, 0.3, 900.0, 0.01)
		_mix(b, voice, start, 0.08)
	return b


## Metal on bone: a bright ring with a hard knock.
func _clang() -> PackedFloat32Array:
	var b := _buffer(0.6)
	for f: float in [820.0, 1290.0, 2010.0]:
		_mix(b, _tone(0.55, f, f * 0.98, 6.0), 0.0, 0.35)
	_mix(b, _noise(0.05, 8000.0, 3000.0, 12.0), 0.0, 0.8)
	return b


## Energy crackle: a falling buzz with fizz on top.
func _zap() -> PackedFloat32Array:
	var b := _note(84.0, 0.05, "square", 0.001, 0.25, 5000.0, 0.02)
	var slide := _tone(0.35, 1600.0, 300.0, 5.0)
	_mix(b, slide, 0.0, 0.5)
	_mix(b, _noise(0.3, 9000.0, 4000.0, 6.0, true), 0.0, 0.4)
	return b


## An explosion: a deep rumble that rolls off slowly.
func _boom() -> PackedFloat32Array:
	var b := _noise(1.2, 900.0, 120.0, 3.5)
	_mix(b, _tone(0.8, 90.0, 30.0, 4.0), 0.0, 1.2)
	_mix(b, _noise(0.08, 6000.0, 2000.0, 10.0), 0.0, 0.6)
	return b


# --- voices ---

## A voice: a buzzy pulse at a pitch sliding from `from_hz` to `to_hz` (with a little
## vibrato), shaped by two vowel formants, under an envelope from `shape(t)`.
func _voice(seconds: float, from_hz: float, to_hz: float, f1: float, f2: float, shape: Callable, vibrato: float = 0.0) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var phase := 0.0
	var r1 := _resonator(f1, 90.0)
	var r2 := _resonator(f2, 140.0)
	var s1 := [0.0, 0.0]
	var s2 := [0.0, 0.0]
	for i in b.size():
		var t := float(i) / b.size()
		var hz := lerpf(from_hz, to_hz, t) * (1.0 + vibrato * sin(TAU * 6.0 * t * seconds))
		phase = fmod(phase + hz / RATE, 1.0)
		var source := (2.0 * phase - 1.0) * 0.7 + randf_range(-0.15, 0.15)
		var y1: float = r1[0] * source + r1[1] * float(s1[0]) + r1[2] * float(s1[1])
		s1[1] = s1[0]
		s1[0] = y1
		var y2: float = r2[0] * source + r2[1] * float(s2[0]) + r2[2] * float(s2[1])
		s2[1] = s2[0]
		s2[0] = y2
		b[i] = (y1 + y2 * 0.6) * float(shape.call(t))
	return b


## Two-pole resonator coefficients [gain, a1, a2] at `hz` with `width` Hz bandwidth.
func _resonator(hz: float, width: float) -> Array:
	var r := exp(-PI * width / RATE)
	var a1 := 2.0 * r * cos(TAU * hz / RATE)
	var a2 := -r * r
	return [1.0 - r, a1, a2]


## Hit: a short grunt, "uhh".
func _voice_hurt() -> PackedFloat32Array:
	return _voice(0.28, 210.0, 150.0, 600.0, 1100.0, func(t: float) -> float: return minf(1.0, t * 12.0) * pow(1.0 - t, 1.5))


## Knocked out: a long falling cry, "aaahhh".
func _voice_die() -> PackedFloat32Array:
	return _voice(1.1, 300.0, 95.0, 780.0, 1250.0, func(t: float) -> float: return minf(1.0, t * 10.0) * pow(1.0 - t, 1.2), 0.03)


## Special charged: a rising power-up yell, "haaa!".
func _voice_charge() -> PackedFloat32Array:
	var b := _voice(0.9, 140.0, 270.0, 720.0, 1300.0, func(t: float) -> float: return minf(1.0, t * 2.5) * (1.0 if t < 0.85 else (1.0 - t) / 0.15), 0.02)
	_mix(b, _noise(0.9, 2500.0, 5000.0, 1.5, true), 0.0, 0.08)
	return b


## Fatality: a triumphant laugh, "ha-ha-HA!".
func _voice_laugh() -> PackedFloat32Array:
	var b := _buffer(0.9)
	for k in 3:
		var pulse := _voice(0.2 if k < 2 else 0.34, 230.0 + k * 20.0, 200.0 + k * 30.0, 750.0, 1200.0, func(t: float) -> float: return minf(1.0, t * 14.0) * pow(1.0 - t, 1.3))
		_mix(b, pulse, k * 0.24, 0.8 if k < 2 else 1.0)
	return b

# --- music ---

func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


func _kick() -> PackedFloat32Array:
	var b := _tone(0.28, 150.0, 42.0, 7.0)
	_mix(b, _noise(0.01, 6000.0, 3000.0, 30.0, true), 0.0, 0.3)
	return b


func _snare() -> PackedFloat32Array:
	var b := _noise(0.2, 9000.0, 3000.0, 9.0, true)
	_mix(b, _tone(0.12, 220.0, 170.0, 10.0), 0.0, 0.5)
	return b


func _hat(open: bool) -> PackedFloat32Array:
	return _noise(0.12 if open else 0.04, 12000.0, 9000.0, 10.0 if open else 25.0, true)


## A note: `shape` saw, square, triangle or pluck; amp envelope with attack/decay.
func _note(midi: float, seconds: float, shape: String, attack: float, release: float, cutoff: float, detune: float = 0.0) -> PackedFloat32Array:
	var b := _buffer(seconds + release)
	var f := _hz(midi)
	var y := 0.0
	var a := _lp(cutoff)
	var phases := [0.0, 0.25]
	for i in b.size():
		var t := float(i) / RATE
		var env := minf(1.0, t / maxf(attack, 0.001))
		if t > seconds:
			env *= exp(-(t - seconds) / maxf(release * 0.35, 0.001))
		var s := 0.0
		for v in (2 if detune > 0.0 else 1):
			var freq := f * (1.0 + (detune if v == 1 else 0.0))
			phases[v] = fmod(float(phases[v]) + freq / RATE, 1.0)
			var p: float = phases[v]
			match shape:
				"saw":
					s += 2.0 * p - 1.0
				"square":
					s += 1.0 if p < 0.5 else -1.0
				"triangle":
					s += 4.0 * absf(p - 0.5) - 1.0
				"pluck":
					s += (2.0 * p - 1.0) * exp(-t * 7.0)
		y += a * (s - y)
		b[i] = y * env
	return b


## A battle track at `bpm`, shifted by `shift` semitones: driving drums, a pumping
## bass, a 16th-note arpeggio, pads over `chords`, and a lead hook (`lead` shape) in
## the second half. 16 bars that loop.
func _battle(bpm: float, shift: int, chords: Array, lead: String, arp: String) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var bars := 16
	var b := _buffer(bars * 4 * beat)
	var kick := _kick()
	var snare := _snare()
	var hat := _hat(false)
	var ohat := _hat(true)
	for bar in bars:
		var chord: Array = chords[bar % 4]
		var t0 := bar * 4 * beat
		for step in 16:
			var t := t0 + step * beat / 4.0
			if step % 8 == 0 or step == 10:
				_mix(b, kick, t, 0.9)
			if step % 8 == 4:
				_mix(b, snare, t, 0.6)
			if bar % 4 == 3 and step >= 12:
				_mix(b, snare, t, 0.35)
			_mix(b, ohat if step % 4 == 2 else hat, t, 0.18 if step % 2 == 0 else 0.1)
			# Bass: eighth notes on the root, jumping an octave on the off-beats.
			if step % 2 == 0:
				var root: int = int(chord[0]) + shift - 24 + (12 if step % 4 == 2 else 0)
				_mix(b, _note(root, beat * 0.4, "square", 0.004, 0.05, 900.0), t, 0.32)
			# Arpeggio over the chord.
			if bar >= 2:
				var tone: int = int(chord[step % 3]) + shift + 12 + (12 if step % 8 >= 4 else 0)
				_mix(b, _note(tone, beat * 0.2, arp, 0.002, 0.08, 3500.0), t, 0.11)
		# Pads under it all.
		for tone: int in chord:
			_mix(b, _note(tone + shift, beat * 3.8, "saw", 0.25, 0.3, 1400.0, 0.004), t0, 0.06)
		# Lead hook in the second half.
		if bar >= 8:
			var hook := [[0, 76, 1.0], [1, 74, 0.5], [1.5, 72, 0.5], [2, 69, 1.5], [3.5, 72, 0.5]]
			if bar % 2 == 1:
				hook = [[0, 72, 0.5], [0.5, 74, 0.5], [1, 76, 1.0], [2, 79, 1.0], [3, 76, 1.0]]
			for n: Array in hook:
				_mix(b, _note(float(n[1]) + shift, beat * float(n[2]) * 0.9, lead, 0.01, 0.12, 2600.0, 0.003), t0 + float(n[0]) * beat, 0.09)
	return b


## Menu: 100 BPM in C major. Warm pads, a plucked arpeggio, a soft beat and a bell-like
## melody. 16 bars that loop.
func _menu() -> PackedFloat32Array:
	var beat := 60.0 / 100.0
	var bars := 16
	var b := _buffer(bars * 4 * beat)
	var kick := _kick()
	var hat := _hat(false)
	var snare := _snare()
	var chords := [[48, 52, 55, 59], [55, 59, 62, 66], [57, 60, 64, 67], [53, 57, 60, 64]]
	var melody := [76, 74, 72, 74, 76, 79, 76, 74, 72, 71, 72, 74, 76, 74, 72, 67]
	for bar in bars:
		var chord: Array = chords[bar % 4]
		var t0 := bar * 4 * beat
		for tone: int in chord:
			_mix(b, _note(tone, beat * 3.9, "saw", 0.6, 0.6, 1000.0, 0.005), t0, 0.055)
		_mix(b, _note(int(chord[0]) - 12, beat * 3.5, "triangle", 0.05, 0.4, 600.0), t0, 0.28)
		for step in 8:
			var t := t0 + step * beat / 2.0
			var tone: int = int(chord[step % 4]) + 12
			_mix(b, _note(tone, beat * 0.4, "pluck", 0.002, 0.2, 3000.0), t, 0.1)
			if bar >= 4:
				if step % 4 == 0:
					_mix(b, kick, t, 0.55)
				if step % 4 == 2:
					_mix(b, snare, t, 0.25)
				_mix(b, hat, t, 0.08)
		if bar >= 8:
			for half in 2:
				var tone: float = melody[((bar - 8) * 2 + half) % melody.size()]
				_mix(b, _note(tone, beat * 1.7, "triangle", 0.01, 0.6, 4000.0), t0 + half * 2.0 * beat, 0.16)
	return b


# --- writing ---

## Normalises to `peak`, soft-clips, and writes a 16-bit mono WAV.
func _save(path: String, samples: PackedFloat32Array, peak: float) -> void:
	var top := 0.0001
	for s in samples:
		top = maxf(top, absf(s))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := tanh(samples[i] / top * peak * 1.2) / tanh(1.2)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(RATE)
	file.store_32(RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
	file.close()
