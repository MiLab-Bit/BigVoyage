extends CanvasLayer
## 指令面板（⌘K 风格）：过滤已有动作，键盘一等公民

var _filter: LineEdit
var _list: VBoxContainer
var _actions: Array = []
var _filtered: Array = []
var _selected := 0

func _ready() -> void:
	layer = 45
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
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "航海指令"
	title.add_theme_font_size_override("font_size", 18)
	v.add_child(title)
	_filter = LineEdit.new()
	_filter.placeholder_text = "搜索：编队、贸易、过一天…"
	_filter.grab_focus()
	_filter.text_changed.connect(func(_t): _apply_filter())
	v.add_child(_filter)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var tip := Label.new()
	tip.text = "↑↓ 选择 · Enter 执行 · Esc 关闭"
	tip.add_theme_color_override("font_color", VoyageTheme.MUTED)
	tip.add_theme_font_size_override("font_size", 13)
	v.add_child(tip)
	_build_actions()
	_apply_filter()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				_selected = maxi(0, _selected - 1)
				_render_list()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_selected = mini(maxi(_filtered.size() - 1, 0), _selected + 1)
				_render_list()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_run_selected()
				get_viewport().set_input_as_handled()

func _build_actions() -> void:
	var main = get_tree().current_scene
	_actions = [
		{"id": "day", "label": "过一天", "keys": "空格", "run": func(): GameState.advance_day(1)},
		{"id": "fleet", "label": "打开编队", "keys": "F", "run": func():
			if main and main.has_method("_open_fleet"):
				main._open_fleet()
		},
		{"id": "codex", "label": "打开图鉴", "keys": "C", "run": func():
			if main and main.has_method("_open_codex"):
				main._open_codex()
		},
		{"id": "gacha", "label": "打开祈愿", "keys": "G", "run": func():
			if main and main.has_method("_open_gacha"):
				main._open_gacha()
		},
		{"id": "systems", "label": "打开经营（贸易/科技/联航）", "keys": "E", "run": func():
			if main and main.has_method("_open_systems"):
				main._open_systems()
		},
		{"id": "harbor", "label": "港主简报", "keys": "", "run": func():
			if main and main.has_method("_open_harbor_brief"):
				main._open_harbor_brief()
		},
		{"id": "ops", "label": "运营日历", "keys": "O", "run": func(): OpsDirector.open_panel()},
		{"id": "sail", "label": "出航至选中岛", "keys": "", "run": func():
			if main and main.has_method("_on_sail"):
				main._on_sail()
		},
		{"id": "poi", "label": "探索当前岛 POI", "keys": "", "run": func():
			if main and main.has_method("_on_poi"):
				main._on_poi()
		},
		{"id": "battle", "label": "挑战护岛者 / 宣示主权", "keys": "", "run": func():
			if main and main.has_method("_on_battle"):
				main._on_battle()
		},
		{"id": "skip30", "label": "跳过 30 日", "keys": "", "run": func():
			if main and main.has_method("_on_skip30"):
				main._on_skip30()
		},
		{"id": "reset", "label": "新开局", "keys": "", "run": func():
			if main and main.has_method("_on_reset"):
				main._on_reset()
		},
	]

func _apply_filter() -> void:
	var q := _filter.text.strip_edges().to_lower()
	_filtered.clear()
	for a in _actions:
		if q == "" or str(a.label).to_lower().contains(q) or str(a.id).contains(q):
			_filtered.append(a)
	_selected = 0
	_render_list()

func _render_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _filtered.is_empty():
		var empty := Label.new()
		empty.text = "无匹配指令"
		empty.add_theme_color_override("font_color", VoyageTheme.MUTED)
		_list.add_child(empty)
		return
	for i in _filtered.size():
		var a: Dictionary = _filtered[i]
		var b := Button.new()
		var key_tag := (" · %s" % a.keys) if str(a.keys) != "" else ""
		b.text = "%s%s" % [a.label, key_tag]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == _selected:
			b.modulate = VoyageTheme.CURRENT
		var idx := i
		b.pressed.connect(func():
			_selected = idx
			_run_selected()
		)
		_list.add_child(b)

func _run_selected() -> void:
	if _selected < 0 or _selected >= _filtered.size():
		return
	var a: Dictionary = _filtered[_selected]
	var cb: Callable = a.run
	queue_free()
	cb.call()
