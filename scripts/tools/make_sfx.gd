extends SceneTree
## Synthesises the placeholder sound effects into res://audio/sfx/ (sfxr-style).
## Re-run after tweaking:  godot --headless --path . -s res://scripts/tools/make_sfx.gd

const RATE := 22050
const OUT_DIR := "res://audio/sfx"

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save("whoosh", _whoosh(0.34))
	_save("sling", _mix(_sweep(0.12, 260.0, 900.0, 0.05, 18.0, 1), _noise(0.06, 0.5, 60.0), 0.3))
	_save("twang", _pluck(0.4, 196.0))
	_save("hit_body", _mix(_sweep(0.3, 160.0, 55.0, 0.06, 12.0, 2), _noise(0.12, 0.25, 35.0), 0.6))
	_save("hit_head", _mix(_mix(_sweep(0.4, 950.0, 420.0, 0.05, 10.0, 2), _sweep(0.4, 1900.0, 1900.0, 1.0, 9.0, 1), 0.3), _sweep(0.25, 150.0, 60.0, 0.05, 14.0, 1), 0.7))
	_save("tick", _mix(_noise(0.07, 0.9, 70.0), _sweep(0.07, 2300.0, 1800.0, 0.03, 60.0, 1), 0.5))
	_save("thunk", _mix(_noise(0.16, 0.35, 45.0), _sweep(0.18, 240.0, 140.0, 0.04, 24.0, 1), 0.8))
	_save("ground", _mix(_noise(0.3, 0.12, 16.0), _sweep(0.3, 95.0, 55.0, 0.08, 13.0, 1), 0.7))
	_save("ko", _notes([[392.0, 0.22], [370.0, 0.22], [349.0, 0.22], [330.0, 0.75]], true))
	_save("win", _notes([[523.0, 0.1], [659.0, 0.1], [784.0, 0.1], [1047.0, 0.45]], false))
	_save("lose", _notes([[523.0, 0.14], [440.0, 0.14], [349.0, 0.14], [262.0, 0.5]], false))
	_save("turn", _mix(_sweep(0.12, 659.0, 659.0, 1.0, 22.0, 1), _delay(_sweep(0.22, 880.0, 880.0, 1.0, 16.0, 1), 0.07), 0.9))
	_save("click", _sweep(0.06, 1200.0, 900.0, 0.02, 55.0, 1))
	print("Sound effects written to " + OUT_DIR)
	quit()


func _save(sound_name: String, samples: PackedFloat32Array) -> void:
	samples = _normalize(samples, 0.85)
	var fade := mini(samples.size(), int(RATE * 0.005))
	for i in fade:
		samples[samples.size() - 1 - i] *= float(i) / fade
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.save_to_wav(ProjectSettings.globalize_path("%s/%s.wav" % [OUT_DIR, sound_name]))


## A tone gliding from f0 to f1 (glide = time constant in s), decaying at `decay` per s.
## harmonics > 1 adds odd harmonics for a rounder, more cartoony sound.
func _sweep(duration: float, f0: float, f1: float, glide: float, decay: float, harmonics: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (f1 + (f0 - f1) * exp(-t / glide)) / RATE
		var s := 0.0
		for h in harmonics:
			var n := 2 * h + 1
			s += sin(phase * n) / n
		out[i] = s * exp(-t * decay) * minf(1.0, t * 400.0)
	return out


## Filtered noise. smoothing 0..1: low is a dull rumble, high is a bright hiss.
func _noise(duration: float, smoothing: float, decay: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	var y := 0.0
	for i in out.size():
		var t := float(i) / RATE
		y += smoothing * (_rng.randf_range(-1.0, 1.0) - y)
		out[i] = y * exp(-t * decay)
	return out


## Air rushing past: band-passed noise whose brightness and volume swell and fade.
func _whoosh(duration: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	var fast := 0.0
	var slow := 0.0
	for i in out.size():
		var p := float(i) / out.size()
		var swell := sin(PI * p)
		fast += (0.04 + 0.3 * swell) * (_rng.randf_range(-1.0, 1.0) - fast)
		slow += 0.01 * (fast - slow)
		out[i] = (fast - slow) * swell * swell
	return out


## A plucked string (Karplus-Strong), for the bow.
func _pluck(duration: float, freq: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(duration * RATE))
	var period := int(RATE / freq)
	var buffer := PackedFloat32Array()
	buffer.resize(period)
	for i in period:
		buffer[i] = _rng.randf_range(-1.0, 1.0)
	for i in out.size():
		var k := i % period
		out[i] = buffer[k]
		buffer[k] = 0.996 * 0.5 * (buffer[k] + buffer[(k + 1) % period])
	return out


## A little tune of [frequency, seconds] pairs. Vibrato wobbles the last note.
func _notes(notes: Array, vibrato_last: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var phase := 0.0
	for n in notes.size():
		var freq: float = notes[n][0]
		var length := int(float(notes[n][1]) * RATE)
		var wobble := vibrato_last and n == notes.size() - 1
		for i in length:
			var t := float(i) / RATE
			var f := freq * (1.0 + (0.025 * sin(TAU * 6.0 * t) if wobble else 0.0))
			phase += TAU * f / RATE
			var env := minf(1.0, t * 200.0) * minf(1.0, float(length - i) / (RATE * 0.03))
			out.append((sin(phase) + sin(phase * 3.0) / 3.0 + sin(phase * 5.0) / 6.0) * env * 0.6)
	return out


func _delay(samples: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	out.append_array(samples)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, b_gain: float) -> PackedFloat32Array:
	var out := a.duplicate()
	if b.size() > out.size():
		out.resize(b.size())
	for i in b.size():
		out[i] += b[i] * b_gain
	return out


func _normalize(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var loudest := 0.0001
	for s in samples:
		loudest = maxf(loudest, absf(s))
	for i in samples.size():
		samples[i] *= peak / loudest
	return samples
