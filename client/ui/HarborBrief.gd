extends CanvasLayer
## 港主简报：LLM 原型（失败自动降级本地台词）

var _body: RichTextLabel
var _status: Label
var _island_id: String = ""

func _ready() -> void:
	layer = 23
	_island_id = GameState.current_island
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
	panel.custom_minimum_size = Vector2(560, 360)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -180
	panel.offset_bottom = 180
	add_child(panel)
	Juice.present_overlay(dim, panel)
	Sfx.play_event("sfx_ui_ok")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Label.new()
	title.text = "港主简报 · %s" % VoyageTheme.island_label(_island_id)
	title.add_theme_font_size_override("font_size", 22)
	v.add_child(title)
	_status = Label.new()
	_status.text = "港主正在整理潮讯…"
	_status.add_theme_color_override("font_color", VoyageTheme.MUTED)
	v.add_child(_status)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(0, 180)
	v.add_child(_body)
	var row := HBoxContainer.new()
	v.add_child(row)
	var refresh := Button.new()
	refresh.text = "再听一遍"
	refresh.pressed.connect(func():
		# 清当日缓存需走网关内部；简单起见直接再请求（缓存命中则秒回）
		_status.text = "港主清了清嗓子…"
		Sfx.play_select()
		LlmGateway.harbor_brief_async(_island_id)
	)
	row.add_child(refresh)
	var close := Button.new()
	close.text = "告辞"
	close.pressed.connect(queue_free)
	row.add_child(close)
	if not LlmGateway.brief_ready.is_connected(_on_brief):
		LlmGateway.brief_ready.connect(_on_brief)
	LlmGateway.harbor_brief_async(_island_id)

func _exit_tree() -> void:
	if LlmGateway.brief_ready.is_connected(_on_brief):
		LlmGateway.brief_ready.disconnect(_on_brief)

func _on_brief(text: String, meta: Dictionary) -> void:
	_body.text = text
	var src := str(meta.get("source", "?"))
	match src:
		"llm":
			_status.text = "来自港主口述（实时）"
			Sfx.play_event("sfx_nar_chapter_title")
		"cache":
			_status.text = "今日已听过 · 复述存档"
			Sfx.play_select()
		"fallback":
			_status.text = "潮讯不稳 · 港主改用口谕底稿"
			Sfx.play_event("sfx_ui_click")
		_:
			_status.text = "潮讯受阻 · 已用本地口谕（%s）" % src
			Sfx.play_deny()
