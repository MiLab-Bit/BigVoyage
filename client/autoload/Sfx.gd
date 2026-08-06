extends Node
## 优先播 assets/audio/sfx；缺失则程序合成兜底（不挡玩法）

var _player: AudioStreamPlayer
var _file_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _gen: AudioStreamGenerator

func _ready() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = 44100
	_gen.buffer_length = 0.3
	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	_player.volume_db = -8.0
	add_child(_player)
	_file_player = AudioStreamPlayer.new()
	_file_player.volume_db = -6.0
	add_child(_file_player)

func play_event(event_id: String) -> void:
	var path := AssetDB.sfx_path(event_id)
	if path == "":
		# 兼容无 sfx_ 前缀
		path = AssetDB.sfx_path("sfx_" + event_id) if not event_id.begins_with("sfx_") else ""
	if path != "":
		var stream = load(path)
		if stream != null:
			_file_player.stream = stream
			_file_player.play()
			return
	# fallback procedural by family
	if event_id.contains("deny") or event_id.contains("error") or event_id.contains("warn"):
		play_deny()
	elif event_id.contains("hit") or event_id.contains("dot"):
		play_hit()
	elif event_id.contains("restraint"):
		play_restraint()
	elif event_id.contains("sail"):
		play_sail()
	elif event_id.contains("day"):
		play_day()
	else:
		play_select()

func play_ok() -> void:
	if not _try_file("sfx_ui_ok") and not _try_file("sfx_ui_confirm"):
		_beep([523.25, 659.25], [0.06, 0.09], 0.22)

func play_deny() -> void:
	if not _try_file("sfx_ui_deny") and not _try_file("sfx_ui_error"):
		_beep([220.0, 170.0], [0.08, 0.1], 0.28)

func play_hit() -> void:
	if not _try_file("sfx_btl_hit_flame"):
		_noise_burst(0.05, 0.18)

func play_restraint() -> void:
	if not _try_file("sfx_btl_restraint_flame"):
		_beep([392.0, 523.25, 659.25], [0.05, 0.05, 0.12], 0.25)

func play_sail() -> void:
	if not _try_file("sfx_nav_set_sail"):
		_beep([196.0, 246.94, 293.66], [0.07, 0.07, 0.14], 0.18)

func play_select() -> void:
	if not _try_file("sfx_ui_click") and not _try_file("sfx_ui_select"):
		_beep([440.0], [0.04], 0.12)

func play_day() -> void:
	if not _try_file("sfx_nav_day_advance"):
		_beep([261.63, 329.63, 392.0], [0.06, 0.06, 0.1], 0.16)

func _try_file(event_id: String) -> bool:
	var path := AssetDB.sfx_path(event_id)
	if path == "":
		return false
	var stream = load(path)
	if stream == null:
		return false
	_file_player.stream = stream
	_file_player.play()
	return true

func _ensure_playback() -> void:
	if not _player.playing:
		_player.play()
	_playback = _player.get_stream_playback()

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
			var env := exp(-4.0 * t / max(dur, 1e-3))
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
