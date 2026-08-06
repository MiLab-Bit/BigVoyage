extends RefCounted
class_name SystemsOverlay
## 经营浮层共用壳：在已有 CanvasLayer 上挂 dim + 铜框

static func mount(layer: CanvasLayer, title_text: String, min_size: Vector2 = Vector2(760, 600)) -> Dictionary:
	layer.layer = 21
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = VoyageTheme.OVERLAY_DIM
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			Sfx.play_select()
			layer.queue_free()
	)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "VoyageCopperPanel"
	panel.custom_minimum_size = min_size
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -min_size.x * 0.5
	panel.offset_right = min_size.x * 0.5
	panel.offset_top = -min_size.y * 0.5
	panel.offset_bottom = min_size.y * 0.5
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(func():
		Sfx.play_select()
		layer.queue_free()
	)
	head.add_child(close)
	Juice.present_overlay(dim, panel)
	Sfx.play_event("sfx_ui_ok")
	return {"vbox": v, "title": title, "dim": dim, "panel": panel}
