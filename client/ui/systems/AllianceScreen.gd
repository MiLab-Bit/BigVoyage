extends CanvasLayer
## 联航屏：对阵看板 + 可读战报 + 突袭

const AllianceServiceScript := preload("res://systems/social/AllianceService.gd")
const RaidServiceScript := preload("res://systems/social/RaidService.gd")
const SystemsOverlayScript := preload("res://ui/systems/SystemsOverlay.gd")
const WarLogViewScript := preload("res://ui/systems/WarLogView.gd")

var _body: RichTextLabel
var _actions: VBoxContainer
var _log_host: VBoxContainer

func _ready() -> void:
	var shell: Dictionary = SystemsOverlayScript.mount(self, "赛季联航", Vector2(800, 640))
	var v: VBoxContainer = shell.vbox
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(0, 140)
	v.add_child(_body)
	var log_title := Label.new()
	log_title.text = "近期战报"
	log_title.add_theme_color_override("font_color", VoyageTheme.COPPER.lightened(0.1))
	v.add_child(log_title)
	var log_scroll := ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(0, 160)
	v.add_child(log_scroll)
	_log_host = VBoxContainer.new()
	_log_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_host.add_theme_constant_override("separation", 6)
	log_scroll.add_child(_log_host)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	v.add_child(scroll)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_actions)
	_refresh()

func _refresh() -> void:
	for c in _actions.get_children():
		c.queue_free()
	for c in _log_host.get_children():
		c.queue_free()
	var al: Dictionary = GameState.alliance
	if str(al.get("id", "")) == "":
		_body.text = "赛季联航对抗：加入后可突袭邻据、与敌联「赤潮联航」比拼战绩；税率入金库，高潮期可领金库奖。"
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "自建联盟名称"
		_actions.add_child(name_edit)
		var b := Button.new()
		b.text = "创建联盟"
		b.pressed.connect(func():
			var r: Dictionary = AllianceServiceScript.create(name_edit.text)
			if bool(r.get("ok", false)):
				Sfx.play_event("sfx_ui_fleet_confirm")
				NarrativeDirector.try_chapter("alliance_join")
			else:
				Sfx.play_deny()
			GameState.emit_signal("toast", "联盟已创建" if r.get("ok") else str(r.get("reason")))
			_refresh()
		)
		_actions.add_child(b)
		var join := Button.new()
		join.text = "加入赛季联航「北洋联航」"
		join.pressed.connect(func():
			var r2: Dictionary = AllianceServiceScript.join_season_league()
			if bool(r2.get("ok", false)):
				Sfx.play_event("sfx_ui_fleet_confirm")
				NarrativeDirector.try_chapter("alliance_join")
			else:
				Sfx.play_deny()
			GameState.emit_signal("toast", "已加入北洋联航" if r2.get("ok") else str(r2.get("reason")))
			_refresh()
		)
		_actions.add_child(join)
		return
	var war: Dictionary = AllianceServiceScript.season_war_snapshot()
	var lead := int(war.get("lead", 0))
	var lead_bb := VoyageTheme.bb(VoyageTheme.SUCCESS if lead >= 0 else VoyageTheme.DANGER, "%+d" % lead)
	_body.text = "联盟 [b]%s[/b] · 领袖 %s\n税率 %.0f%% · 金库 %d · 战绩 %d胜/%d负 · 上限 %d\n\n[b]对阵看板[/b]  vs %s · 阶段 %s\n我方 [b]%d[/b]  :  敌联 [b]%d[/b]（差 %s）· 敌出征 %d\n%s" % [
		al.get("name", ""), al.get("leader", ""),
		float(al.get("tax", 0)) * 100.0, int(al.get("treasury", 0)),
		int(al.get("gvg_wins", 0)), int(al.get("gvg_losses", 0)),
		AllianceServiceScript.member_cap(),
		str(war.get("rival_name", "赤潮联航")), str(war.get("phase", "idle")),
		int(war.get("war_score", 0)), int(war.get("rival_score", 0)), lead_bb,
		int(war.get("rival_sorties", 0)),
		VoyageTheme.bb(VoyageTheme.INFO, "日产/贸易税入金库；高潮期可突袭同海终核"),
	]
	WarLogViewScript.fill(_log_host, war.get("log", []))
	var tax := Button.new()
	tax.text = "税率设为 5%（上限）"
	tax.pressed.connect(func():
		var r: Dictionary = AllianceServiceScript.set_tax(0.05)
		GameState.emit_signal("toast", "税率已更新" if r.get("ok") else str(r.get("reason")))
		Sfx.play_ok()
		_refresh()
	)
	_actions.add_child(tax)
	var tax3 := Button.new()
	tax3.text = "税率设为 3%"
	tax3.pressed.connect(func():
		AllianceServiceScript.set_tax(0.03)
		Sfx.play_ok()
		_refresh()
	)
	_actions.add_child(tax3)
	var pay := Button.new()
	pay.text = "捐献 200 战略"
	pay.pressed.connect(func():
		var r: Dictionary = AllianceServiceScript.contribute(200)
		if bool(r.get("ok", false)):
			Sfx.play_event("sfx_ui_reward")
		else:
			Sfx.play_deny()
		GameState.emit_signal("toast", "捐献成功" if r.get("ok") else str(r.get("reason")))
		_refresh()
	)
	_actions.add_child(pay)
	if bool(war.get("claim_ready", false)):
		var chest := Button.new()
		chest.text = "领取联航战金库奖励"
		chest.pressed.connect(func():
			var cr: Dictionary = AllianceServiceScript.claim_war_chest()
			if bool(cr.get("ok", false)):
				Sfx.play_event("sfx_ui_reward")
				Juice.celebrate()
				NarrativeDirector.try_chapter("war_chest")
			GameState.emit_signal("toast", "联航战 +%d" % int(cr.reward) if cr.get("ok") else str(cr.get("reason")))
			_refresh()
		)
		_actions.add_child(chest)
	var gvg_title := Label.new()
	gvg_title.text = "— 联航突袭 —"
	_actions.add_child(gvg_title)
	for tid in RaidServiceScript.targets_from(GameState.current_island):
		var gate: Dictionary = RaidServiceScript.can_raid(tid)
		var gb := Button.new()
		gb.theme_type_variation = "VoyageDangerButton"
		gb.text = "突袭 %s" % VoyageTheme.island_label(str(tid))
		gb.disabled = not bool(gate.get("ok", false))
		if gb.disabled:
			gb.tooltip_text = str(gate.get("reason", "不可突袭"))
		var island: String = tid
		gb.pressed.connect(func():
			var r: Dictionary = RaidServiceScript.raid(island)
			if not bool(r.get("ok", false)):
				Sfx.play_deny()
				GameState.emit_signal("toast", str(r.get("reason", "失败")))
				return
			Sfx.play_event("sfx_btl_finisher")
			var battle: Dictionary = r.get("battle", {})
			battle["gvg"] = true
			var main = get_tree().current_scene
			if main and main.has_method("_play_battle"):
				main._selected = island
				main._play_battle(battle, GameData.islands.get(island, {"id": island, "name": island}))
			GameState.emit_signal("toast", "联航突袭 %s · 战利品 %d" % ["胜" if r.get("won") else "败", int(r.get("loot", 0))])
			queue_free()
		)
		_actions.add_child(gb)
	var leave := Button.new()
	leave.text = "退出联盟"
	leave.pressed.connect(func():
		AllianceServiceScript.leave()
		Sfx.play_select()
		_refresh()
	)
	_actions.add_child(leave)
