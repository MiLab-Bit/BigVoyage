extends CanvasLayer
## 钱包次级页

const SystemsOverlayScript := preload("res://ui/systems/SystemsOverlay.gd")

var _body: RichTextLabel
var _actions: VBoxContainer

func _ready() -> void:
	var shell: Dictionary = SystemsOverlayScript.mount(self, "钱包（可选）", Vector2(640, 480))
	var v: VBoxContainer = shell.vbox
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(0, 260)
	v.add_child(_body)
	_actions = VBoxContainer.new()
	v.add_child(_actions)
	_refresh()

func _refresh() -> void:
	for c in _actions.get_children():
		c.queue_free()
	_body.text = "可选 Aleo 钱包（不影响本机完整游玩）\n网络：testnet\n%s\n地址：%s\n路径：%s\n承诺算法：%s\n资金：%s\nSidecar：%s\n%s" % [
		WalletBridge.network_hint(),
		WalletBridge.address if WalletBridge.address != "" else "（未连接 · 可正常游玩）",
		WalletBridge.path,
		EngineLock.HASH_ALG,
		WalletBridge.fund_hint(),
		"mock=%s" % str(ChainGateway.mock_enabled),
		VoyageTheme.bb(VoyageTheme.INFO, "未连接时战斗仍正常结算；连接仅用于开发者验证链承诺。"),
	]
	var b := Button.new()
	b.text = "创建 / 连接钱包"
	b.pressed.connect(func():
		var r: Dictionary = WalletBridge.create_or_connect()
		Sfx.play_ok()
		GameState.emit_signal("toast", "钱包 %s (%s)" % [r.get("address", r.get("error", "")), r.get("path", "")])
		_refresh()
	)
	_actions.add_child(b)
	var fund := Button.new()
	fund.text = "资金提示（水龙头）"
	fund.pressed.connect(func():
		GameState.emit_signal("toast", WalletBridge.fund_hint())
	)
	_actions.add_child(fund)
