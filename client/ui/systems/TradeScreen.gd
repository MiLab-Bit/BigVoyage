extends CanvasLayer
## 贸易屏：港际跑商 + 三角航线

const TradeServiceScript := preload("res://systems/economy/TradeService.gd")
const AllianceServiceScript := preload("res://systems/social/AllianceService.gd")
const SystemsOverlayScript := preload("res://ui/systems/SystemsOverlay.gd")

var _tab := "direct"
var _body: RichTextLabel
var _actions: VBoxContainer

func _ready() -> void:
	var shell: Dictionary = SystemsOverlayScript.mount(self, "贸易港务", Vector2(780, 620))
	var v: VBoxContainer = shell.vbox
	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for t in [["direct", "直航跑商"], ["triangle", "三角航线"]]:
		var b := Button.new()
		b.text = t[1]
		var id: String = t[0]
		b.pressed.connect(func():
			_tab = id
			Sfx.play_select()
			_refresh()
		)
		tabs.add_child(b)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.custom_minimum_size = Vector2(0, 120)
	_body.fit_content = true
	v.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 320)
	v.add_child(scroll)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_actions)
	_refresh()

func _refresh() -> void:
	for c in _actions.get_children():
		c.queue_free()
	if _tab == "triangle":
		_refresh_triangle()
	else:
		_refresh_direct()

func _refresh_direct() -> void:
	var from_id := GameState.current_island
	var tax := AllianceServiceScript.tax_rate()
	_body.text = "当前港：[b]%s[/b]\n联盟税率 %.0f%% · 跑商耗 2 体力\n%s" % [
		VoyageTheme.island_label(from_id), tax * 100.0,
		VoyageTheme.bb(VoyageTheme.MUTED, "选择已占领港执行一单。"),
	]
	for id in GameState.owned_islands:
		if id == from_id:
			continue
		if not GameData.trade_prices.get("ports", {}).has(id):
			continue
		for good in GameData.trade_prices.get("goods", []):
			var q: Dictionary = TradeServiceScript.quote(from_id, id, str(good), 1)
			var b := Button.new()
			b.text = "%s → %s · %s  %+d（税 %d）" % [
				VoyageTheme.island_label(from_id), VoyageTheme.island_label(str(id)),
				good, int(q.get("net", 0)), int(q.get("tax", 0)),
			]
			b.disabled = not bool(q.get("ok", false))
			if b.disabled:
				b.tooltip_text = str(q.get("reason", "不可交易"))
			var gid: String = str(good)
			var tid: String = str(id)
			b.pressed.connect(func():
				var r: Dictionary = TradeServiceScript.execute(from_id, tid, gid, 1)
				if bool(r.get("ok", false)):
					Sfx.play_event("sfx_ui_reward")
					Juice.celebrate()
					GameState.emit_signal("toast", "贸易成功 +%d" % int(r.net))
					NarrativeDirector.try_chapter("first_trade")
				else:
					Sfx.play_deny()
					GameState.emit_signal("toast", str(r.get("reason", "失败")))
				_refresh()
			)
			_actions.add_child(b)
	if _actions.get_child_count() == 0:
		var tip := Label.new()
		tip.text = "暂无可跑商路线：先占领更多贸易港。"
		tip.add_theme_color_override("font_color", VoyageTheme.MUTED)
		_actions.add_child(tip)

func _refresh_triangle() -> void:
	var a := GameState.current_island
	_body.text = "三角 [b]A→B→C[/b] · 当前 A=%s\n运费/风险按海域；跨海加码；终核与三海有终局加成。" % VoyageTheme.island_label(a)
	var ports: Array = []
	for id in GameData.trade_prices.get("ports", {}).keys():
		ports.append(str(id))
	ports.sort()
	var goods: Array = GameData.trade_prices.get("goods", [])
	var shown := 0
	for b in ports:
		if b == a:
			continue
		for c in ports:
			if c == a or c == b:
				continue
			if not GameState.owned_islands.has(c) and not GameState.owned_islands.has(b):
				continue
			var g0 := str(goods[0]) if goods.size() > 0 else "timber"
			var g1 := str(goods[1]) if goods.size() > 1 else g0
			var q: Dictionary = TradeServiceScript.quote_triangle(a, b, c, g0, g1, 1)
			if not bool(q.get("ok", false)):
				continue
			var btn := Button.new()
			var tag := ""
			if bool(q.get("three_sea", false)):
				tag += "·三海"
			if bool(q.get("endgame", false)):
				tag += "·终局"
			btn.text = "%s→%s→%s · %s/%s  %+d%s" % [
				VoyageTheme.island_label(a), VoyageTheme.island_label(str(b)), VoyageTheme.island_label(str(c)),
				g0, g1, int(q.get("net", 0)), tag,
			]
			var bb: String = b
			var cc: String = c
			var gg0: String = g0
			var gg1: String = g1
			btn.pressed.connect(func():
				var r: Dictionary = TradeServiceScript.execute_triangle(a, bb, cc, gg0, gg1, 1)
				if bool(r.get("ok", false)):
					Sfx.play_event("sfx_ui_reward")
					GameState.emit_signal("toast", "三角 +%d" % int(r.net))
					NarrativeDirector.try_chapter("first_trade")
				else:
					Sfx.play_deny()
					GameState.emit_signal("toast", str(r.get("reason", "失败")))
				_refresh()
			)
			_actions.add_child(btn)
			shown += 1
			if shown >= 12:
				return
	if shown == 0:
		var tip := Label.new()
		tip.text = "暂无正利三角线：先占领更多贸易港。"
		tip.add_theme_color_override("font_color", VoyageTheme.MUTED)
		_actions.add_child(tip)
