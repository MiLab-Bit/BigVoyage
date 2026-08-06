extends PanelContainer
class_name PredictDashboard
## 编队预测仪表盘：克制可读 + 可胜/险胜/不利（对齐 VoyageTheme）

signal verdict_changed(verdict: String)

const RING := {"flame": "ironwall", "ironwall": "wind", "wind": "tide", "tide": "flame"}

var _label: RichTextLabel
var _slots: HBoxContainer
var _verdict_lbl: Label
var _enemy_island: String = "FR_02"
var _title: Label

func _ready() -> void:
	custom_minimum_size = Vector2(0, 118)
	theme_type_variation = "VoyageCopperPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(VoyageTheme.PANEL_BG.r, VoyageTheme.PANEL_BG.g, VoyageTheme.PANEL_BG.b, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(VoyageTheme.COPPER.r, VoyageTheme.COPPER.g, VoyageTheme.COPPER.b, 0.75)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_title = Label.new()
	_title.text = "预测 · 胜负在出航前"
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", VoyageTheme.COPPER.lightened(0.15))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_verdict_lbl = Label.new()
	_verdict_lbl.text = "—"
	_verdict_lbl.add_theme_font_size_override("font_size", 18)
	_verdict_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_verdict_lbl)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 6)
	v.add_child(_slots)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(0, 36)
	v.add_child(_label)

func set_enemy_island(island_id: String) -> void:
	_enemy_island = island_id

func refresh(fleet: Array) -> void:
	for c in _slots.get_children():
		c.queue_free()
	var adv := 0
	var disadv := 0
	var enemy: Array = GameData.guards.get(_enemy_island, {}).get("crew_ids", [])
	if enemy.is_empty():
		enemy = ["IRON_R_01", "IRON_R_02", "IRON_SR_01"]
	var enemy_sys: Array = []
	for eid in enemy:
		if GameData.cards.has(eid):
			enemy_sys.append(str(GameData.cards[eid]["system"]))

	for id in fleet:
		var info: Dictionary = DisplayNames.for_card(str(id))
		var sys := str(info.get("system", ""))
		var chip := _make_chip(str(id), info)
		_slots.add_child(chip)
		for es in enemy_sys:
			if RING.get(sys, "") == es:
				adv += 1
			elif RING.get(es, "") == sys:
				disadv += 1

	var verdict := "均势"
	if adv > disadv + 1:
		verdict = "可胜"
		Sfx.play_event("sfx_ui_predict_ok")
	elif adv > disadv:
		verdict = "险胜"
		Sfx.play_event("sfx_ui_predict_ok")
	elif disadv > adv:
		verdict = "不利"
		Sfx.play_event("sfx_ui_predict_warn")

	var vc := VoyageTheme.verdict_color(verdict)
	_verdict_lbl.text = verdict
	_verdict_lbl.add_theme_color_override("font_color", vc)
	var island_name := VoyageTheme.island_label(_enemy_island)
	_label.text = "对「%s」守卫 · 克制 %s / 被克 %s\n%s · 形状码 ▲烈焰 ▣铁壁 ◆疾风 ●潮汐" % [
		island_name,
		VoyageTheme.bb(VoyageTheme.WARN, "+%d" % adv),
		VoyageTheme.bb(VoyageTheme.DANGER, "−%d" % disadv),
		VoyageTheme.bb(VoyageTheme.MUTED, "冻洋 铁壁×1.15 / 烈焰×0.95"),
	]
	verdict_changed.emit(verdict)

func _make_chip(card_id: String, info: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", VoyageTheme.chip_frame(str(info.get("system", ""))))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	box.add_child(h)
	var tex := AssetDB.card_head(card_id)
	if tex:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture = tex
		h.add_child(tr)
	var lbl := Label.new()
	lbl.text = "%s %s" % [info.get("shape", "•"), info.get("display", card_id)]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", VoyageTheme.PARCHMENT)
	h.add_child(lbl)
	return box
