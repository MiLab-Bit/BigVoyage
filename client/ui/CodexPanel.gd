extends CanvasLayer
## 图鉴壳：20 卡真名 / 机制名 / 立绘 / 体系筛选

const DisplayNamesScript := preload("res://core/DisplayNames.gd")

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Center/Panel
@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var tabs: HBoxContainer = $Center/Panel/Margin/VBox/Tabs
@onready var grid: GridContainer = $Center/Panel/Margin/VBox/Scroll/Grid
@onready var detail: RichTextLabel = $Center/Panel/Margin/VBox/Detail
@onready var btn_close: Button = $Center/Panel/Margin/VBox/Close

var _filter_sys := ""

func _ready() -> void:
	title.text = "船员图鉴 · 真名与形状"
	panel.theme_type_variation = "VoyageCopperPanel"
	btn_close.pressed.connect(queue_free)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			queue_free()
	)
	_build_tabs()
	_rebuild()
	dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)

func _build_tabs() -> void:
	for c in tabs.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	var defs := [
		{"id": "", "label": "全部"},
		{"id": "flame", "label": "▲烈焰"},
		{"id": "ironwall", "label": "▣铁壁"},
		{"id": "wind", "label": "◆疾风"},
		{"id": "tide", "label": "●潮汐"},
	]
	for d in defs:
		var b := Button.new()
		b.text = d["label"]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = (d["id"] == _filter_sys)
		var sid: String = d["id"]
		b.pressed.connect(func():
			_filter_sys = sid
			_rebuild()
		)
		tabs.add_child(b)

func _rebuild() -> void:
	for c in grid.get_children():
		c.queue_free()
	for card in GameData.card_list:
		var id := str(card.get("id", ""))
		var sys := str(card.get("system", ""))
		if _filter_sys != "" and sys != _filter_sys:
			continue
		grid.add_child(_make_cell(id, card))

func _make_cell(id: String, card: Dictionary) -> Control:
	var info: Dictionary = DisplayNamesScript.for_card(id)
	var owned := GameState.owned_cards.has(id)
	var box := Button.new()
	box.custom_minimum_size = Vector2(150, 200)
	box.clip_contents = true
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(140, 140)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = AssetDB.card_illu(id)
	if tr.texture == null:
		tr.texture = AssetDB.card_bust(id)
	tr.modulate = Color(1, 1, 1, 1.0 if owned else 0.35)
	v.add_child(tr)
	var nm := Label.new()
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text = "%s %s" % [info.get("shape", "•"), info.get("display", id)]
	nm.add_theme_color_override("font_color", GameData.system_color(sys_of(card)))
	nm.add_theme_font_size_override("font_size", 14)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var sub := Label.new()
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rar := str(card.get("rarity", "?"))
	sub.text = "%s%s · %s" % [rar, "★独占" if rar == "UR" else "", "已拥有" if owned else "未获得"]
	sub.add_theme_font_size_override("font_size", 11)
	sub.modulate = Color(1.0, 0.86, 0.45) if rar == "UR" else Color(0.75, 0.8, 0.85)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sub)
	if rar == "UR":
		var badge := Label.new()
		badge.text = "UR"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(badge)
	box.pressed.connect(func(): _show_detail(id, info, card, owned))
	return box

func sys_of(card: Dictionary) -> String:
	return str(card.get("system", ""))

func _show_detail(id: String, info: Dictionary, card: Dictionary, owned: bool) -> void:
	Sfx.play_select()
	var blurb := str(card.get("identity", card.get("desc", "洋流记得他们的名字。")))
	var UrExclusiveScript := preload("res://systems/gacha/UrExclusive.gd")
	var ex := UrExclusiveScript.blurb(id)
	detail.text = "[b]%s[/b] %s\n机制名：%s · %s / %s\n%s\n%s\n技能：%s\n%s" % [
		info.get("display", id),
		info.get("shape", ""),
		info.get("mechanism", ""),
		GameData.SYS_NAME.get(info.get("system", ""), "?"),
		card.get("rarity", "?"),
		"已编入船籍" if owned else "图鉴锁定（POI/抽卡可见）",
		blurb,
		str(card.get("skill", {}).get("name", "—")),
		ex,
	]
