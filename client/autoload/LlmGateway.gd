extends Node
## OpenAI 兼容 Chat Completions（港主简报等）
## 密钥：res://config/llm.local.json（已 gitignore）

signal brief_ready(text: String, meta: Dictionary)

var _cfg: Dictionary = {}
var _cache: Dictionary = {}
var _http: HTTPRequest
var _pending := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 25.0
	add_child(_http)
	_load_cfg()

func _load_cfg() -> void:
	_cfg = {
		"enabled": false,
		"base_url": "https://www.abc-ai.cn/v1/chat/completions",
		"model": "Qwen-flash",
		"api_key": "",
		"temperature": 0.7,
		"timeout_sec": 25,
	}
	var path := "res://config/llm.local.json"
	if not FileAccess.file_exists(path):
		path = "res://config/llm.example.json"
	if FileAccess.file_exists(path):
		var raw := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(raw)
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in parsed.keys():
				_cfg[k] = parsed[k]
	_http.timeout = float(_cfg.get("timeout_sec", 25))

func is_configured() -> bool:
	return bool(_cfg.get("enabled", false)) and str(_cfg.get("api_key", "")).strip_edges() != ""

func harbor_brief_async(island_id: String) -> void:
	if _pending:
		return
	var cache_key := "%s@%d" % [island_id, GameState.day]
	if _cache.has(cache_key):
		brief_ready.emit(str(_cache[cache_key]), {"cached": true, "source": "cache"})
		return
	if not is_configured() or not App.flag("llm_harbor", true):
		var fb := _fallback_brief(island_id)
		_cache[cache_key] = fb
		brief_ready.emit(fb, {"cached": false, "source": "fallback"})
		return
	_pending = true
	var prompt := _build_prompt(island_id)
	var body := {
		"model": str(_cfg.get("model", "Qwen-flash")),
		"temperature": float(_cfg.get("temperature", 0.7)),
		"messages": [
			{
				"role": "system",
				"content": "你是大航海 SLG 的港主简报官。用中文，2～4 句，沉稳、有海味道，禁止剧透未解锁内容，禁止编造具体数值以外的虚假战果。只输出简报正文。",
			},
			{"role": "user", "content": prompt},
		],
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % str(_cfg.get("api_key", "")),
	])
	var err := _http.request(
		str(_cfg.get("base_url", "")),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if err != OK:
		_pending = false
		var fb2 := _fallback_brief(island_id)
		brief_ready.emit(fb2, {"cached": false, "source": "error", "err": err})
		return
	var completed: Array = await _http.request_completed
	_pending = false
	var result: int = completed[0]
	var response_code: int = completed[1]
	var response_body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var fb3 := _fallback_brief(island_id)
		brief_ready.emit(fb3, {"cached": false, "source": "http", "code": response_code})
		return
	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	var text := ""
	if typeof(parsed) == TYPE_DICTIONARY:
		var choices = parsed.get("choices", [])
		if typeof(choices) == TYPE_ARRAY and choices.size() > 0:
			var msg = choices[0].get("message", {})
			text = str(msg.get("content", "")).strip_edges()
	if text == "":
		text = _fallback_brief(island_id)
		brief_ready.emit(text, {"cached": false, "source": "empty"})
		return
	_cache[cache_key] = text
	brief_ready.emit(text, {"cached": false, "source": "llm"})

func _build_prompt(island_id: String) -> String:
	var isl: Dictionary = GameData.islands.get(island_id, {})
	var war := {}
	if str(GameState.alliance.get("id", "")) != "":
		war = {
			"name": GameState.alliance.get("name", ""),
			"us": int(GameState.alliance.get("war_score", 0)),
			"them": int(GameState.alliance.get("rival_score", 0)),
			"rival": GameState.alliance.get("rival_name", "赤潮联航"),
		}
	return "第%d日 · 港口「%s」（%s）· 体力%d · 战略%d · 占领岛%d · 赛季%s · 联航%s。请给船长一段港主简报。" % [
		GameState.day,
		str(isl.get("name", island_id)),
		island_id,
		GameState.stamina,
		GameState.strategic,
		GameState.owned_islands.size(),
		SeasonDirector.season_label(),
		JSON.stringify(war) if not war.is_empty() else "未加入",
	]

func _fallback_brief(island_id: String) -> String:
	var name := VoyageTheme.island_label(island_id)
	var owned := GameState.owned_islands.has(island_id)
	var lines: PackedStringArray = []
	lines.append("港主点头：「%s」%s。" % [name, "已在你旗下，货栈灯火通明" if owned else "仍听潮声，未换旗帜"])
	lines.append("今日是第 %d 日，%s；舱里还剩 %d 体力、%d 战略。" % [
		GameState.day, SeasonDirector.season_label(), GameState.stamina, GameState.strategic,
	])
	if str(GameState.alliance.get("id", "")) != "":
		lines.append("联航战报传来：我方 %d，对阵 %s %d。潮水不等人。" % [
			int(GameState.alliance.get("war_score", 0)),
			str(GameState.alliance.get("rival_name", "赤潮联航")),
			int(GameState.alliance.get("rival_score", 0)),
		])
	else:
		lines.append("北洋联航仍在招旗手——若你想打联航仗，码头文书处可以落名。")
	return "\n".join(lines)
