extends Node
## 支付合规闸：本机完整免费体验（无内购、无真货币支付）
## COMPLIANCE_PAYMENTS_ENABLED 保持 false；不接支付通道是产品定案，不是半成品缺口

signal compliance_ready

var ready_for_play := false

func _ready() -> void:
	await get_tree().process_frame
	if bool(GameState.compliance.get("accepted", false)):
		ready_for_play = true
		compliance_ready.emit()
		return
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		GameState.compliance = {
			"accepted": true,
			"age_ok": true,
			"region": "CN-dev",
			"payments_ack": true,
			"free_complete": true,
			"headless": true,
		}
		ready_for_play = true
		compliance_ready.emit()

func payments_allowed() -> bool:
	## 定案：本版本完整免费，永不开放真支付
	return false

func ensure_interactive() -> void:
	if ready_for_play or bool(GameState.compliance.get("accepted", false)):
		ready_for_play = true
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.92)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "VoyageCopperPanel"
	panel.custom_minimum_size = Vector2(640, 420)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -210
	panel.offset_bottom = 210
	layer.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := Label.new()
	title.text = "启航须知"
	title.add_theme_font_size_override("font_size", 26)
	v.add_child(title)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.custom_minimum_size = Vector2(0, 200)
	rtl.text = "1. 本版本为 [b]完整免费体验[/b]：无内购、无真实货币支付、体力靠过日刷新。\n2. 四海域 36 岛、赛季联航对抗、贸易/科技均可在本机完整体验。\n3. 可选连接 Aleo 钱包仅供开发者验证链承诺，[b]不影响完整游玩[/b]。\n4. 请确认已满 18 周岁。"
	v.add_child(rtl)
	var age := CheckBox.new()
	age.text = "我已满 18 周岁"
	v.add_child(age)
	var region := OptionButton.new()
	region.add_item("中国大陆", 0)
	region.add_item("其他地区", 1)
	v.add_child(region)
	var ok := Button.new()
	ok.text = "开始航程"
	ok.pressed.connect(func():
		if not age.button_pressed:
			GameState.emit_signal("toast", "需确认年龄")
			return
		GameState.compliance = {
			"accepted": true,
			"age_ok": true,
			"region": "CN" if region.selected == 0 else "OTHER",
			"payments_ack": true,
			"free_complete": true,
			"ts": Time.get_unix_time_from_system(),
		}
		GameState.save_game()
		ready_for_play = true
		compliance_ready.emit()
		layer.queue_free()
	)
	v.add_child(ok)
	get_tree().root.add_child(layer)
	await compliance_ready

func try_paid_stamina(_amount: int) -> bool:
	GameState.emit_signal("toast", "本版本完整免费 · 请用空格过日刷新体力")
	Juice.deny_pulse()
	return false
