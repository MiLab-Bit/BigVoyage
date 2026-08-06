extends RefCounted
class_name WarLogView
## 把「D84 · 正文」战报渲染成可读条目

static func fill(host: VBoxContainer, log: Array) -> void:
	if log.is_empty():
		var empty := Label.new()
		empty.text = "尚无战报 · 加入联航并推进日程后出现"
		empty.add_theme_color_override("font_color", VoyageTheme.MUTED)
		host.add_child(empty)
		return
	var n := 0
	for line in log:
		host.add_child(_row(str(line)))
		n += 1
		if n >= 8:
			break

static func _row(raw: String) -> Control:
	var day := ""
	var body := raw
	if raw.begins_with("D"):
		var parts := raw.split(" · ", false, 1)
		if parts.size() >= 1:
			day = parts[0]
		if parts.size() >= 2:
			body = parts[1]
	var tone := VoyageTheme.MUTED
	if body.contains("受挫") or body.contains("败"):
		tone = VoyageTheme.DANGER
	elif body.contains("出征") or body.contains("截获") or body.contains("我方 +"):
		tone = VoyageTheme.SUCCESS
	elif body.contains("赤潮") or body.contains("敌联") or body.contains("敌绩"):
		tone = VoyageTheme.WARN
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	sb.set_border_width_all(1)
	sb.border_color = Color(tone.r, tone.g, tone.b, 0.55)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	if day != "":
		var d := Label.new()
		d.text = day
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", VoyageTheme.INFO)
		d.custom_minimum_size = Vector2(48, 0)
		h.add_child(d)
	var lbl := Label.new()
	lbl.text = body
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", tone.lightened(0.15))
	h.add_child(lbl)
	return panel
