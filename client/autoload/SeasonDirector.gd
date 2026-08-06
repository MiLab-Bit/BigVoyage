extends Node
## 四季赛季状态机：S1 冻洋 → S2 渊海 → S3 瀚海 → S4 信风带
## 节拍 6-18-30-30-6（合计 90）；默认全海 36 岛

signal season_changed(season_id: String)
signal phase_changed(phase_id: String)

var seasons: Dictionary = {}
var current_season: String = "S1"
var season_day: int = 1
var phase_id: String = "drift"

const PHASES := [
	{"id": "drift", "days": 6, "name": "漂流"},
	{"id": "awaken", "days": 18, "name": "觉醒"},
	{"id": "expand", "days": 30, "name": "扩张"},
	{"id": "contend", "days": 30, "name": "争锋"},
	{"id": "settle", "days": 6, "name": "结算"},
]

func _ready() -> void:
	seasons = GameData.seasons
	current_season = str(GameState.tutorial_flags.get("season_id", "S1"))
	season_day = int(GameState.tutorial_flags.get("season_day", 1))
	_recompute_phase()
	GameState.day_advanced.connect(_on_day)
	# 默认全海
	if bool(GameData.constants.get("FULL_WORLD_DEFAULT", true)):
		App.feature_flags["full_world"] = true
		GameState.tutorial_flags["unlock_all_seas"] = true
	if App.flag("full_world", true) or bool(GameState.tutorial_flags.get("unlock_all_seas", false)):
		App.feature_flags["full_world"] = true
		GameData.reload_world_filter(active_sea_ids())

func active_sea_ids() -> Array:
	if App.flag("full_world", true) or bool(GameState.tutorial_flags.get("unlock_all_seas", false)):
		return ["frozen", "abyss", "blaze", "tradewind"]
	var order := ["S1", "S2", "S3", "S4"]
	var seas := ["frozen", "abyss", "blaze", "tradewind"]
	var idx := order.find(current_season)
	if idx < 0:
		idx = 0
	var out: Array = []
	for i in range(idx + 1):
		out.append(seas[i])
	return out

func season_label() -> String:
	var s: Dictionary = seasons.get(current_season, {})
	return "%s · 第 %d 日 · %s" % [
		str(s.get("name", current_season)),
		season_day,
		_phase_name(),
	]

func debug_unlock_all() -> void:
	GameState.tutorial_flags["unlock_all_seas"] = true
	App.feature_flags["full_world"] = true
	GameData.reload_world_filter(active_sea_ids())
	season_changed.emit(current_season)
	GameState.emit_signal("toast", "全量海域已解锁（调试）· 重载海图")
	GameState.save_game()
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()

func advance_season() -> void:
	var order := ["S1", "S2", "S3", "S4"]
	var i := order.find(current_season)
	if i < 0 or i >= order.size() - 1:
		GameState.emit_signal("toast", "已是终季切片")
		return
	current_season = order[i + 1]
	season_day = 1
	GameState.tutorial_flags["season_id"] = current_season
	GameState.tutorial_flags["season_day"] = season_day
	_recompute_phase()
	GameData.reload_world_filter(active_sea_ids())
	season_changed.emit(current_season)
	GameState.save_game()
	GameState.emit_signal("toast", "进入 %s" % seasons.get(current_season, {}).get("name", current_season))
	if get_tree().current_scene != null:
		get_tree().reload_current_scene()

func _on_day(_d: int) -> void:
	season_day += 1
	if season_day > 90:
		season_day = 1
		advance_season()
		return
	GameState.tutorial_flags["season_day"] = season_day
	var old := phase_id
	_recompute_phase()
	if old != phase_id:
		phase_changed.emit(phase_id)

func _recompute_phase() -> void:
	var acc := 0
	for p in PHASES:
		acc += int(p["days"])
		if season_day <= acc:
			phase_id = str(p["id"])
			return
	phase_id = "settle"

func _phase_name() -> String:
	for p in PHASES:
		if str(p["id"]) == phase_id:
			return str(p["name"])
	return phase_id
