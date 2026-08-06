extends CanvasLayer
## 经营入口：贸易 / 科技 / 联航 各成一屏（钱包次级）

func _ready() -> void:
	layer = 21
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = VoyageTheme.OVERLAY_DIM
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			queue_free()
	)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "VoyageCopperPanel"
	panel.custom_minimum_size = Vector2(520, 420)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -210
	panel.offset_bottom = 210
	add_child(panel)
	Juice.present_overlay(dim, panel)
	Sfx.play_event("sfx_ui_ok")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "海域经营"
	title.add_theme_font_size_override("font_size", 24)
	v.add_child(title)
	var tip := Label.new()
	tip.text = "一屏一事 · 选模块进入"
	tip.add_theme_color_override("font_color", VoyageTheme.MUTED)
	v.add_child(tip)
	for item in [
		["贸易港务", "跑商与三角航线", "trade"],
		["科技树", "战略投入与海域意志", "tech"],
		["赛季联航", "对阵、战报与突袭", "alliance"],
		["钱包（可选）", "Aleo 开发者验证", "wallet"],
	]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 52)
		b.text = "%s  —  %s" % [item[0], item[1]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id: String = item[2]
		b.pressed.connect(func():
			Sfx.play_select()
			_open(id)
		)
		v.add_child(b)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(queue_free)
	v.add_child(close)

func _open(id: String) -> void:
	var parent := get_parent()
	queue_free()
	match id:
		"trade":
			parent.add_child(load("res://ui/systems/TradeScreen.gd").new())
		"tech":
			parent.add_child(load("res://ui/systems/TechScreen.gd").new())
		"alliance":
			parent.add_child(load("res://ui/systems/AllianceScreen.gd").new())
		"wallet":
			parent.add_child(load("res://ui/systems/WalletSheet.gd").new())
