extends Node
## BGM：按当前海域切换床景/紧张/战斗/Boss 曲；缺轨回退冻洋

var _player: AudioStreamPlayer
var _current := ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -10.0
	add_child(_player)

func current_sea() -> String:
	if Engine.get_main_loop() == null:
		return "frozen"
	var gd = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameData")
	var gs = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	if gd == null or gs == null:
		return "frozen"
	return str(gd.islands.get(gs.current_island, {}).get("sea", "frozen"))

func play(key: String, fade: float = 0.4) -> void:
	if key == _current and _player.playing:
		return
	var path := AssetDB.music_path(key)
	if path == "":
		return
	var stream = load(path)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = not key.begins_with("stinger_") and not key.contains("short") and not key.contains("climax") and not key.contains("cutscene")
		if key.begins_with("bgm_") and not key.contains("short"):
			(stream as AudioStreamMP3).loop = true
	_player.stream = stream
	_player.play()
	_current = key
	if fade > 0.0:
		_player.volume_db = -40.0
		var tw := create_tween()
		tw.tween_property(_player, "volume_db", -10.0, fade)

func stop(fade: float = 0.3) -> void:
	if not _player.playing:
		return
	if fade <= 0.0:
		_player.stop()
		_current = ""
		return
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_player.stop()
		_current = ""
		_player.volume_db = -10.0
	)

func play_boot() -> void:
	play("bgm_menu_main")

func play_map() -> void:
	_play_first(_map_keys(current_sea()))

func play_map_tense() -> void:
	_play_first(_tense_keys(current_sea()))

func play_battle() -> void:
	_play_first(_battle_keys(current_sea()))

func play_boss(sea: String = "") -> void:
	var s := sea if sea != "" else current_sea()
	_play_first(_boss_keys(s))

func play_climax() -> void:
	play("bgm_battle_climax", 0.15)

func play_victory_once() -> void:
	_play_oneshot("bgm_victory_short")

func play_defeat_once() -> void:
	_play_oneshot("bgm_defeat_short")

func play_gacha() -> void:
	play("bgm_gacha_bed")

func play_leit(sys: String) -> void:
	_play_oneshot("stinger_leit_%s" % sys)

func _map_keys(sea: String) -> PackedStringArray:
	match sea:
		"abyss":
			return PackedStringArray(["bgm_sea_abyss_bed", "bgm_sea_frozen_bed"])
		"blaze":
			return PackedStringArray(["bgm_sea_hanhai_bed", "bgm_sea_blaze_bed", "bgm_sea_frozen_bed"])
		"tradewind":
			return PackedStringArray(["bgm_sea_tradewind_bed", "bgm_sea_frozen_bed"])
		_:
			return PackedStringArray(["bgm_sea_frozen_bed", "bgm_map_frozen"])

func _tense_keys(sea: String) -> PackedStringArray:
	match sea:
		"abyss":
			return PackedStringArray(["bgm_sea_abyss_tense", "bgm_sea_abyss_battle", "bgm_sea_frozen_tense"])
		"blaze":
			return PackedStringArray(["bgm_sea_blaze_tense", "bgm_sea_hanhai_tense", "bgm_sea_hanhai_battle", "bgm_sea_frozen_tense"])
		"tradewind":
			return PackedStringArray(["bgm_sea_tradewind_tense", "bgm_sea_tradewind_battle", "bgm_sea_frozen_tense"])
		_:
			return PackedStringArray(["bgm_sea_frozen_tense", "bgm_battle_frozen"])

func _battle_keys(sea: String) -> PackedStringArray:
	match sea:
		"abyss":
			return PackedStringArray(["bgm_sea_abyss_battle", "bgm_battle_frozen", "bgm_battle"])
		"blaze":
			return PackedStringArray(["bgm_sea_hanhai_battle", "bgm_sea_blaze_battle", "bgm_battle_frozen"])
		"tradewind":
			return PackedStringArray(["bgm_sea_tradewind_battle", "bgm_battle_frozen"])
		_:
			return PackedStringArray(["bgm_battle_frozen", "bgm_battle"])

func _boss_keys(sea: String) -> PackedStringArray:
	match sea:
		"abyss":
			return PackedStringArray(["bgm_boss_abyss", "bgm_boss_herald", "bgm_sea_abyss_battle"])
		"blaze":
			return PackedStringArray(["bgm_boss_blaze", "bgm_boss_hanhai", "bgm_battle_climax"])
		"tradewind":
			return PackedStringArray(["bgm_boss_tradewind", "bgm_sea_tradewind_battle", "bgm_boss_herald"])
		_:
			return PackedStringArray(["bgm_boss_frozen", "bgm_boss_warden", "bgm_boss_herald", "bgm_battle_climax"])

func _play_first(keys: PackedStringArray) -> void:
	for k in keys:
		if AssetDB.music_path(k) != "":
			play(k)
			return

func _play_oneshot(key: String) -> void:
	var path := AssetDB.music_path(key)
	if path == "":
		return
	var stream = load(path)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	_player.stream = stream
	_player.play()
	_current = key
