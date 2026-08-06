extends Control
## 主界面：海图 + HUD + 侧栏。手感：拖拽平移、出航弧线、岛脉冲、资源滚动、过日反馈。

const BattleFacadeScript = preload("res://systems/battle/BattleFacade.gd")
const PoiServiceScript = preload("res://systems/economy/PoiService.gd")
const StaminaCostsScript = preload("res://systems/economy/StaminaCosts.gd")
const MapGraphScript = preload("res://systems/map/MapGraph.gd")

@onready var sea_bg: ColorRect = $SeaBg
@onready var map_root: Node2D = $MapViewport/SubViewport/MapRoot
@onready var cam: Camera2D = $MapViewport/SubViewport/MapRoot/Camera2D
@onready var flash: ColorRect = $Flash
@onready var toast_box: VBoxContainer = $HUD/ToastBox
@onready var lbl_day: Label = $HUD/StatusStrip/Row/DayLabel
@onready var lbl_sta: Label = $HUD/StatusStrip/Row/StaBox/StaLabel
@onready var sta_bar: ProgressBar = $HUD/StatusStrip/Row/StaBox/StaBar
@onready var lbl_res: Label = $HUD/StatusStrip/Row/ResLabel
@onready var lbl_pos: Label = $HUD/StatusStrip/Row/PosLabel
@onready var lbl_war: Label = $HUD/StatusStrip/Row/WarChip
@onready var btn_day: Button = $HUD/StatusStrip/Row/BtnDay
@onready var btn_more: MenuButton = $HUD/StatusStrip/Row/BtnMore
@onready var side: PanelContainer = $HUD/SidePanel
@onready var side_title: Label = $HUD/SidePanel/Margin/VBox/Title
@onready var side_hint: Label = $HUD/SidePanel/Margin/VBox/StatusHint
@onready var side_body: RichTextLabel = $HUD/SidePanel/Margin/VBox/Body
@onready var btn_insight: Button = $HUD/SidePanel/Margin/VBox/BtnInsight
@onready var btn_sail: Button = $HUD/SidePanel/Margin/VBox/BtnSail
@onready var btn_poi: Button = $HUD/SidePanel/Margin/VBox/BtnPOI
@onready var btn_battle: Button = $HUD/SidePanel/Margin/VBox/BtnBattle
@onready var btn_fleet: Button = $HUD/BottomDock/DockRow/BtnFleet
@onready var btn_codex: Button = $HUD/BottomDock/DockRow/BtnCodex
@onready var btn_gacha: Button = $HUD/BottomDock/DockRow/BtnGacha
@onready var btn_systems: Button = $HUD/BottomDock/DockRow/BtnSystems
@onready var btn_palette: Button = $HUD/BottomDock/DockRow/BtnPalette
@onready var busy_banner: Label = $HUD/BusyBanner
@onready var side_vbox: VBoxContainer = $HUD/SidePanel/Margin/VBox

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
var _side_concept: TextureRect
var _side_sys_row: HBoxContainer
var _side_sys_icons: Dictionary = {}
var _insight_open := false

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
	btn_codex.pressed.connect(_open_codex)
	btn_gacha.pressed.connect(_open_gacha)
	btn_systems.pressed.connect(_open_systems)
	btn_palette.pressed.connect(_open_palette)
	btn_insight.pressed.connect(_toggle_insight)
	btn_codex.visible = App.flag("codex", true)
	btn_gacha.visible = App.flag("gacha", true)
	btn_day.pressed.connect(func(): GameState.advance_day(1))
	_setup_more_menu()
	_apply_sea_art()
	_style_side_panel()
	_build_map()
	_selected = GameState.current_island
	_focus_island(_selected, false)
	_refresh_hud()
	_update_side()
	Bgm.play_map()
	if not GameState.tutorial_flags.get("boot_tip", false):
		GameState.tutorial_flags["boot_tip"] = true
		_show_toast("右键拖图 · 滚轮缩放 · 空格过一天 · K 指令")

func _apply_sea_art() -> void:
	var sea := "frozen"
	if GameData.islands.has(GameState.current_island):
		sea = str(GameData.islands[GameState.current_island].get("sea", "frozen"))
	var tex: Texture2D = null
	match sea:
		"abyss":
			tex = AssetDB.env("env_abyss_chart_base")
		"blaze":
			tex = AssetDB.env("env_blaze_chart_base")
			if tex == null:
				tex = AssetDB.env("env_hanhai_chart_base")
		"tradewind":
			tex = AssetDB.env("env_tradewind_chart_base")
		_:
			tex = AssetDB.env("env_map_frozen_sea")
	if tex == null:
		tex = AssetDB.env("env_map_frozen_sea")
	if tex == null:
		return
	var old := get_node_or_null("SeaArt")
	if old:
		old.queue_free()
	var tr := TextureRect.new()
	tr.name = "SeaArt"
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = tex
	tr.modulate = Color(1, 1, 1, 0.85)
	sea_bg.add_sibling(tr)
	move_child(tr, sea_bg.get_index() + 1)
	sea_bg.color = Color(0.04, 0.07, 0.12, 0.35)

func _style_side_panel() -> void:
	side.theme_type_variation = "VoyageCopperPanel"
	_side_concept = TextureRect.new()
	_side_concept.name = "ConceptArt"
	_side_concept.custom_minimum_size = Vector2(0, 200)
	_side_concept.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_side_concept.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_side_concept.modulate = Color(1, 1, 1, 0.98)
	_side_concept.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_show_concept_lightbox()
	)
	side_vbox.add_child(_side_concept)
	side_vbox.move_child(_side_concept, 1)
	_side_sys_row = HBoxContainer.new()
	_side_sys_row.name = "SysRow"
	_side_sys_row.add_theme_constant_override("separation", 6)
	_side_sys_row.alignment = BoxContainer.ALIGNMENT_CENTER
	side_vbox.add_child(_side_sys_row)
	side_vbox.move_child(_side_sys_row, 2)
	for sys in ["flame", "ironwall", "wind", "tide"]:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(28, 28)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = AssetDB.sys_icon(sys)
		tr.modulate = Color(1, 1, 1, 0.35)
		tr.tooltip_text = str(GameData.SYS_NAME.get(sys, sys))
		_side_sys_row.add_child(tr)
		_side_sys_icons[sys] = tr
	btn_sail.text = "出航（%d 体力）" % StaminaCostsScript.sail()
	btn_poi.text = "探索 POI（%d 体力）" % StaminaCostsScript.poi()
	var btn_harbor := Button.new()
	btn_harbor.name = "BtnHarbor"
	btn_harbor.custom_minimum_size = Vector2(0, 36)
	btn_harbor.text = "港主简报"
	btn_harbor.pressed.connect(_open_harbor_brief)
	side_vbox.add_child(btn_harbor)
	side_vbox.move_child(btn_harbor, btn_sail.get_index())

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

func _setup_more_menu() -> void:
	var popup := btn_more.get_popup()
	popup.clear()
	if App.flag("ops", true):
		popup.add_item("运营日历", 0)
	popup.add_item("跳过 30 日", 1)
	popup.add_item("新开局", 2)
	popup.id_pressed.connect(func(id: int):
		match id:
			0:
				OpsDirector.open_panel()
			1:
				_on_skip30()
			2:
				_on_reset()
	)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_palette"):
		_open_palette()
		get_viewport().set_input_as_handled()
		return
	if _busy:
		return
	if event.is_action_pressed("advance_day"):
		GameState.advance_day(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_fleet"):
		_open_fleet()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_codex"):
		_open_codex()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_gacha"):
		_open_gacha()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_systems"):
		_open_systems()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_ops"):
		if App.flag("ops", true):
			OpsDirector.open_panel()
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
	var ship_tex := AssetDB.ship(GameState.ship_id)
	if ship_tex:
		var spr := Sprite2D.new()
		spr.texture = ship_tex
		spr.scale = Vector2(0.12, 0.12)
		spr.centered = true
		_ship.add_child(spr)
	else:
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
	var marker := AssetDB.island_icon(id)
	if marker == null:
		marker = AssetDB.island_marker()
	if marker:
		var spr := Sprite2D.new()
		spr.texture = marker
		spr.scale = Vector2(0.22, 0.22)
		spr.position = Vector2(0, -58)
		spr.z_index = 1
		n.add_child(spr)
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
	var is_current := id == GameState.current_island
	var sb := VoyageTheme.island_style(str(isl.get("tier", "light")), owned, revealed, is_current)
	if not revealed:
		btn.text = "？？？"
	else:
		btn.text = str(isl.get("name", id))
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
			var key: String = (str(a_id) + ">" + str(b_id)) if str(a_id) < str(b_id) else (str(b_id) + ">" + str(a_id))
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
	if id == "FR_12" and not bool(GameState.tutorial_flags.get("nar_boss_herald", false)):
		NarrativeDirector.play_chapter("boss_herald")
	if _busy:
		return
	Sfx.play_select()
	_selected = id
	GameState.reveal_island(id)
	EventBus.island_selected.emit(id)
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
	lbl_day.text = "第 %d 日 · %s" % [GameState.day, SeasonDirector.season_label()]
	var sta_max := int(GameData.constants.get("STAMINA_MAX", 120))
	lbl_sta.text = "体力 %d/%d" % [GameState.stamina, sta_max]
	sta_bar.max_value = sta_max
	sta_bar.value = GameState.stamina
	var fill_c := VoyageTheme.WIND
	if GameState.stamina <= sta_max * 0.2:
		fill_c = VoyageTheme.DANGER
	elif GameState.stamina <= sta_max * 0.45:
		fill_c = VoyageTheme.WARN
	sta_bar.add_theme_stylebox_override("fill", VoyageTheme.bar_fill(fill_c))
	lbl_res.text = "战略 %d" % GameState.strategic
	var cur = GameData.islands.get(GameState.current_island, {})
	lbl_pos.text = "当前位置 · %s" % cur.get("name", GameState.current_island)
	_refresh_war_chip()
	busy_banner.visible = _busy
	if _busy:
		busy_banner.text = "航行中…" if btn_sail.disabled else "处理中…"
	_refresh_map_styles()
	_update_side()
	if _ship and _island_nodes.has(GameState.current_island) and not _busy:
		_ship.position = _island_nodes[GameState.current_island].position + Vector2(0, 42)

func _refresh_war_chip() -> void:
	var al: Dictionary = GameState.alliance
	if str(al.get("id", "")) == "":
		lbl_war.visible = false
		return
	lbl_war.visible = true
	var us := int(al.get("war_score", 0))
	var them := int(al.get("rival_score", 0))
	var lead := us - them
	var lead_col := VoyageTheme.SUCCESS if lead >= 0 else VoyageTheme.DANGER
	lbl_war.add_theme_color_override("font_color", lead_col)
	lbl_war.text = "联航 %d : %d" % [us, them]

func _toggle_insight() -> void:
	_insight_open = not _insight_open
	_update_side()

func _update_side() -> void:
	if _selected == "" or not GameData.islands.has(_selected):
		return
	var isl: Dictionary = GameData.islands[_selected]
	var owned := GameState.owned_islands.has(_selected)
	var revealed := GameState.revealed.has(_selected)
	side_title.text = isl.get("name", _selected) if revealed else "未知海域"
	if _side_concept:
		var concept := AssetDB.island_concept(_selected) if revealed else null
		if concept == null and revealed:
			concept = AssetDB.island_icon(_selected)
		_side_concept.texture = concept
		_side_concept.visible = concept != null
		_side_concept.modulate = Color(1, 1, 1, 1.0 if revealed else 0.35)
	_highlight_side_systems(revealed)
	# 一句话状态（Certain）
	if not revealed:
		side_hint.text = "迷雾未散 · 靠近或选中可揭示"
		side_hint.add_theme_color_override("font_color", VoyageTheme.MUTED)
	elif owned:
		side_hint.text = "已占领 · 日产累计 %d" % int(GameState.island_yield_bank.get(_selected, 0))
		side_hint.add_theme_color_override("font_color", VoyageTheme.SUCCESS)
	elif int(isl.get("guard_hp", 0)) <= 0:
		side_hint.text = "无守卫 · 可宣示主权"
		side_hint.add_theme_color_override("font_color", VoyageTheme.SUCCESS)
	elif _selected == GameState.current_island:
		side_hint.text = "护岛者 HP %s · 可挑战" % str(isl.get("guard_hp", 0))
		side_hint.add_theme_color_override("font_color", VoyageTheme.WARN)
		if not _busy:
			Bgm.play_map_tense()
	else:
		side_hint.text = "相邻可达 · 先出航再行动"
		side_hint.add_theme_color_override("font_color", VoyageTheme.INFO)
	var lines: PackedStringArray = []
	if revealed:
		var neighbors: Array = GameData.adjacency.get(_selected, [])
		var nn: PackedStringArray = []
		for n in neighbors:
			nn.append(VoyageTheme.island_label(str(n)))
		lines.append("相邻：%s" % (", ".join(nn) if not nn.is_empty() else "—"))
		var pois: Array = isl.get("poi", [])
		if not pois.is_empty():
			lines.append("POI：%s" % ", ".join(pois))
		if _insight_open:
			lines.append("")
			lines.append(VoyageTheme.bb(VoyageTheme.MUTED, "海域气质 · 冻洋偏铁壁"))
			lines.append("环境：铁壁 %s / 烈焰 %s" % [
				VoyageTheme.bb(VoyageTheme.IRON, "×1.15"),
				VoyageTheme.bb(VoyageTheme.FLAME, "×0.95"),
			])
			lines.append("形状码 ▲烈焰 ▣铁壁 ◆疾风 ●潮汐")
			lines.append(VoyageTheme.bb(VoyageTheme.MUTED, "编号 %s · %s" % [_selected, isl.get("tier", "?")]))
	else:
		lines.append("迷雾未散。")
	side_body.text = "\n".join(lines)
	btn_insight.text = "情报 ▴" if _insight_open else "情报 ▾"
	btn_sail.text = "出航（%d 体力）" % StaminaCostsScript.sail()
	btn_poi.text = "探索 POI（%d 体力）" % StaminaCostsScript.poi()
	var can_sail := GameState.can_sail_to(_selected) or _selected == GameState.current_island
	if has_node("HUD/SidePanel/Margin/VBox/BtnHarbor"):
		var bh: Button = $HUD/SidePanel/Margin/VBox/BtnHarbor
		bh.disabled = _busy or _selected != GameState.current_island
		bh.tooltip_text = "" if not bh.disabled else "需在当前停靠港听取简报"
	btn_sail.disabled = (not can_sail and _selected != GameState.current_island) or _busy
	if not GameState.can_sail_to(_selected) and _selected != GameState.current_island:
		btn_sail.tooltip_text = "只能驶向相邻岛屿"
	elif _selected == GameState.current_island:
		btn_sail.tooltip_text = "已在此岛"
	else:
		btn_sail.tooltip_text = ""
	btn_poi.disabled = _selected != GameState.current_island or _busy
	btn_poi.tooltip_text = "" if not btn_poi.disabled else "需先航行到该岛"
	btn_battle.disabled = _selected != GameState.current_island or owned or int(isl.get("guard_hp", 0)) <= 0 or _busy
	if _selected == GameState.current_island and not owned and int(isl.get("guard_hp", 0)) <= 0:
		btn_battle.disabled = _busy
		btn_battle.text = "宣示主权"
		btn_battle.tooltip_text = ""
	else:
		btn_battle.text = "挑战护岛者（%d 体力）" % StaminaCostsScript.raid()
		if btn_battle.disabled and not owned:
			btn_battle.tooltip_text = "需先航行到该岛" if _selected != GameState.current_island else ""
		else:
			btn_battle.tooltip_text = ""

func _highlight_side_systems(revealed: bool) -> void:
	if _side_sys_row == null:
		return
	# 冻洋偏置：铁壁亮、烈焰略暗
	for sys in _side_sys_icons.keys():
		var tr: TextureRect = _side_sys_icons[sys]
		if not revealed:
			tr.modulate = Color(1, 1, 1, 0.2)
			continue
		match sys:
			"ironwall":
				tr.modulate = Color(1, 1, 1, 1.0)
			"flame":
				tr.modulate = Color(1, 1, 1, 0.45)
			_:
				tr.modulate = Color(1, 1, 1, 0.7)

func _on_sail() -> void:
	if _busy:
		return
	if _selected == GameState.current_island:
		_show_toast("已在此岛")
		return
	if not MapGraphScript.can_sail(GameState.current_island, _selected):
		GameState.emit_signal("toast", "只能驶向相邻岛屿")
		Juice.deny_pulse()
		return
	if not GameState.spend_stamina(StaminaCostsScript.sail()):
		return
	_busy = true
	busy_banner.visible = true
	busy_banner.text = "出航中…"
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
	for n in MapGraphScript.neighbors(to_id):
		GameState.reveal_island(n)
	GameState.save_game()
	GameState.emit_signal("state_changed")
	EventBus.sailed.emit(from_id, to_id)
	_apply_sea_art()
	Bgm.play_map()
	Juice.shake(2.5, 0.12)
	_show_toast("顺流抵达「%s」" % GameData.islands[to_id]["name"])
	_busy = false
	busy_banner.visible = false
	NarrativeDirector.try_chapter("first_sail")
	var sea := str(GameData.islands.get(to_id, {}).get("sea", ""))
	if sea == "abyss":
		NarrativeDirector.try_chapter("abyss_enter")
	_update_side()

func _on_poi() -> void:
	if _busy:
		return
	if _selected != GameState.current_island:
		GameState.emit_signal("toast", "先航行到该岛")
		return
	if not GameState.spend_stamina(StaminaCostsScript.poi()):
		return
	Sfx.play_ok()
	var result: Dictionary = PoiServiceScript.resolve(_selected)
	# Demo 软化：首次 POI 提高可见掉落；strict_poi 时关闭（对齐 [B4]）
	if App.flag("demo_soft_poi", true) and not App.flag("strict_poi", false):
		if not GameState.tutorial_flags.get("first_poi", false) and str(result.get("crew_id", "")) == "":
			var soft_roll := randf()
			if soft_roll < 0.08:
				var pool: Array = []
				for c in GameData.card_list:
					if not GameState.owned_cards.has(c["id"]):
						pool.append(c["id"])
				if pool.is_empty():
					pool = GameData.cards.keys()
				if not pool.is_empty():
					result.crew_id = pool[randi() % pool.size()]
	var gained_res := int(result.get("strategic", 0))
	GameState.add_strategic(gained_res, "POI")
	Juice.float_label(self, "+%d 战略" % gained_res, get_local_mouse_position(), Color(0.7, 0.9, 1.0))
	Juice.punch(btn_poi, 1.06, 0.1)
	if str(result.get("crew_id", "")) != "":
		GameState.gain_card(str(result.crew_id))
	if bool(result.get("ship_scrap", false)):
		_show_toast("发现船图纸残页（折算战略资源）")
	GameState.tutorial_flags["first_poi"] = true
	GameState.save_game()
	EventBus.poi_resolved.emit(_selected, result)
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
	if not GameState.spend_stamina(StaminaCostsScript.raid()):
		return
	if _selected == "FR_12" and not bool(GameState.tutorial_flags.get("nar_boss_clash", false)):
		await NarrativeDirector.play_chapter("boss_clash")
	var seed := GameState.battle_seed + GameState.day * 17 + _selected.hash()
	var result: Dictionary = BattleFacadeScript.fight_guard(
		GameState.fleet, _selected, GameState.ship_id, seed
	)
	if bool(result.get("empty_guard", false)):
		GameState.capture_island(_selected)
		return
	ChainGateway.commit_battle(result, {"island_id": _selected})
	EventBus.battle_resolved.emit(_selected, result)
	_play_battle(result, isl)

func _play_battle(result: Dictionary, isl: Dictionary) -> void:
	_busy = true
	busy_banner.visible = true
	busy_banner.text = "交战中…"
	set_meta("last_battle_result", result)
	var overlay := preload("res://ui/BattleOverlay.tscn").instantiate()
	add_child(overlay)
	overlay.play(result, isl)
	overlay.finished.connect(_on_battle_finished)

func _on_battle_finished(won: bool) -> void:
	var gvg := false
	# 最近一场若是 GVG，不占岛（战利品已在 RaidService 结算）
	if typeof(ChainGateway.last_receipt) == TYPE_DICTIONARY:
		pass
	var last_battle: Dictionary = {}
	if has_meta("last_battle_result"):
		last_battle = get_meta("last_battle_result")
	gvg = bool(last_battle.get("gvg", false))
	if won:
		Bgm.play_victory_once()
		if not gvg:
			var was_new := not GameState.owned_islands.has(_selected)
			GameState.capture_island(_selected)
			if was_new and not bool(GameState.tutorial_flags.get("nar_harbor", false)):
				NarrativeDirector.play_chapter("harbor")
		if not GameState.tutorial_flags.get("restraint_tip", false):
			GameState.tutorial_flags["restraint_tip"] = true
			_show_toast("提示：烈焰克铁壁 ×1.3 — 冻洋也怕火。")
		await get_tree().create_timer(1.2).timeout
		Bgm.play_map()
	else:
		Bgm.play_defeat_once()
		GameState.emit_signal("toast", "败退。调整编队再试。")
		Juice.deny_pulse()
		await get_tree().create_timer(1.0).timeout
		Bgm.play_map()
	GameState.save_game()
	GameState.emit_signal("state_changed")
	_busy = false
	busy_banner.visible = false

func _open_fleet() -> void:
	if _busy:
		return
	var panel := preload("res://ui/FleetPanel.tscn").instantiate()
	add_child(panel)

func _open_codex() -> void:
	if _busy:
		return
	if not App.flag("codex", true):
		return
	add_child(preload("res://ui/CodexPanel.tscn").instantiate())

func _open_gacha() -> void:
	if _busy:
		return
	if not App.flag("gacha", true):
		return
	add_child(preload("res://ui/GachaScreen.tscn").instantiate())

func _open_systems() -> void:
	if _busy:
		return
	add_child(load("res://ui/systems/SystemsMenu.gd").new())

func _open_harbor_brief() -> void:
	if _busy:
		return
	if get_tree().get_nodes_in_group("harbor_brief").size() > 0:
		return
	var brief = load("res://ui/HarborBrief.gd").new()
	brief.add_to_group("harbor_brief")
	add_child(brief)

func _open_palette() -> void:
	if get_tree().get_nodes_in_group("command_palette").size() > 0:
		return
	var pal = load("res://ui/CommandPalette.gd").new()
	pal.add_to_group("command_palette")
	add_child(pal)

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

func _show_concept_lightbox() -> void:
	if _side_concept == null or _side_concept.texture == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 30
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.88)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			layer.queue_free()
	)
	layer.add_child(dim)
	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 80
	tr.offset_right = -80
	tr.offset_top = 60
	tr.offset_bottom = -60
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = _side_concept.texture
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tr)
	var tip := Label.new()
	tip.text = "点击任意处关闭 · 岛立绘"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	tip.offset_top = -48
	layer.add_child(tip)
	add_child(layer)

func _show_toast(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", VoyageTheme.PARCHMENT)
	toast_box.add_child(lbl)
	Juice.punch(lbl, 1.04, 0.1)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.35)
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
