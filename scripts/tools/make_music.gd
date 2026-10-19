extends SceneTree
## Synthesises the two music loops into res://audio/music/ (chiptune style: bass,
## arpeggiated chords, a lead melody and drums). Notes that ring past the end wrap
## round to the start, so the loops are seamless.
##   godot --headless --path . -s res://scripts/tools/make_music.gd

const RATE := 22050
const OUT_DIR := "res://audio/music"
const A3 := 220.0

## Chords as semitones from A3, with a minor/major flag.
const BATTLE_CHORDS := [[0, true], [-4, false], [3, false], [-2, false]]  # Am F C G
const MENU_CHORDS := [[3, false], [-2, false], [0, true], [-4, false]]  # C G Am F

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_rng.seed = 7
	_save("battle", _track(132.0, BATTLE_CHORDS, true))
	_rng.seed = 3
	_save("menu", _track(96.0, MENU_CHORDS, false))
	print("Music written to " + OUT_DIR)
	quit()


func _track(bpm: float, chords: Array, battle: bool) -> PackedFloat32Array:
	var step := int(RATE * 60.0 / bpm / 4.0)  # one 16th note
	var bars := 8
	var buffer := PackedFloat32Array()
	buffer.resize(step * 16 * bars)
	var melody := _melody(bars, battle)
	for bar in bars:
		var chord: Array = chords[bar % chords.size()]
		var root: int = chord[0]
		var tones := [root, root + (3 if chord[1] else 4), root + 7]
		var bar_start := bar * 16 * step
		for s in 16:
			var at := bar_start + s * step
			# Bass: root and octave on 8ths.
			if s % 2 == 0:
				var bass_note: int = root - 12 + (12 if s % 8 == 6 else 0)
				_note(buffer, at, _freq(bass_note), step * 2, &"triangle", 0.34, 6.0)
			# Arpeggio over the chord in 16ths.
			var arp: int = tones[s % 3] + (12 if (s / 3) % 2 == 1 else 0)
			_note(buffer, at, _freq(arp + 12), step, &"square12", 0.07 if battle else 0.06, 14.0)
			# Drums.
			if battle:
				if s % 4 == 0:
					_kick(buffer, at)
				if s % 8 == 4:
					_snare(buffer, at)
				if s % 2 == 1:
					_hat(buffer, at, 0.05)
			else:
				if s % 8 == 0:
					_kick(buffer, at, 0.35)
				if s % 4 == 2:
					_hat(buffer, at, 0.035)
		# Lead melody.
		for hit: Array in melody[bar]:
			_note(buffer, bar_start + int(hit[0]) * step, _freq(root + int(hit[1]) + 12), int(hit[2]) * step, &"square25", 0.11 if battle else 0.09, 3.5, true)
	return buffer


## Per bar, a list of [step, semitone-above-root, length-in-steps] from a pentatonic
## scale. Bars 1-2 set a motif; later bars repeat it with small changes.
func _melody(bars: int, battle: bool) -> Array:
	var scale := [0, 3, 5, 7, 10, 12, 15] if battle else [0, 2, 4, 7, 9, 12, 14]
	var motif := []
	var s := 0
	while s < 16:
		var length: int = [2, 2, 4, 1, 3][_rng.randi() % 5] if battle else [2, 4, 4, 6][_rng.randi() % 4]
		if _rng.randf() < 0.8:
			motif.append([s, scale[_rng.randi() % scale.size()], mini(length, 16 - s)])
		s += length
	var result := []
	for bar in bars:
		var notes := []
		for hit: Array in motif:
			var pitch: int = hit[1]
			if bar % 4 == 3 and _rng.randf() < 0.5:
				pitch = scale[_rng.randi() % scale.size()]
			notes.append([hit[0], pitch, hit[2]])
		# The first two bars are quieter: just the groove.
		result.append(notes if bar >= 2 else [])
	return result


func _freq(semitones_from_a3: int) -> float:
	return A3 * pow(2.0, semitones_from_a3 / 12.0)


func _note(buffer: PackedFloat32Array, start: int, freq: float, length: int, wave: StringName, volume: float, decay: float, vibrato: bool = false) -> void:
	var size := buffer.size()
	var phase := 0.0
	var total := length + int(RATE * 0.05)
	for i in total:
		var t := float(i) / RATE
		var f := freq * (1.0 + (0.012 * sin(TAU * 5.5 * t) if vibrato and t > 0.12 else 0.0))
		phase = fmod(phase + f / RATE, 1.0)
		var sample := 0.0
		match wave:
			&"triangle":
				sample = 4.0 * absf(phase - 0.5) - 1.0
			&"square12":
				sample = 1.0 if phase < 0.125 else -0.3
			_:
				sample = 1.0 if phase < 0.25 else -0.5
		var env := minf(1.0, t * 300.0) * exp(-t * decay)
		if i > length:
			env *= 1.0 - float(i - length) / (total - length)
		var index := (start + i) % size
		buffer[index] += sample * env * volume


func _kick(buffer: PackedFloat32Array, start: int, volume: float = 0.5) -> void:
	var phase := 0.0
	for i in int(RATE * 0.18):
		var t := float(i) / RATE
		phase += TAU * (50.0 + 110.0 * exp(-t * 30.0)) / RATE
		buffer[(start + i) % buffer.size()] += sin(phase) * exp(-t * 18.0) * volume


func _snare(buffer: PackedFloat32Array, start: int) -> void:
	var y := 0.0
	for i in int(RATE * 0.16):
		var t := float(i) / RATE
		y += 0.6 * (_rng.randf_range(-1.0, 1.0) - y)
		var tone := sin(TAU * 190.0 * t) * exp(-t * 30.0) * 0.3
		buffer[(start + i) % buffer.size()] += (y * exp(-t * 22.0) * 0.28) + tone * 0.4


func _hat(buffer: PackedFloat32Array, start: int, volume: float) -> void:
	var last := 0.0
	for i in int(RATE * 0.04):
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		buffer[(start + i) % buffer.size()] += (noise - last) * exp(-t * 90.0) * volume
		last = noise


func _save(track_name: String, samples: PackedFloat32Array) -> void:
	var loudest := 0.0001
	for s in samples:
		loudest = maxf(loudest, absf(s))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] / loudest * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.save_to_wav(ProjectSettings.globalize_path("%s/%s.wav" % [OUT_DIR, track_name]))
