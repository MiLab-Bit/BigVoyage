extends Node
## Day0–2 强制三步引导（M6）：苏醒 → 顺流靠岛 → 首次 POI → 首占岛
## 贸易/联盟为软引导（Demo 仅 toast 提示）

signal step_changed(step_id: String)
signal tutorial_completed

const STEPS := [
	{"id": "wake", "title": "木筏苏醒", "body": "你在霜锚港醒来。点选相邻岛屿，准备出航。", "mandatory": true},
	{"id": "sail", "title": "顺流靠岛", "body": "消耗 1 体力出航到相邻岛。洋流即航线。", "mandatory": true},
	{"id": "poi", "title": "首次探索", "body": "在当前岛探索 POI（6 体力），收集战略资源或船员。", "mandatory": true},
	{"id": "capture", "title": "首占岛", "body": "击败护岛者或宣示主权，占领岛屿开始日产。", "mandatory": true},
	{"id": "soft_trade", "title": "成长线", "body": "贸易、科技与赛季联航已在系统坞开放。", "mandatory": false},
	{"id": "soft_league", "title": "联盟（软）", "body": "联盟入口为全量运营功能，当前为桩。", "mandatory": false},
]

var enabled := true
var _idx := 0
var _banner: CanvasLayer

func _ready() -> void:
	await get_tree().process_frame
	enabled = App.flag("tutorial", true)
	if not enabled:
		return
	EventBus.sailed.connect(_on_sailed)
	EventBus.poi_resolved.connect(_on_poi)
	EventBus.island_captured.connect(_on_capture)
	_sync_from_flags()
	if not bool(GameState.tutorial_flags.get("tutorial_done", false)):
		call_deferred("show_current")

func _sync_from_flags() -> void:
	var f := GameState.tutorial_flags
	if bool(f.get("capture_done", false)) or GameState.owned_islands.size() > 1:
		_idx = 4
	elif bool(f.get("first_poi", false)):
		_idx = 3
	elif bool(f.get("first_sail", false)):
		_idx = 2
	elif bool(f.get("wake_seen", false)):
		_idx = 1
	else:
		_idx = 0

func current_step() -> Dictionary:
	if _idx >= STEPS.size():
		return {}
	return STEPS[_idx]

func show_current() -> void:
	if not enabled or bool(GameState.tutorial_flags.get("tutorial_done", false)):
		return
	var step: Dictionary = current_step()
	if step.is_empty():
		_complete()
		return
	_ensure_banner()
	var title: Label = _banner.get_node("Panel/Margin/VBox/Title")
	var body: RichTextLabel = _banner.get_node("Panel/Margin/VBox/Body")
	var prog: Label = _banner.get_node("Panel/Margin/VBox/Prog")
	title.text = "引导 · %s" % step.get("title", "")
	body.text = str(step.get("body", ""))
	prog.text = "步骤 %d / %d%s" % [
		_idx + 1, STEPS.size(),
		" · 强制" if bool(step.get("mandatory", true)) else " · 软引导",
	]
	_banner.visible = true
	step_changed.emit(str(step.get("id", "")))
	if str(step.get("id", "")) == "wake":
		GameState.tutorial_flags["wake_seen"] = true

func advance(reason: String = "") -> void:
	if not enabled:
		return
	_idx = mini(_idx + 1, STEPS.size())
	if _idx >= 4:
		# 强制三步+占岛完成后进入软引导或结束
		if _idx >= STEPS.size() or reason == "force_done":
			_complete()
			return
	show_current()
	GameState.save_game()

func _on_sailed(_from: String, _to: String) -> void:
	if str(current_step().get("id", "")) == "sail" or str(current_step().get("id", "")) == "wake":
		GameState.tutorial_flags["first_sail"] = true
		if str(current_step().get("id", "")) == "wake":
			_idx = 1
		advance("sail")

func _on_poi(_island: String, _result: Dictionary) -> void:
	if str(current_step().get("id", "")) == "poi":
		advance("poi")

func _on_capture(_island: String) -> void:
	GameState.tutorial_flags["capture_done"] = true
	if str(current_step().get("id", "")) == "capture":
		advance("capture")
		# 软引导两步快速闪过后完成
		await get_tree().create_timer(2.2).timeout
		if enabled and not bool(GameState.tutorial_flags.get("tutorial_done", false)):
			_idx = STEPS.size()
			_complete()

func _complete() -> void:
	GameState.tutorial_flags["tutorial_done"] = true
	GameState.save_game()
	if _banner:
		_banner.visible = false
	GameState.emit_signal("toast", "引导完成。胜负在出航前——去编队看预测仪表盘。")
	tutorial_completed.emit()
	# 软提示运营桩
	if App.flag("ops", true):
		OpsDirector.nudge_soft_features()

func _ensure_banner() -> void:
	if _banner != null and is_instance_valid(_banner):
		return
	_banner = CanvasLayer.new()
	_banner.layer = 30
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = "VoyageCopperPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = 64
	panel.offset_bottom = 200
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.name = "VBox"
	margin.add_child(v)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 20)
	v.add_child(title)
	var body := RichTextLabel.new()
	body.name = "Body"
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(0, 48)
	v.add_child(body)
	var prog := Label.new()
	prog.name = "Prog"
	prog.add_theme_font_size_override("font_size", 12)
	prog.modulate = Color(0.7, 0.8, 0.9)
	v.add_child(prog)
	var btn := Button.new()
	btn.text = "知道了"
	btn.pressed.connect(func():
		if str(current_step().get("id", "")) == "wake":
			GameState.tutorial_flags["wake_seen"] = true
			_idx = 1
			GameState.save_game()
		_banner.visible = false
	)
	v.add_child(btn)
	_banner.add_child(panel)
	get_tree().root.add_child(_banner)
