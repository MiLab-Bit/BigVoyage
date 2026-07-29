extends Node
## 轻量程序音效（AudioStreamGenerator），不依赖外部 wav

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _gen: AudioStreamGenerator
var _busy := false

func _ready() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = 44100
	_gen.buffer_length = 0.3
	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	_player.volume_db = -8.0
	add_child(_player)

func _ensure_playback() -> void:
	if not _player.playing:
		_player.play()
	_playback = _player.get_stream_playback()

func play_ok() -> void:
	_beep([523.25, 659.25], [0.06, 0.09], 0.22)

func play_deny() -> void:
	_beep([220.0, 170.0], [0.08, 0.1], 0.28)

func play_hit() -> void:
	_noise_burst(0.05, 0.18)

func play_restraint() -> void:
	_beep([392.0, 523.25, 659.25], [0.05, 0.05, 0.12], 0.25)

func play_sail() -> void:
	_beep([196.0, 246.94, 293.66], [0.07, 0.07, 0.14], 0.18)

func play_select() -> void:
	_beep([440.0], [0.04], 0.12)

func play_day() -> void:
	_beep([261.63, 329.63, 392.0], [0.06, 0.06, 0.1], 0.16)

func _beep(freqs: Array, durs: Array, amp: float) -> void:
	_ensure_playback()
	if _playback == null:
		return
	var rate := 44100.0
	for i in freqs.size():
		var f: float = freqs[i]
		var dur: float = durs[i] if i < durs.size() else 0.08
		var n := int(dur * rate)
		for s in n:
			var t := float(s) / rate
			var env := exp(-4.0 * t / max(dur, 0.01))
			var sample := amp * env * sin(TAU * f * t)
			_playback.push_frame(Vector2(sample, sample))

func _noise_burst(dur: float, amp: float) -> void:
	_ensure_playback()
	if _playback == null:
		return
	var n := int(dur * 44100.0)
	for s in n:
		var t := float(s) / 44100.0
		var env := exp(-12.0 * t)
		var sample := amp * env * (randf() * 2.0 - 1.0)
		_playback.push_frame(Vector2(sample, sample))
