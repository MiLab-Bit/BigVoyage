extends Node
## 运营：活动日历 / 公告 / 海域限定经济加成

signal event_started(event_id: String)
signal announcement(msg: String)

var calendar: Array = []
var _fired_starts: Dictionary = {}

func _ready() -> void:
	if FileAccess.file_exists("res://data/ops_calendar.json"):
		var f := FileAccess.open("res://data/ops_calendar.json", FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			calendar = parsed.get("events", [])
	if not GameState.day_advanced.is_connected(_on_day):
		GameState.day_advanced.connect(_on_day)
	call_deferred("_pull_sidecar")
	call_deferred("_check_starts")

func _on_day(_day: int) -> void:
	_check_starts()

func _check_starts() -> void:
	for e in active_events():
		var eid := str(e.get("id", ""))
		if eid == "" or _fired_starts.has(eid):
			continue
		if int(e.get("day_from", -1)) == GameState.day:
			_fired_starts[eid] = true
			event_started.emit(eid)
			announcement.emit("活动开启：%s" % e.get("name", eid))
			GameState.emit_signal("toast", "活动：%s" % e.get("name", eid))

func _pull_sidecar() -> void:
	if ChainGateway == null or ChainGateway.mock_enabled:
		return
	var remote: Dictionary = ChainGateway.sidecar_get("/ops/events")
	if bool(remote.get("ok", false)):
		for e in remote.get("events", []):
			calendar.append(e)
		for a in remote.get("announcements", []):
			announcement.emit(str(a.get("msg", "")))

func nudge_soft_features() -> void:
	announcement.emit("运营日历：赛季节拍活动已排期；battle/boss/season 会改掉率与守卫。")
	GameState.emit_signal("toast", "运营日历已就绪")

## POI 船员/船骸掉率倍率（battle / boss / season）
func crew_drop_mult(island_id: String = "") -> float:
	var m := 1.0
	var sea := ""
	var is_boss := false
	if island_id != "" and GameData != null:
		var isl: Dictionary = GameData.islands.get(island_id, {})
		sea = str(isl.get("sea", ""))
		is_boss = str(isl.get("tier", "")) == "boss" or island_id in ["FR_12", "AB_09", "BL_09", "TW_09"]
	for e in active_events():
		var kind := str(e.get("kind", ""))
		if kind not in ["battle", "boss", "season"]:
			continue
		if kind == "boss":
			var bosses: Array = e.get("boss_islands", [])
			if island_id != "" and not bosses.is_empty() and not bosses.has(island_id) and not is_boss:
				continue
		var sea_f := str(e.get("sea", ""))
		if sea_f != "" and sea != "" and sea_f != sea:
			continue
		if e.has("drop_mult"):
			m *= float(e.get("drop_mult", 1.0))
	return m

## 守卫 HP 倍率（battle / boss / season）
func guard_hp_mult(island_id: String = "", sea: String = "") -> float:
	var m := 1.0
	var is_boss := island_id in ["FR_12", "AB_09", "BL_09", "TW_09"]
	if island_id != "" and GameData != null:
		var isl: Dictionary = GameData.islands.get(island_id, {})
		if sea == "":
			sea = str(isl.get("sea", ""))
		if str(isl.get("tier", "")) == "boss":
			is_boss = true
	for e in active_events():
		var kind := str(e.get("kind", ""))
		if kind not in ["battle", "boss", "season"]:
			continue
		if kind == "boss":
			var bosses: Array = e.get("boss_islands", [])
			if not bosses.is_empty() and island_id != "" and not bosses.has(island_id) and not is_boss:
				continue
		var sea_f := str(e.get("sea", ""))
		if sea_f != "" and sea != "" and sea_f != sea:
			continue
		if e.has("guard_mult"):
			m *= float(e.get("guard_mult", 1.0))
	return m

func gvg_loot_mult() -> float:
	var m := 1.0
	for e in active_events():
		if str(e.get("kind", "")) not in ["battle", "boss", "season"]:
			continue
		if e.has("gvg_loot_mult"):
			m *= float(e.get("gvg_loot_mult", 1.0))
	return m

func trade_risk_mult(sea: String = "") -> float:
	var m := 1.0
	for e in active_events():
		if str(e.get("kind", "")) != "economy":
			continue
		var sea_f := str(e.get("sea", ""))
		if sea_f != "" and sea != "" and sea_f != sea:
			continue
		if e.has("risk_mult"):
			m *= float(e.get("risk_mult", 1.0))
	return m

func active_events(day: int = -1) -> Array:
	var d := day if day >= 0 else GameState.day
	var out: Array = []
	for e in calendar:
		var a := int(e.get("day_from", 1))
		var b := int(e.get("day_to", 9999))
		if d >= a and d <= b:
			out.append(e)
	return out

func open_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 22
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = VoyageTheme.OVERLAY_DIM
	dim.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			layer.queue_free()
	)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "VoyageCopperPanel"
	panel.custom_minimum_size = Vector2(560, 460)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -230
	panel.offset_bottom = 230
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "运营日历"
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.custom_minimum_size = Vector2(0, 300)
	var lines: PackedStringArray = []
	lines.append("赛季：%s · 第 %d 日" % [SeasonDirector.season_label(), GameState.day])
	lines.append("海域解锁：%s" % ", ".join(SeasonDirector.active_sea_ids()))
	lines.append("")
	var evs := active_events()
	if evs.is_empty():
		lines.append("今日无活动。")
	else:
		lines.append("[b]进行中[/b]")
		for e in evs:
			var sea_tag := ""
			if str(e.get("sea", "")) != "":
				sea_tag = " · 限 %s" % e.get("sea")
			var mult_tag := ""
			if e.has("mult"):
				mult_tag = " · 贸×%.2f" % float(e.get("mult"))
			var fx: PackedStringArray = []
			if e.has("drop_mult"):
				fx.append("掉×%.2f" % float(e.drop_mult))
			if e.has("guard_mult"):
				fx.append("卫×%.2f" % float(e.guard_mult))
			if e.has("gvg_loot_mult"):
				fx.append("GVG×%.2f" % float(e.gvg_loot_mult))
			if e.has("risk_mult"):
				fx.append("险×%.2f" % float(e.risk_mult))
			var fx_tag := (" · " + ", ".join(fx)) if not fx.is_empty() else ""
			lines.append("• [b]%s[/b]（%d–%d · %s%s%s%s）\n  %s" % [
				e.get("name", e.get("id", "")),
				int(e.get("day_from", 0)), int(e.get("day_to", 0)),
				e.get("kind", "?"), sea_tag, mult_tag, fx_tag,
				e.get("desc", ""),
			])
	lines.append("\n本机完整体验 · 运营日历已生效")
	rtl.text = "\n".join(lines)
	v.add_child(rtl)
	var row := HBoxContainer.new()
	v.add_child(row)
	var btn_next := Button.new()
	btn_next.text = "推进赛季"
	btn_next.pressed.connect(func():
		SeasonDirector.advance_season()
		Bgm.play_map()
		layer.queue_free()
	)
	row.add_child(btn_next)
	var btn_close := Button.new()
	btn_close.text = "关闭"
	btn_close.pressed.connect(layer.queue_free)
	row.add_child(btn_close)
	layer.add_child(panel)
	Juice.present_overlay(dim, panel)
	get_tree().root.add_child(layer)
