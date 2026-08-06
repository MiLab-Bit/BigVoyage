extends Node
## 链网关：mock FieldMapper / Sidecar leo run(Poseidon8 snarkVM) / wallet execute

signal commit_finished(receipt: Dictionary)

const FieldMapperScript := preload("res://core/FieldMapper.gd")

const HASH_ALG := "poseidon8_snarkvm_v1"
## soft_v1 仅兼容读旧收据，禁止写入新 commit
const HASH_ALG_LEGACY_SOFT := "poseidon8_soft_v1"

var mock_enabled: bool = true
var last_receipt: Dictionary = {}
var sidecar_host: String = "127.0.0.1"
var sidecar_port: int = 8787

func _ready() -> void:
	mock_enabled = bool(GameData.constants.get("CHAIN_MOCK", true))
	var url := str(GameData.constants.get("CHAIN_SIDECAR_URL", "http://127.0.0.1:8787"))
	_parse_url(url)
	print("[ChainGateway] mock=%s sidecar=%s:%d hash_alg=%s" % [str(mock_enabled), sidecar_host, sidecar_port, HASH_ALG])

func _parse_url(url: String) -> void:
	var u := url.trim_prefix("http://").trim_prefix("https://")
	var parts := u.split(":")
	if parts.size() >= 1:
		sidecar_host = parts[0]
	if parts.size() >= 2:
		sidecar_port = int(parts[1].split("/")[0])

func commit_battle(result: Dictionary, meta: Dictionary = {}) -> Dictionary:
	var winner := str(result.get("winner", ""))
	var wcode := 1 if winner == "A" else (2 if winner == "B" else 0)
	var env_h := "0"
	if typeof(result.get("env", null)) == TYPE_DICTIONARY:
		env_h = "%x" % abs(int(JSON.stringify(result.env).hash()))
	var season_n := 1
	if has_node("/root/SeasonDirector"):
		season_n = int(str(SeasonDirector.current_season).replace("S", ""))
	var payload := {
		"ruleset_h": str(result.get("ruleset_hash", EngineLock.RULESET_HASH_DESIGN)),
		"fleets_h": str(result.get("hash", "0")),
		"env_h": env_h,
		"seed": int(meta.get("seed", result.get("seed", 0))),
		"winner": wcode,
		"rounds": int(result.get("rounds", 0)),
		"log_root": str(result.get("log_root", result.get("hash", "0"))),
		"season": season_n,
	}
	var mapped: Dictionary = FieldMapperScript.map_commit_payload(payload)
	var receipt := {
		"mock": mock_enabled,
		"ok": true,
		"commit": "",
		"mapped": mapped,
		"sha_design": str(result.get("hash", "")),
		"hash_alg": HASH_ALG,
		"log_root": str(result.get("log_root", "")),
		"ruleset_hash": str(result.get("ruleset_hash", "")),
		"winner": winner,
		"rounds": int(result.get("rounds", 0)),
		"island_id": str(meta.get("island_id", "")),
		"ts": Time.get_unix_time_from_system(),
		"program": "bv_commit.aleo",
		"path": "mock_field_map" if mock_enabled else "sidecar_leo",
		"wallet": WalletBridge.address if has_node("/root/WalletBridge") else "",
		"note": "authoritative commit = Sidecar leo run Poseidon8; mock only maps fields",
	}
	# Always prefer Sidecar for snarkVM Poseidon8 when reachable (even if CHAIN_MOCK)
	var live := sidecar_post("/commit", {
		"hash": str(result.get("hash", "")),
		"ruleset_hash": payload.ruleset_h,
		"fleets_h": payload.fleets_h,
		"env_h": payload.env_h,
		"seed": payload.seed,
		"winner": winner,
		"rounds": payload.rounds,
		"log_root": payload.log_root,
		"season": payload.season,
		"island_id": receipt.island_id,
		"broadcast": bool(meta.get("broadcast", false)),
	})
	if bool(live.get("ok", false)):
		receipt["sidecar"] = live
		receipt["commit"] = str(live.get("commit", ""))
		receipt["leo"] = live.get("leo", {})
		receipt["wallet_execute"] = live.get("wallet_execute", {})
		receipt["path"] = "sidecar_leo"
		receipt["mock"] = false
		print("[ChainGateway] %s commit %s…" % [HASH_ALG, str(receipt.commit).substr(0, 12)])
	elif mock_enabled:
		receipt["commit"] = "pending_leo:%s" % mapped.get("ruleset_h", "")
		receipt["path"] = "mock_field_map_pending_leo"
		receipt["sidecar_error"] = str(live.get("error", live.get("leo", {}).get("error", "unreachable")))
		print("[ChainGateway] field-mapped mock (leo pending) %s" % str(receipt.commit).substr(0, 24))
	else:
		receipt["ok"] = false
		receipt["path"] = "sidecar_fail"
		receipt["sidecar_error"] = str(live.get("error", "unreachable"))
		receipt["commit"] = ""
		push_warning("[ChainGateway] sidecar/leo fail — no soft_v1 fallback for new commits")
	_emit_receipt(receipt)
	return receipt

func sidecar_post(path: String, body: Dictionary) -> Dictionary:
	return _http_json("POST", path, body)

func sidecar_get(path: String) -> Dictionary:
	return _http_json("GET", path, {})

func health() -> Dictionary:
	var h := sidecar_get("/health")
	if bool(h.get("ok", false)):
		return {"ok": true, "mock": mock_enabled, "hash_alg": HASH_ALG, "sidecar": h, "last": last_receipt.get("commit", "")}
	if mock_enabled:
		return {"ok": true, "mock": true, "hash_alg": HASH_ALG, "last": last_receipt.get("commit", ""), "note": "sidecar offline"}
	return {"ok": false, "mock": false, "hash_alg": HASH_ALG, "sidecar": h}

func _emit_receipt(receipt: Dictionary) -> void:
	last_receipt = receipt
	commit_finished.emit(receipt)
	if has_node("/root/EventBus"):
		EventBus.chain_commit_done.emit(receipt)

func _http_json(method: String, path: String, body: Dictionary) -> Dictionary:
	var http := HTTPClient.new()
	var err := http.connect_to_host(sidecar_host, sidecar_port)
	if err != OK:
		return {"ok": false, "error": "connect"}
	var t0 := Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		if Time.get_ticks_msec() - t0 > 1200:
			return {"ok": false, "error": "connect_timeout"}
		OS.delay_msec(5)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"ok": false, "error": "not_connected"}
	var headers := PackedStringArray(["Content-Type: application/json", "Connection: close"])
	var payload := "" if method == "GET" else JSON.stringify(body)
	var m := HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST
	err = http.request(m, path, headers, payload)
	if err != OK:
		return {"ok": false, "error": "request"}
	# leo run can be slow
	var timeout_ms := 180000 if path == "/commit" else 5000
	t0 = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		if Time.get_ticks_msec() - t0 > timeout_ms:
			return {"ok": false, "error": "request_timeout"}
		OS.delay_msec(5)
	if not http.has_response():
		return {"ok": false, "error": "no_response"}
	var rb := PackedByteArray()
	t0 = Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() > 0:
			rb.append_array(chunk)
		else:
			OS.delay_msec(2)
		if Time.get_ticks_msec() - t0 > timeout_ms:
			break
	var parsed = JSON.parse_string(rb.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "bad_json"}
	return parsed
