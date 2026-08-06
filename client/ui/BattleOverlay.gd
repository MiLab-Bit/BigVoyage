extends CanvasLayer
signal finished(won: bool)

const SfxRouterScript := preload("res://presentation/audio/SfxRouter.gd")
const DisplayNamesScript := preload("res://core/DisplayNames.gd")
const BattleLogPresenterScript := preload("res://presentation/battle/BattleLogPresenter.gd")
const BattlePresenterScript := preload("res://presentation/battle/BattlePresenter.gd")
const FrameAnimatorScript := preload("res://presentation/battle/FrameAnimator.gd")

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Center/Panel
@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var log_box: RichTextLabel = $Center/Panel/Margin/VBox/Log
@onready var bar_a: ProgressBar = $Center/Panel/Margin/VBox/Bars/BarA
@onready var bar_b: ProgressBar = $Center/Panel/Margin/VBox/Bars/BarB
@onready var lbl_a: Label = $Center/Panel/Margin/VBox/Bars/LblA
@onready var lbl_b: Label = $Center/Panel/Margin/VBox/Bars/LblB
@onready var skip_btn: Button = $Center/Panel/Margin/VBox/Skip
@onready var vbox: VBoxContainer = $Center/Panel/Margin/VBox

var _result: Dictionary
var _playing := false
var _skip := false
var _hp_a := 0.0
var _hp_b := 0.0
var _max_a := 1.0
var _max_b := 1.0
var _row_a: HBoxContainer
var _row_b: HBoxContainer
var _phase_lbl: Label
var _result_banner: PanelContainer
var _result_lbl: Label
var _vfx_flash: TextureRect
var _portraits_a: Dictionary = {}
var _portraits_b: Dictionary = {}
var _restraint_hits := 0
var _total_hits := 0
var _hit_index := 0
var _phase := 0

func _ready() -> void:
	skip_btn.pressed.connect(func(): _skip = true)
	panel.theme_type_variation = "VoyageCopperPanel"
	panel.custom_minimum_size = Vector2(880, 660)
	dim.color = VoyageTheme.OVERLAY_DIM
	title.add_theme_color_override("font_color", VoyageTheme.PARCHMENT.lightened(0.06))
	lbl_a.add_theme_color_override("font_color", VoyageTheme.SUCCESS.lightened(0.1))
	lbl_b.add_theme_color_override("font_color", VoyageTheme.DANGER.lightened(0.15))
	_ensure_unit_rows()
	Juice.present_overlay(dim, panel, 0.18)

func _ensure_unit_rows() -> void:
	_phase_lbl = Label.new()
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_lbl.add_theme_font_size_override("font_size", 14)
	_phase_lbl.add_theme_color_override("font_color", VoyageTheme.COPPER.lightened(0.2))
	vbox.add_child(_phase_lbl)
	vbox.move_child(_phase_lbl, 1)
	_row_a = HBoxContainer.new()
	_row_a.add_theme_constant_override("separation", 8)
	_row_a.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_row_a)
	vbox.move_child(_row_a, 2)
	_row_b = HBoxContainer.new()
	_row_b.add_theme_constant_override("separation", 8)
	_row_b.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_row_b)
	vbox.move_child(_row_b, 3)
	_vfx_flash = TextureRect.new()
	_vfx_flash.custom_minimum_size = Vector2(64, 64)
	_vfx_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vfx_flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vfx_flash.modulate.a = 0.0
	_vfx_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_vfx_flash)
	vbox.move_child(_vfx_flash, 4)
	_result_banner = PanelContainer.new()
	_result_banner.visible = false
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.06, 0.1, 0.14, 0.96)
	rsb.set_border_width_all(2)
	rsb.border_color = VoyageTheme.COPPER
	rsb.set_corner_radius_all(10)
	rsb.content_margin_left = 16
	rsb.content_margin_right = 16
	rsb.content_margin_top = 10
	rsb.content_margin_bottom = 10
	_result_banner.add_theme_stylebox_override("panel", rsb)
	_result_lbl = Label.new()
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.add_theme_font_size_override("font_size", 28)
	_result_banner.add_child(_result_lbl)
	vbox.add_child(_result_banner)
	# 放在 Skip 之前（末尾前一位）
	vbox.move_child(_result_banner, vbox.get_child_count() - 2)

func play(result: Dictionary, isl: Dictionary) -> void:
	_result = result
	var iid := str(isl.get("id", ""))
	var sea := str(isl.get("sea", result.get("sea", Bgm.current_sea())))
	var is_boss := bool(result.get("boss", false)) or iid in ["FR_12", "AB_09", "BL_09", "TW_09"] \
		or str(isl.get("tier", "")) == "boss"
	if is_boss:
		Bgm.play_boss(sea)
	else:
		Bgm.play_battle()
	title.text = ("终核海战 · %s" if is_boss else "海战 · %s") % isl.get("name", "")
	var battle_bg := AssetDB.env("env_battle_deck")
	if iid == "FR_12":
		var boss_bg := AssetDB.env("boss/env_boss_FR_12_bg")
		if boss_bg:
			battle_bg = boss_bg
	if battle_bg and dim:
		var tr := TextureRect.new()
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = battle_bg
		tr.modulate = Color(1, 1, 1, 0.38)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.add_sibling(tr)
		move_child(tr, dim.get_index())
	_build_portraits(result.get("units_a", []), _row_a, _portraits_a)
	_build_portraits(result.get("units_b", []), _row_b, _portraits_b)
	if iid == "FR_12":
		_attach_boss_creature(_row_b)
	_max_a = max(1.0, _sum_field(result.get("units_a", []), "max_hp"))
	_max_b = max(1.0, _sum_field(result.get("units_b", []), "max_hp"))
	_hp_a = _max_a
	_hp_b = _max_b
	bar_a.max_value = _max_a
	bar_b.max_value = _max_b
	bar_a.value = _max_a
	bar_b.value = _max_b
	lbl_a.text = "我方舰队"
	lbl_b.text = "终核卫队" if is_boss else "护岛者"
	_style_bars()
	log_box.clear()
	await get_tree().process_frame
	_set_phase(BattlePresenterScript.Phase.OPENING)
	_row_a.modulate.a = 0.0
	_row_b.modulate.a = 0.0
	var otw := create_tween()
	otw.set_parallel(true)
	otw.tween_property(_row_a, "modulate:a", 1.0, BattlePresenterScript.OPENING_SEC)
	otw.tween_property(_row_b, "modulate:a", 1.0, BattlePresenterScript.OPENING_SEC)
	log_box.append_text("%s 舰队破雾入场\n" % VoyageTheme.bb(VoyageTheme.WARN, "开场"))
	if not _skip:
		await otw.finished
	_playing = true
	await _run_log()
	_playing = false
	_set_phase(BattlePresenterScript.Phase.FINALE)
	var won := str(result.get("winner", "")) == "A"
	_hp_a = _sum_field(result.get("units_a", []), "hp")
	_hp_b = _sum_field(result.get("units_b", []), "hp")
	bar_a.value = _hp_a
	bar_b.value = _hp_b
	_refresh_bar_urgency()
	Juice.shake(8 if won else 4, 0.2)
	Sfx.play_event("sfx_btl_finisher")
	var summary := BattleLogPresenterScript.summarize(result)
	var end := "胜利" if won else "败北"
	var hash_s := str(result.get("hash", ""))
	if hash_s.length() > 16:
		hash_s = hash_s.substr(0, 16) + "…"
	var ratio := 0.0
	if _total_hits > 0:
		ratio = float(_restraint_hits) / float(_total_hits)
	_show_result_banner(won, end)
	log_box.append_text("\n\n[b]%s[/b] · %s\n克制贡献 %s · hash %s\n" % [
		VoyageTheme.bb(VoyageTheme.SUCCESS if won else VoyageTheme.DANGER, end),
		summary,
		VoyageTheme.bb(VoyageTheme.WARN, "%d/%d（%.0f%%）" % [_restraint_hits, _total_hits, ratio * 100.0]),
		VoyageTheme.bb(VoyageTheme.MUTED, hash_s),
	])
	if won:
		Juice.celebrate()
	else:
		Juice.deny_pulse()
	if not _skip:
		await get_tree().create_timer(BattlePresenterScript.FINALE_SEC).timeout
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(panel, "modulate:a", 0.0, 0.2)
	await tw.finished
	emit_signal("finished", won)
	queue_free()

func _show_result_banner(won: bool, end: String) -> void:
	_result_banner.visible = true
	_result_lbl.text = end
	_result_lbl.add_theme_color_override("font_color", VoyageTheme.SUCCESS if won else VoyageTheme.DANGER)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.06, 0.1, 0.14, 0.96)
	rsb.set_border_width_all(2)
	rsb.border_color = VoyageTheme.SUCCESS if won else VoyageTheme.DANGER
	rsb.set_corner_radius_all(10)
	rsb.content_margin_left = 16
	rsb.content_margin_right = 16
	rsb.content_margin_top = 10
	rsb.content_margin_bottom = 10
	_result_banner.add_theme_stylebox_override("panel", rsb)
	_result_banner.modulate.a = 0.0
	_result_banner.scale = Vector2(0.92, 0.92)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_result_banner, "modulate:a", 1.0, 0.18)
	tw.tween_property(_result_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _attach_boss_creature(row: HBoxContainer) -> void:
	var tex := AssetDB.creature("creature_starleviathan_illu")
	if tex == null:
		tex = AssetDB.creature("creature_lostguard_awake_illu")
	if tex == null:
		return
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(96, 110)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(92, 80)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture = tex
	var border := PanelContainer.new()
	border.add_theme_stylebox_override("panel", VoyageTheme.portrait_frame("tide", VoyageTheme.TIDE))
	border.add_child(tr)
	wrap.add_child(border)
	var nm := Label.new()
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 11)
	nm.text = "★星渊巨兽"
	nm.add_theme_color_override("font_color", VoyageTheme.TIDE.lightened(0.25))
	wrap.add_child(nm)
	row.add_child(wrap)
	row.move_child(wrap, 0)

func _set_phase(p: int) -> void:
	_phase = p
	if _phase_lbl:
		_phase_lbl.text = "· %s ·" % BattlePresenterScript.phase_label(p)

func _build_portraits(units: Array, row: HBoxContainer, store: Dictionary) -> void:
	for c in row.get_children():
		c.queue_free()
	store.clear()
	for u in units:
		var id := str(u.get("id", ""))
		var uid := str(u.get("uid", id))
		var wrap := VBoxContainer.new()
		wrap.custom_minimum_size = Vector2(76, 100)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(70, 70)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var tex := AssetDB.card_head(id)
		if tex == null:
			tex = AssetDB.card_bust(id)
		tr.texture = tex
		FrameAnimatorScript.attach(self, tr, id)
		var sys := str(u.get("sys", ""))
		var border := PanelContainer.new()
		border.add_theme_stylebox_override("panel", VoyageTheme.portrait_frame(sys))
		border.add_child(tr)
		wrap.add_child(border)
		var nm := Label.new()
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.add_theme_font_size_override("font_size", 11)
		var info: Dictionary = DisplayNamesScript.for_card(id)
		nm.text = "%s%s" % [info.get("shape", ""), info.get("display", id)]
		nm.add_theme_color_override("font_color", VoyageTheme.system_color(sys).lightened(0.25))
		wrap.add_child(nm)
		row.add_child(wrap)
		store[uid] = border

func _style_bars() -> void:
	bar_a.add_theme_stylebox_override("fill", VoyageTheme.bar_fill(VoyageTheme.SUCCESS))
	bar_b.add_theme_stylebox_override("fill", VoyageTheme.bar_fill(VoyageTheme.DANGER))
	bar_a.add_theme_stylebox_override("background", VoyageTheme.bar_bg())
	bar_b.add_theme_stylebox_override("background", VoyageTheme.bar_bg())

func _refresh_bar_urgency() -> void:
	if _max_a > 0.0 and _hp_a / _max_a <= 0.25:
		bar_a.add_theme_stylebox_override("fill", VoyageTheme.bar_fill(VoyageTheme.WARN))
	if _max_b > 0.0 and _hp_b / _max_b <= 0.25:
		bar_b.add_theme_stylebox_override("fill", VoyageTheme.bar_fill(VoyageTheme.WARN.darkened(0.1)))

func _sum_field(units: Array, key: String) -> float:
	var s := 0.0
	for u in units:
		s += float(u.get(key, 0))
	return s

func _display_from_uid(uid: String, fallback: String) -> String:
	var idx := uid.find("_")
	if idx < 0:
		return fallback
	var cid := uid.substr(idx + 1)
	var info: Dictionary = DisplayNamesScript.for_card(cid)
	var d := str(info.get("display", ""))
	return d if d != "" else fallback

func _pulse_portrait(uid: String, strong: bool) -> void:
	var node: Control = _portraits_a.get(uid)
	if node == null:
		node = _portraits_b.get(uid)
	if node == null:
		return
	Juice.punch(node, 1.12 if strong else 1.06, 0.1)

func _flash_restraint(sys: String) -> void:
	var tex := AssetDB.vfx("vfx_restraint_%s" % sys)
	if tex == null:
		tex = AssetDB.vfx("vfx_dot_burn") if sys == "flame" else null
	if tex == null:
		return
	_vfx_flash.texture = tex
	_vfx_flash.modulate.a = 0.9
	var tw := create_tween()
	tw.tween_property(_vfx_flash, "modulate:a", 0.0, 0.45)

func _float_dmg(dmg: int, is_restraint: bool) -> void:
	var col := VoyageTheme.WARN if is_restraint else VoyageTheme.DANGER.lightened(0.15)
	Juice.float_label(panel, "-%d" % dmg, Vector2(panel.size.x * 0.5, 120), col)

func _run_log() -> void:
	var log: Array = _result.get("log", [])
	var hits_total := BattlePresenterScript.count_hits(log)
	_hit_index = 0
	for entry in log:
		if _skip:
			break
		SfxRouterScript.play_from_battle_event(entry)
		var t: String = str(entry.get("t", ""))
		if t == "hit":
			_hit_index += 1
			_total_hits += 1
			var p := BattlePresenterScript.classify_phase(entry, _hit_index, hits_total)
			if p != _phase and p != BattlePresenterScript.Phase.OPENING:
				_set_phase(p)
			var dmg := int(entry.get("dmg", 0))
			var coef := float(entry.get("restraint", 1.0))
			var is_r := coef > 1.05
			var sys_a := str(entry.get("sys_a", ""))
			var name_a := _display_from_uid(str(entry.get("attacker", "")), str(entry.get("name_a", "?")))
			var name_t := _display_from_uid(str(entry.get("target", "")), str(entry.get("name_t", "?")))
			var line := "%s → %s  %s" % [name_a, name_t, VoyageTheme.bb(VoyageTheme.WARN, "-%d" % dmg)]
			if is_r:
				_restraint_hits += 1
				line += "  %s" % VoyageTheme.bb(VoyageTheme.COPPER.lightened(0.2), "克制×%.2f %s" % [coef, DisplayNamesScript.shape(sys_a)])
				_flash_restraint(sys_a)
				Sfx.play_restraint()
			elif coef < 0.95:
				line += "  %s" % VoyageTheme.bb(VoyageTheme.DANGER, "被克×%.2f" % coef)
			log_box.append_text(line + "\n")
			_float_dmg(dmg, is_r)
			_pulse_portrait(str(entry.get("attacker", "")), is_r)
			_pulse_portrait(str(entry.get("target", "")), false)
			if str(entry.get("attacker", "")).begins_with("A"):
				_hp_b = max(0.0, _hp_b - float(dmg))
				bar_b.value = _hp_b
				Juice.hit_impact(is_r)
			else:
				_hp_a = max(0.0, _hp_a - float(dmg))
				bar_a.value = _hp_a
				Juice.hit_impact(false)
			_refresh_bar_urgency()
			Juice.punch(panel, 1.012, 0.07)
		elif t == "dot":
			var dmg2 := int(entry.get("dmg", 0))
			log_box.append_text("%s −%d（层 %s）\n" % [
				VoyageTheme.bb(VoyageTheme.FLAME, "燃烧 DoT"), dmg2, str(entry.get("stacks", 1))
			])
			_float_dmg(dmg2, false)
			var burn := AssetDB.vfx("vfx_dot_burn")
			if burn:
				_vfx_flash.texture = burn
				_vfx_flash.modulate.a = 0.7
				var tw := create_tween()
				tw.tween_property(_vfx_flash, "modulate:a", 0.0, 0.35)
			var tgt := str(entry.get("target", ""))
			if tgt.begins_with("B"):
				_hp_b = max(0.0, _hp_b - float(dmg2))
				bar_b.value = _hp_b
			else:
				_hp_a = max(0.0, _hp_a - float(dmg2))
				bar_a.value = _hp_a
			_refresh_bar_urgency()
		elif t == "control":
			_set_phase(BattlePresenterScript.Phase.GRIND)
			log_box.append_text("%s\n" % VoyageTheme.bb(VoyageTheme.TIDE.lightened(0.2), "控制 · %s" % str(entry.get("kind", "stun"))))
		elif t == "kill":
			_set_phase(BattlePresenterScript.Phase.FINALE)
			log_box.append_text("%s\n" % VoyageTheme.bb(VoyageTheme.DANGER, "击破！"))
			Juice.shake(7, 0.15)
		elif t == "start":
			log_box.append_text("%s\n" % VoyageTheme.bb(VoyageTheme.MUTED, "交战开始 · seed %s · 定点结算" % str(entry.get("seed", 0))))
		if not _skip:
			await get_tree().create_timer(BattlePresenterScript.delay_for(entry)).timeout
	if _skip:
		_hp_a = _sum_field(_result.get("units_a", []), "hp")
		_hp_b = _sum_field(_result.get("units_b", []), "hp")
		bar_a.value = _hp_a
		bar_b.value = _hp_b
		_refresh_bar_urgency()
