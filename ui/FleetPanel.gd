extends CanvasLayer

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

var _fleet: Array = []

func _ready() -> void:
	_fleet = GameState.fleet.duplicate()
	dim.modulate.a = 0
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	panel.scale = Vector2(0.94, 0.94)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn_add.pressed.connect(_on_add)
	btn_remove.pressed.connect(_on_remove)
	btn_save.pressed.connect(_on_save)
	btn_close.pressed.connect(queue_free)
	list_owned.item_activated.connect(func(_i): _on_add())
	list_fleet.item_activated.connect(func(_i): _on_remove())
	_rebuild()
	_update_hint()

func _rebuild() -> void:
	list_owned.clear()
	for id in GameState.owned_cards:
		var c: Dictionary = GameData.cards.get(id, {})
		var col := GameData.system_color(str(c.get("system", "")))
		var text := "%s  [%s/%s] COST%d" % [
			c.get("name", id),
			GameData.SYS_NAME.get(c.get("system", ""), "?"),
			c.get("rarity", "?"),
			GameData.rarity_cost(str(c.get("rarity", "R")))
		]
		var i := list_owned.add_item(text)
		list_owned.set_item_metadata(i, id)
		list_owned.set_item_custom_fg_color(i, col)
	list_fleet.clear()
	for id in _fleet:
		var c: Dictionary = GameData.cards.get(id, {})
		var col := GameData.system_color(str(c.get("system", "")))
		var text := "%s  · %s" % [c.get("name", id), GameData.SYS_NAME.get(c.get("system", ""), "?")]
		var i := list_fleet.add_item(text)
		list_fleet.set_item_metadata(i, id)
		list_fleet.set_item_custom_fg_color(i, col)
	var cost := 0
	for id in _fleet:
		cost += GameData.rarity_cost(str(GameData.cards.get(id, {}).get("rarity", "R")))
	lbl_cost.text = "COST %d / %d · 槽位 %d / %d" % [
		cost,
		int(GameData.constants.get("FLEET_CAPACITY", 10)),
		_fleet.size(),
		int(GameData.constants.get("FLEET_SLOTS", 5))
	]

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
	Sfx.play_select()
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
	if trial.size() > int(GameData.constants.get("FLEET_SLOTS", 5)):
		GameState.emit_signal("toast", "槽位已满")
		Juice.deny_pulse()
		return false
	var cost := 0
	var sys_count := {}
	for id in trial:
		var c: Dictionary = GameData.cards[id]
		cost += GameData.rarity_cost(c["rarity"])
		sys_count[c["system"]] = int(sys_count.get(c["system"], 0)) + 1
	if cost > int(GameData.constants.get("FLEET_CAPACITY", 10)):
		GameState.emit_signal("toast", "COST 超限")
		Juice.deny_pulse()
		return false
	var soft := int(GameData.constants.get("SAME_SYS_SOFT_CAP", 4))
	for s in sys_count.keys():
		if int(sys_count[s]) > soft:
			GameState.emit_signal("toast", "同体系最多 %d" % soft)
			Juice.deny_pulse()
			return false
	return true

func _on_save() -> void:
	if _fleet.is_empty():
		GameState.emit_signal("toast", "编队不能为空")
		Juice.deny_pulse()
		return
	if GameState.set_fleet(_fleet):
		Sfx.play_ok()
		Juice.celebrate()
		queue_free()

func _update_hint() -> void:
	var flame := 0
	var iron := 0
	for id in _fleet:
		var s = GameData.cards.get(id, {}).get("system", "")
		if s == "flame":
			flame += 1
		if s == "ironwall":
			iron += 1
	var tip := "冻洋守卫偏铁壁。编入烈焰可打出 [color=#e85d04]克制×1.3[/color]。"
	if flame > 0:
		tip += " 当前烈焰 %d 张 — 优势面已打开。" % flame
	elif iron >= 3:
		tip += " 纯铁壁能吃环境×1.15，但怕火。"
	lbl_hint.text = tip
