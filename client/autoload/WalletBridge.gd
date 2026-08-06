extends Node
## Aleo 钱包：优先 Provable SDK（wallet-bridge :8788 via Sidecar），失败再本地 stub

signal wallet_changed(address: String)

var address: String = ""
var connected := false
var path: String = "none"

func _ready() -> void:
	address = str(GameState.tutorial_flags.get("wallet_address", ""))
	connected = address != ""
	path = str(GameState.tutorial_flags.get("wallet_path", "none"))

func create_or_connect() -> Dictionary:
	# 1) Provable SDK via Sidecar → wallet-bridge
	var created := ChainGateway.sidecar_post("/wallet/create", {})
	if bool(created.get("ok", false)):
		address = str(created.get("address", ""))
		path = "provable_sdk"
		_persist()
		wallet_changed.emit(address)
		return {"ok": true, "address": address, "path": path, "sidecar": created}
	var conn := ChainGateway.sidecar_post("/wallet/connect", {})
	if bool(conn.get("ok", false)) and str(conn.get("address", "")) != "":
		address = str(conn.get("address", ""))
		path = "provable_sdk"
		connected = true
		_persist()
		wallet_changed.emit(address)
		return {"ok": true, "address": address, "path": path, "sidecar": conn}
	# 2) Demo stub（无 bridge 时）
	if address == "":
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(str(Time.get_unix_time_from_system()).to_utf8_buffer())
		address = "aleo1local%s" % ctx.finish().hex_encode().substr(0, 16)
	path = "local_stub"
	connected = true
	_persist()
	wallet_changed.emit(address)
	return {
		"ok": true,
		"address": address,
		"path": path,
		"note": "Start chain/wallet-bridge (npm i && npm start) for Provable SDK account",
	}

func network_hint() -> String:
	## Leo Wallet / 浏览器扩展：必须先手动切到 Aleo 测试网再连接
	return "注意：Leo Wallet 用户必须先手动将网络更改为 Aleo 测试网才能连接。"

func fund_hint() -> String:
	if address == "" or path == "local_stub":
		return "%s 先创建/连接钱包（经营 → 钱包）" % network_hint()
	return "%s 测试网水龙头注资（免费）：https://faucet.aleo.org/ → %s" % [network_hint(), address]

func short_address() -> String:
	if address.length() <= 12:
		return address
	return address.substr(0, 8) + "…" + address.substr(address.length() - 4, 4)

func _persist() -> void:
	GameState.tutorial_flags["wallet_address"] = address
	GameState.tutorial_flags["wallet_path"] = path
	GameState.save_game()
