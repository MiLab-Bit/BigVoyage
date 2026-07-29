extends Control
## 主界面：海图 + HUD + 侧栏。手感：拖拽平移、出航弧线、岛脉冲、资源滚动、过日反馈。

const _RB = preload("res://systems/ResolveBattle.gd")

@onready var map_root: Node2D = $MapViewport/SubViewport/MapRoot
@onready var cam: Camera2D = $MapViewport/SubViewport/MapRoot/Camera2D
@onready var flash: ColorRect = $Flash
@onready var toast_box: VBoxContainer = $HUD/ToastBox
@onready var lbl_day: Label = $HUD/TopBar/DayLabel
@onready var lbl_sta: Label = $HUD/TopBar/StaLabel
@onready var lbl_res: Label = $HUD/TopBar/ResLabel
@onready var lbl_pos: Label = $HUD/TopBar/PosLabel
@onready var side: PanelContainer = $HUD/SidePanel
@onready var side_title: Label = $HUD/SidePanel/Margin/VBox/Title
@onready var side_body: RichTextLabel = $HUD/SidePanel/Margin/VBox/Body
@onready var btn_sail: Button = $HUD/SidePanel/Margin/VBox/BtnSail
@onready var btn_poi: Button = $HUD/SidePanel/Margin/VBox/BtnPOI
@onready var btn_battle: Button = $HUD/SidePanel/Margin/VBox/BtnBattle
@onready var btn_fleet: Button = $HUD/TopBar/BtnFleet
@onready var btn_day: Button = $HUD/TopBar/BtnDay
@onready var btn_skip30: Button = $HUD/TopBar/BtnSkip30
@onready var btn_reset: Button = $HUD/TopBar/BtnReset

var _island_nodes: Dictionary = {}
var _selected: String = ""
var _panning := false
var _pan_last := Vector2.ZERO
var _shake_time := 0.0
var _shake_amt := 0.0
var _edges: Node2D
var _ship: Node2D
var _busy := false
var _wave_t := 0.0

func _ready() -> void:
	flash.modulate.a = 0.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Juice.shake_requested.connect(_on_shake)
	Juice.flash_requested.connect(_on_flash)
	GameState.state_changed.connect(_refresh_hud)
	GameState.toast.connect(_show_toast)
	GameState.day_advanced.connect(func(_d): Sfx.play_day())
	GameState.resources_gained.connect(_on_res_gain)
	btn_sail.pressed.connect(_on_sail)
	btn_poi.pressed.connect(_on_poi)
	btn_battle.pressed.connect(_on_battle)
	btn_fleet.pressed.connect(_open_fleet)
	btn_day.pressed.connect(func(): GameState.advance_day(1))
	btn_skip30.pressed.connect(_on_skip30)
	btn_reset.pressed.connect(_on_reset)
	_style_side_panel()
	_build_map()
	_selected = GameState.current_island
	_focus_island(_selected, false)
	_refresh_hud()
	_update_side()
	if not GameState.tutorial_flags.get("boot_tip", false):
		GameState.tutorial_flags["boot_tip"] = true
		_show_toast("右键拖拽平移 · 滚轮缩放 · 空格过一天 · 点岛出航")

func _style_side_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.1, 0.16, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.35, 0.55, 0.75, 0.55)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	side.add_theme_stylebox_override("panel", sb)

func _process(delta: float) -> void:
	_wave_t += delta
	if _shake_time > 0.0:
		_shake_time -= delta
		var s := _shake_amt * (_shake_time)
		cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
		if _shake_time <= 0.0:
			cam.offset = Vector2.ZERO
	if _island_nodes.has(_selected):
		var n: Node2D = _island_nodes[_selected]
		n.scale = Vector2.ONE * (1.0 + 0.05 * sin(_wave_t * 4.0))
	if _ship:
		_ship.rotation = sin(_wave_t * 2.2) * 0.08

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("advance_day"):
		GameState.advance_day(1)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
			_pan_last = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom = (cam.zoom * 1.08).clamp(Vector2(0.55, 0.55), Vector2(1.8, 1.8))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom = (cam.zoom / 1.08).clamp(Vector2(0.55, 0.55), Vector2(1.8, 1.8))
	if event is InputEventMouseMotion and _panning:
		var delta_p: Vector2 = event.position - _pan_last
		_pan_last = event.position
		cam.position -= delta_p / cam.zoom

func _build_map() -> void:
	_edges = Node2D.new()
	_edges.name = "Edges"
	_edges.z_index = -1
	map_root.add_child(_edges)

	var mist := CPUParticles2D.new()
	mist.amount = 48
	mist.lifetime = 6.0
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(900, 600)
	mist.direction = Vector2(1, 0.2)
	mist.spread = 22
	mist.gravity = Vector2.ZERO
	mist.initial_velocity_min = 8
	mist.initial_velocity_max = 24
	mist.scale_amount_min = 1.5
	mist.scale_amount_max = 3.5
	mist.color = Color(0.55, 0.7, 0.9, 0.22)
	mist.position = Vector2(500, 400)
	map_root.add_child(mist)

	for isl in GameData.island_list:
		var id: String = isl["id"]
		var node := _make_island_node(isl)
		map_root.add_child(node)
		_island_nodes[id] = node
	_redraw_edges()

	_ship = Node2D.new()
	_ship.name = "Ship"
	_ship.z_index = 5
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(-12, -9), Vector2(-6, 0), Vector2(-12, 9)
	])
	poly.color = Color(1.0, 0.86, 0.42, 0.95)
	_ship.add_child(poly)
	var wake := CPUParticles2D.new()
	wake.amount = 18
	wake.lifetime = 0.7
	wake.emitting = false
	wake.direction = Vector2(-1, 0)
	wake.spread = 25
	wake.initial_velocity_min = 20
	wake.initial_velocity_max = 40
	wake.scale_amount_min = 1.5
	wake.scale_amount_max = 3.0
	wake.color = Color(0.7, 0.85, 1.0, 0.55)
	wake.z_index = -1
	_ship.add_child(wake)
	_ship.set_meta("wake", wake)
	map_root.add_child(_ship)
	if _island_nodes.has(GameState.current_island):
		_ship.position = _island_nodes[GameState.current_island].position + Vector2(0, 42)

func _make_island_node(isl: Dictionary) -> Node2D:
	var id: String = isl["id"]
	var n := Node2D.new()
	n.name = id
	n.position = Vector2(float(isl["x"]) * 220.0 + 160.0, float(isl["y"]) * 180.0 + 140.0)
	var ring := Polygon2D.new()
	ring.color = Color(0.25, 0.45, 0.65, 0.25)
	var pts: PackedVector2Array = []
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(Vector2(cos(a), sin(a)) * 48.0)
	ring.polygon = pts
	ring.z_index = -1
	n.add_child(ring)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(118, 72)
	btn.position = Vector2(-59, -36)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(func(): _select_island(id))
	n.add_child(btn)
	n.set_meta("btn", btn)
	n.set_meta("data", isl)
	n.set_meta("ring", ring)
	_style_island_btn(btn, isl)
	return n

func _style_island_btn(btn: Button, isl: Dictionary) -> void:
	var id: String = isl["id"]
	var owned := GameState.owned_islands.has(id)
	var revealed := GameState.revealed.has(id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.18, 0.92)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	if not revealed:
		sb.bg_color = Color(0.05, 0.06, 0.09, 0.85)
		sb.border_color = Color(0.25, 0.3, 0.4)
		btn.text = "？？？"
	else:
		match str(isl.get("tier", "light")):
			"start":
				sb.border_color = Color(0.45, 0.85, 0.7)
			"heavy":
				sb.border_color = Color(0.95, 0.55, 0.25)
			"boss":
				sb.border_color = Color(0.95, 0.3, 0.35)
			_:
				sb.border_color = Color(0.4, 0.65, 0.9)
		if owned:
			sb.bg_color = Color(0.12, 0.22, 0.2, 0.95)
		btn.text = "%s\n%s" % [isl.get("name", id), id]
	if id == GameState.current_island:
		sb.border_color = Color(1.0, 0.86, 0.4)
		sb.set_border_width_all(3)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := sb.duplicate()
	sb_h.bg_color = sb.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)

func _redraw_edges() -> void:
	for c in _edges.get_children():
		c.queue_free()
	var drawn := {}
	for a_id in GameData.adjacency.keys():
		if not _island_nodes.has(a_id):
			continue
		for b_id in GameData.adjacency[a_id]:
			var key := a_id + ">" + b_id if a_id < b_id else b_id + ">" + a_id
			if drawn.has(key):
				continue
			drawn[key] = true
			var line := Line2D.new()
			line.width = 2.2
			line.default_color = Color(0.35, 0.55, 0.75, 0.38)
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.points = PackedVector2Array([
				_island_nodes[a_id].position,
				_island_nodes[b_id].position
			])
			_edges.add_child(line)

func _select_island(id: String) -> void:
	if _busy:
		return
	Sfx.play_select()
	_selected = id
	GameState.reveal_island(id)
	_focus_island(id, true)
	_refresh_map_styles()
	_update_side()
	Juice.punch(_island_nodes[id])

func _focus_island(id: String, animate: bool) -> void:
	if not _island_nodes.has(id):
		return
	var target: Vector2 = _island_nodes[id].position
	if animate:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(cam, "position", target, 0.38)
	else:
		cam.position = target

func _refresh_map_styles() -> void:
	for id in _island_nodes.keys():
		var n: Node2D = _island_nodes[id]
		var btn: Button = n.get_meta("btn")
		_style_island_btn(btn, n.get_meta("data"))
		var ring: Polygon2D = n.get_meta("ring")
		if GameState.owned_islands.has(id):
			ring.color = Color(0.35, 0.75, 0.55, 0.28)
		elif id == GameState.current_island:
			ring.color = Color(1.0, 0.85, 0.35, 0.3)
		else:
			ring.color = Color(0.25, 0.45, 0.65, 0.22)

func _refresh_hud() -> void:
	lbl_day.text = "第 %d 日" % GameState.day
	lbl_sta.text = "体力 %d/%d" % [GameState.stamina, int(GameData.constants.get("STAMINA_MAX", 120))]
	lbl_res.text = "战略 %d" % GameState.strategic
	var cur = GameData.islands.get(GameState.current_island, {})
	lbl_pos.text = "当前位置 · %s" % cur.get("name", GameState.current_island)
	_refresh_map_styles()
	_update_side()
	if _ship and _island_nodes.has(GameState.current_island) and not _busy:
		_ship.position = _island_nodes[GameState.current_island].position + Vector2(0, 42)

func _update_side() -> void:
	if _selected == "" or not GameData.islands.has(_selected):
		return
	var isl: Dictionary = GameData.islands[_selected]
	var owned := GameState.owned_islands.has(_selected)
	var revealed := GameState.revealed.has(_selected)
	side_title.text = isl.get("name", _selected) if revealed else "未知海域"
	var lines: PackedStringArray = []
	lines.append("[color=#9fc0e8]%s[/color] · tier=%s" % [_selected, isl.get("tier", "?")])
	if revealed:
		lines.append("守卫 HP：%s" % str(isl.get("guard_hp", 0)))
		lines.append("POI：%s" % ", ".join(isl.get("poi", [])))
		var neighbors: Array = GameData.adjacency.get(_selected, [])
		var nn: PackedStringArray = []
		for n in neighbors:
			nn.append(GameData.islands.get(n, {}).get("name", n))
		lines.append("相邻：%s" % ", ".join(nn))
		if owned:
			lines.append("[color=#7ddea5]已占领 · 日产累计 %d[/color]" % int(GameState.island_yield_bank.get(_selected, 0)))
		elif int(isl.get("guard_hp", 0)) <= 0:
			lines.append("[color=#7ddea5]无守卫，可直接宣示主权[/color]")
		else:
			lines.append("[color=#ffb703]需击败护岛者方可占领[/color]")
		lines.append("\n冻洋环境：铁壁 [color=#adb5bd]×1.15[/color] / 烈焰 [color=#e85d04]×0.95[/color]")
	else:
		lines.append("迷雾未散。靠近或选中可揭示。")
	side_body.text = "\n".join(lines)
	btn_sail.disabled = (not GameState.can_sail_to(_selected) and _selected != GameState.current_island) or _busy
	btn_poi.disabled = _selected != GameState.current_island or _busy
	btn_battle.disabled = _selected != GameState.current_island or owned or int(isl.get("guard_hp", 0)) <= 0 or _busy
	if _selected == GameState.current_island and not owned and int(isl.get("guard_hp", 0)) <= 0:
		btn_battle.disabled = _busy
		btn_battle.text = "宣示主权"
	else:
		btn_battle.text = "挑战护岛者"

func _on_sail() -> void:
	if _busy:
		return
	if _selected == GameState.current_island:
		_show_toast("已在此岛")
		return
	if not GameState.can_sail_to(_selected):
		GameState.emit_signal("toast", "只能驶向相邻岛屿")
		Juice.deny_pulse()
		return
	if not GameState.spend_stamina(1):
		return
	_busy = true
	Sfx.play_sail()
	var from_id := GameState.current_island
	var to_id := _selected
	var from_pos: Vector2 = _island_nodes[from_id].position + Vector2(0, 42)
	var to_pos: Vector2 = _island_nodes[to_id].position + Vector2(0, 42)
	_ship.position = from_pos
	var wake: CPUParticles2D = _ship.get_meta("wake")
	wake.emitting = true
	var mid := (from_pos + to_pos) * 0.5 + Vector2(0, -36)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float):
		# quadratic bezier
		var p := (1.0 - t) * (1.0 - t) * from_pos + 2.0 * (1.0 - t) * t * mid + t * t * to_pos
		_ship.position = p
		var dir := to_pos - from_pos
		_ship.rotation = dir.angle() + sin(t * PI) * 0.15
	, 0.0, 1.0, 0.55)
	tw.parallel().tween_property(cam, "position", _island_nodes[to_id].position, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	wake.emitting = false
	GameState.current_island = to_id
	GameState.reveal_island(to_id)
	for n in GameData.adjacency.get(to_id, []):
		GameState.reveal_island(n)
	GameState.save_game()
	GameState.emit_signal("state_changed")
	Juice.shake(2.5, 0.12)
	_show_toast("顺流抵达「%s」" % GameData.islands[to_id]["name"])
	_busy = false
	_update_side()

func _on_poi() -> void:
	if _busy:
		return
	if _selected != GameState.current_island:
		GameState.emit_signal("toast", "先航行到该岛")
		return
	if not GameState.spend_stamina(1):
		return
	Sfx.play_ok()
	var isl: Dictionary = GameData.islands[_selected]
	var poi: Array = isl.get("poi", ["resource"])
	var roll := randf()
	var gained_res := int(GameData.constants.get("POI_RESOURCE_BASE", 500))
	GameState.add_strategic(gained_res, "POI")
	Juice.float_label(self, "+%d 战略" % gained_res, get_local_mouse_position(), Color(0.7, 0.9, 1.0))
	Juice.punch(btn_poi, 1.06, 0.1)
	var crew_rate := float(GameData.constants.get("POI_DROP_CREW_RATE", 1.0 / 480.0))
	var soft := 0.08 if not GameState.tutorial_flags.get("first_poi", false) else crew_rate * 12.0
	if poi.has("crew") or poi.has("crew_ur"):
		if roll < max(soft, crew_rate) or (poi.has("crew_ur") and roll < 0.2):
			var pool: Array = []
			for c in GameData.card_list:
				if not GameState.owned_cards.has(c["id"]):
					pool.append(c["id"])
			if pool.is_empty():
				pool = GameData.cards.keys()
			var pick: String = pool[randi() % pool.size()]
			GameState.gain_card(pick)
	if poi.has("ship") and randf() < float(GameData.constants.get("POI_DROP_SHIP_RATE", 1.0 / 960.0)) * 20.0:
		GameState.add_strategic(300, "船图折算")
		_show_toast("发现船图纸残页（Demo：折算战略资源）")
	GameState.tutorial_flags["first_poi"] = true
	GameState.save_game()
	Juice.punch(side)

func _on_battle() -> void:
	if _busy:
		return
	var isl: Dictionary = GameData.islands.get(_selected, {})
	if _selected != GameState.current_island:
		GameState.emit_signal("toast", "先航行到该岛")
		return
	if GameState.owned_islands.has(_selected):
		_show_toast("已占领")
		return
	if int(isl.get("guard_hp", 0)) <= 0:
		GameState.capture_island(_selected)
		return
	if GameState.fleet.is_empty():
		GameState.emit_signal("toast", "请先编队")
		_open_fleet()
		return
	if not GameState.spend_stamina(1):
		return
	var guard: Dictionary = GameData.guards.get(_selected, {})
	var enemy_fleet: Array = guard.get("crew_ids", [])
	if enemy_fleet.is_empty():
		GameState.capture_island(_selected)
		return
	var env := {
		"ship_a": GameState.ship_id,
		"ship_b": guard.get("ship_id", "SHIP_IRON"),
		"hp_mult_b": float(guard.get("hp_mult", 1.0)),
	}
	var seed := GameState.battle_seed + GameState.day * 17 + _selected.hash()
	var result: Dictionary = _RB.resolve(GameState.fleet, enemy_fleet, env, seed)
	_play_battle(result, isl)

func _play_battle(result: Dictionary, isl: Dictionary) -> void:
	_busy = true
	var overlay := preload("res://ui/BattleOverlay.tscn").instantiate()
	add_child(overlay)
	overlay.play(result, isl)
	overlay.finished.connect(func(won: bool):
		if won:
			GameState.capture_island(_selected)
			if not GameState.tutorial_flags.get("restraint_tip", false):
				GameState.tutorial_flags["restraint_tip"] = true
				_show_toast("提示：烈焰克铁壁 ×1.3 — 冻洋也怕火。")
		else:
			GameState.emit_signal("toast", "败退。调整编队再试。")
			Juice.deny_pulse()
		GameState.save_game()
		GameState.emit_signal("state_changed")
		_busy = false
	)

func _open_fleet() -> void:
	if _busy:
		return
	var panel := preload("res://ui/FleetPanel.tscn").instantiate()
	add_child(panel)

func _on_skip30() -> void:
	if _busy:
		return
	GameState.advance_day(30)
	Juice.celebrate()
	Juice.float_label(self, "30 日结算", Vector2(size.x * 0.5, 120), Color(1.0, 0.86, 0.45))

func _on_reset() -> void:
	if _busy:
		return
	GameState.new_game()
	_selected = "FR_01"
	_focus_island(_selected, true)
	if _ship and _island_nodes.has("FR_01"):
		_ship.position = _island_nodes["FR_01"].position + Vector2(0, 42)
	_show_toast("新的航线开始了")

func _show_toast(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.modulate = Color(1, 0.93, 0.75)
	toast_box.add_child(lbl)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(lbl.queue_free)

func _on_res_gain(amount: int, _reason: String) -> void:
	Juice.float_label(self, "+%d" % amount, Vector2(size.x * 0.5, 80), Color(0.65, 0.9, 1.0))

func _on_shake(amount: float, time: float) -> void:
	_shake_amt = amount
	_shake_time = time

func _on_flash(color: Color, time: float) -> void:
	flash.color = color
	flash.modulate.a = color.a
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, time)
