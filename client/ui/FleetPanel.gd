extends CanvasLayer

const PredictDashboardScript := preload("res://ui/PredictDashboard.gd")
const DisplayNamesScript := preload("res://core/DisplayNames.gd")
const FleetRulesScript := preload("res://systems/fleet/FleetRules.gd")

@onready var dim: ColorRect = $Dim
@onready var list_owned: ItemList = $Center/Panel/Margin/VBoxRoot/HBox/Owned/List
@onready var list_fleet: ItemList = $Center/Panel/Margin/VBoxRoot/HBox/Fleet/List
@onready var lbl_cost: Label = $Center/Panel/Margin/VBoxRoot/HBox/Fleet/Cost
@onready var lbl_hint: RichTextLabel = $Center/Panel/Margin/VBoxRoot/Hint
@onready var btn_add: Button = $Center/Panel/Margin/VBoxRoot/HBox/Owned/BtnAdd
@onready var btn_remove: Button = $Center/Panel/Margin/VBoxRoot/HBox/Fleet/BtnRemove
@onready var btn_save: Button = $Center/Panel/Margin/VBoxRoot/Btns/Save
@onready var btn_close: Button = $Center/Panel/Margin/VBoxRoot/Btns/Close
@onready var panel: PanelContainer = $Center/Panel
@onready var vbox_root: VBoxContainer = $Center/Panel/Margin/VBoxRoot
@onready var title: Label = $Center/Panel/Margin/VBoxRoot/Title
@onready var lbl_owned: Label = $Center/Panel/Margin/VBoxRoot/HBox/Owned/Lbl

var _fleet: Array = []
var _predict: PredictDashboard
var _preview: TextureRect
var _preview_frame: PanelContainer
var _preview_lbl: RichTextLabel
var _subtitle: Label

func _ready() -> void:
	_fleet = GameState.fleet.duplicate()
	panel.theme_type_variation = "VoyageCopperPanel"
	panel.custom_minimum_size = Vector2(1080, 640)
	dim.color = VoyageTheme.OVERLAY_DIM
	_build_chrome()
	Juice.present_overlay(dim, panel, 0.16)
	btn_add.pressed.connect(_on_add)
	btn_remove.pressed.connect(_on_remove)
	btn_save.pressed.connect(_on_save)
	btn_close.pressed.connect(queue_free)
	list_owned.item_activated.connect(func(_i): _on_add())
	list_fleet.item_activated.connect(func(_i): _on_remove())
	list_owned.item_selected.connect(_on_owned_selected)
	list_fleet.item_selected.connect(_on_fleet_selected)
	_rebuild()
	_update_hint()

func _build_chrome() -> void:
	title.text = "舰队编成"
	title.add_theme_color_override("font_color", VoyageTheme.PARCHMENT.lightened(0.05))
	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.text = "先看预测，再落编 · 当前对照「%s」" % VoyageTheme.island_label(
		GameState.current_island if GameState.current_island != "FR_01" else "FR_02"
	)
	_subtitle.add_theme_font_size_override("font_size", 14)
	_subtitle.add_theme_color_override("font_color", VoyageTheme.MUTED)
	vbox_root.add_child(_subtitle)
	vbox_root.move_child(_subtitle, 1)

	_predict = PredictDashboardScript.new()
	_predict.set_enemy_island(GameState.current_island if GameState.current_island != "FR_01" else "FR_02")
	vbox_root.add_child(_predict)
	vbox_root.move_child(_predict, 2)

	var preview_row := HBoxContainer.new()
	preview_row.name = "PreviewRow"
	preview_row.add_theme_constant_override("separation", 14)
	preview_row.custom_minimum_size = Vector2(0, 128)
	vbox_root.add_child(preview_row)
	vbox_root.move_child(preview_row, 3)

	_preview_frame = PanelContainer.new()
	_preview_frame.add_theme_stylebox_override("panel", VoyageTheme.portrait_frame("wind"))
	preview_row.add_child(_preview_frame)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(96, 120)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_frame.add_child(_preview)

	_preview_lbl = RichTextLabel.new()
	_preview_lbl.bbcode_enabled = true
	_preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_lbl.fit_content = true
	preview_row.add_child(_preview_lbl)
	_preview_lbl.text = VoyageTheme.bb(VoyageTheme.MUTED, "点选船员查看立绘与真名")

	if lbl_owned:
		lbl_owned.add_theme_color_override("font_color", VoyageTheme.INFO)

func _rebuild() -> void:
	list_owned.clear()
	for id in GameState.owned_cards:
		var info: Dictionary = DisplayNamesScript.for_card(str(id))
		var col := VoyageTheme.system_color(str(info.get("system", "")))
		var text := "%s %s  [%s/%s] COST%d" % [
			info.get("shape", "•"),
			info.get("line", id),
			GameData.SYS_NAME.get(info.get("system", ""), "?"),
			GameData.cards.get(id, {}).get("rarity", "?"),
			GameData.rarity_cost(str(GameData.cards.get(id, {}).get("rarity", "R")))
		]
		var i := list_owned.add_item(text)
		list_owned.set_item_metadata(i, id)
		list_owned.set_item_custom_fg_color(i, col.lightened(0.12))
		var head := AssetDB.card_head(str(id))
		if head:
			list_owned.set_item_icon(i, head)
	list_fleet.clear()
	for id in _fleet:
		var info2: Dictionary = DisplayNamesScript.for_card(str(id))
		var col2 := VoyageTheme.system_color(str(info2.get("system", "")))
		var text2 := "%s %s" % [info2.get("shape", "•"), info2.get("display", id)]
		var i2 := list_fleet.add_item(text2)
		list_fleet.set_item_metadata(i2, id)
		list_fleet.set_item_custom_fg_color(i2, col2.lightened(0.12))
		var head2 := AssetDB.card_head(str(id))
		if head2:
			list_fleet.set_item_icon(i2, head2)
	var cost := 0
	for id in _fleet:
		cost += GameData.rarity_cost(str(GameData.cards.get(id, {}).get("rarity", "R")))
	var cap := int(GameData.constants.get("FLEET_CAPACITY", 10))
	var slots := int(GameData.constants.get("FLEET_SLOTS", 5))
	lbl_cost.text = "COST %d / %d · 槽位 %d / %d" % [cost, cap, _fleet.size(), slots]
	if cost > cap:
		lbl_cost.add_theme_color_override("font_color", VoyageTheme.DANGER)
	elif _fleet.size() >= slots:
		lbl_cost.add_theme_color_override("font_color", VoyageTheme.WARN)
	else:
		lbl_cost.add_theme_color_override("font_color", VoyageTheme.SUCCESS.lightened(0.15))
	if _predict:
		_predict.refresh(_fleet)

func _show_preview(card_id: String) -> void:
	var info: Dictionary = DisplayNamesScript.for_card(card_id)
	var sys := str(info.get("system", ""))
	var tex := AssetDB.card_illu(card_id)
	if tex == null:
		tex = AssetDB.card_bust(card_id)
	_preview.texture = tex
	_preview_frame.add_theme_stylebox_override("panel", VoyageTheme.portrait_frame(sys))
	var c: Dictionary = GameData.cards.get(card_id, {})
	_preview_lbl.text = "[b]%s[/b]  %s\n%s · %s\n%s\n技能：%s" % [
		info.get("display", card_id),
		info.get("shape", ""),
		VoyageTheme.bb(VoyageTheme.INFO, str(info.get("mechanism", ""))),
		GameData.SYS_NAME.get(sys, "?"),
		VoyageTheme.bb(VoyageTheme.MUTED, str(c.get("identity", ""))),
		str(c.get("skill", {}).get("name", "—")),
	]

func _on_owned_selected(i: int) -> void:
	_show_preview(str(list_owned.get_item_metadata(i)))

func _on_fleet_selected(i: int) -> void:
	_show_preview(str(list_fleet.get_item_metadata(i)))

func _on_add() -> void:
	var idxs := list_owned.get_selected_items()
	if idxs.is_empty():
		return
	var id: String = str(list_owned.get_item_metadata(idxs[0]))
	if _fleet.has(id):
		GameState.emit_signal("toast", "编队中已有此卡")
		Juice.deny_pulse()
		return
	var trial := _fleet.duplicate()
	trial.append(id)
	if not _validate(trial):
		return
	_fleet = trial
	Sfx.play_event("sfx_ui_slot_place")
	Juice.punch(list_fleet)
	_rebuild()
	_update_hint()

func _on_remove() -> void:
	var idxs := list_fleet.get_selected_items()
	if idxs.is_empty():
		return
	_fleet.remove_at(idxs[0])
	Sfx.play_select()
	_rebuild()
	_update_hint()

func _validate(trial: Array) -> bool:
	var check: Dictionary = FleetRulesScript.validate(trial, GameState.owned_cards)
	if not bool(check.get("ok", false)):
		GameState.emit_signal("toast", str(check.get("reason", "编队非法")))
		if str(check.get("reason", "")).contains("COST"):
			Sfx.play_event("sfx_ui_cost_warn")
		Juice.deny_pulse()
		return false
	return true

func _on_save() -> void:
	if _fleet.is_empty():
		GameState.emit_signal("toast", "编队不能为空")
		Juice.deny_pulse()
		return
	if GameState.set_fleet(_fleet):
		Sfx.play_event("sfx_ui_fleet_confirm")
		Juice.celebrate()
		queue_free()

func _update_hint() -> void:
	lbl_hint.text = "%s  双击列表可快速加入/移出。" % VoyageTheme.bb(
		VoyageTheme.MUTED, "支柱：看上方预测仪表盘的克制点，再保存编队。"
	)
