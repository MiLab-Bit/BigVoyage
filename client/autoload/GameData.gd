extends Node
## 单一真源：加载 data/*.json · 支持全量 world_full 海域过滤

var constants: Dictionary = {}
var cards: Dictionary = {} # id -> card
var card_list: Array = []
var islands: Dictionary = {} # id -> island
var island_list: Array = []
var sea_theme: Dictionary = {}
var ships: Dictionary = {}
var guards: Dictionary = {}
var adjacency: Dictionary = {}
var starting: Dictionary = {}
var resources_meta: Dictionary = {}
var seasons: Dictionary = {}
var world_full: Dictionary = {}
var seas_meta: Dictionary = {}
var tech_tree: Dictionary = {}
var trade_prices: Dictionary = {}
var sea_balance: Dictionary = {}

const SYS_NAME := {
	"flame": "烈焰", "ironwall": "铁壁", "wind": "疾风", "tide": "潮汐"
}

func _ready() -> void:
	_load_all()

func _load_all() -> void:
	constants = _read_json("res://data/constants.json")
	var card_raw: Dictionary = _read_json("res://data/cards.json")
	card_list = card_raw.get("cards", [])
	for c in card_list:
		cards[c["id"]] = c
	var isl_raw: Dictionary = _read_json("res://data/islands.json")
	sea_theme = isl_raw.get("sea_theme", {})
	island_list = isl_raw.get("islands", [])
	islands.clear()
	for i in island_list:
		var isl: Dictionary = i.duplicate(true)
		isl["sea"] = isl.get("sea", "frozen")
		islands[isl["id"]] = isl
	var ship_raw: Dictionary = _read_json("res://data/ships.json")
	for s in ship_raw.get("ships", []):
		ships[s["id"]] = s
	guards = _read_json("res://data/guards.json").get("guards", {})
	adjacency = _read_json("res://data/adjacency.json")
	starting = _read_json("res://data/starting_deck.json")
	resources_meta = _read_json("res://data/resources.json")
	var season_raw: Dictionary = _read_json("res://data/seasons.json")
	seasons = season_raw.get("seasons", {})
	world_full = _read_json("res://data/world_full.json")
	seas_meta = world_full.get("seas", {})
	tech_tree = _read_json("res://data/tech_tree.json")
	trade_prices = _read_json("res://data/trade_prices.json")
	var bal: Dictionary = _read_json("res://data/seas/balance_final.json")
	sea_balance = bal.get("seas", {})
	print("[GameData] cards=%d islands=%d ships=%d world_full=%d tech=%d" % [
		cards.size(), islands.size(), ships.size(),
		int(world_full.get("_meta", {}).get("count", 0)),
		tech_tree.get("nodes", []).size() if tech_tree.has("nodes") else 0,
	])

func reload_world_filter(sea_ids: Array) -> void:
	## Demo：仅 frozen（保持 12 岛 JSON）；解锁海域时并入 world_full 其它海
	var base: Dictionary = _read_json("res://data/islands.json")
	island_list = []
	islands.clear()
	for i in base.get("islands", []):
		var isl: Dictionary = i.duplicate(true)
		isl["sea"] = "frozen"
		if "frozen" in sea_ids:
			island_list.append(isl)
			islands[isl["id"]] = isl
	adjacency = _read_json("res://data/adjacency.json")
	guards = _read_json("res://data/guards.json").get("guards", {})
	sea_theme = base.get("sea_theme", {})
	if world_full.is_empty():
		world_full = _read_json("res://data/world_full.json")
	var full_islands: Array = world_full.get("islands", [])
	var full_adj: Dictionary = world_full.get("adjacency", {})
	var full_guards: Dictionary = world_full.get("guards", {})
	for isl2 in full_islands:
		var sea := str(isl2.get("sea", ""))
		if sea == "frozen":
			continue  # Demo 冻洋以 12 岛为准
		if sea in sea_ids:
			var copy: Dictionary = isl2.duplicate(true)
			island_list.append(copy)
			islands[copy["id"]] = copy
			var iid := str(copy["id"])
			if full_adj.has(iid):
				adjacency[iid] = full_adj[iid]
			if full_guards.has(iid):
				guards[iid] = full_guards[iid]
	if sea_ids.size() > 0:
		var primary := str(sea_ids[0])
		if seas_meta.has(primary):
			sea_theme = {
				"name": seas_meta[primary].get("name", primary),
				"dominant_system": seas_meta[primary].get("system", "ironwall"),
				"env_bias": seas_meta[primary].get("env_bias", {}),
			}
	print("[GameData] world filter seas=%s islands=%d" % [str(sea_ids), islands.size()])

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing JSON: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Bad JSON: " + path)
		return {}
	return parsed

func restraint_coef(attacker_sys: String, target_sys: String) -> float:
	var ring: Dictionary = constants.get("RING", {})
	if ring.get(attacker_sys, "") == target_sys:
		return float(constants.get("RESTRAINT", 1.3))
	if ring.get(target_sys, "") == attacker_sys:
		return float(constants.get("RESTRAINT_DISADV", 1.0 / 1.3))
	return 1.0

func system_color(sys: String) -> Color:
	var hex: String = constants.get("SYSTEM_COLORS", {}).get(sys, "#FFFFFF")
	return Color.html(hex)

func rarity_cost(rarity: String) -> int:
	return int(constants.get("COST_BY_RARITY", {}).get(rarity, 1))

func env_mod_for(sys: String) -> float:
	var bias: Dictionary = sea_theme.get("env_bias", {}).get("season_mod", {})
	var m := float(bias.get(sys, 1.0))
	# 非冻洋终局表
	var sea := str(sea_theme.get("dominant_system", ""))
	# 若当前岛海域有 balance，优先生效
	var cur_sea := "frozen"
	if Engine.get_main_loop() != null:
		var gs = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
		if gs != null:
			cur_sea = str(islands.get(gs.current_island, {}).get("sea", "frozen"))
	if sea_balance.has(cur_sea):
		m = float(sea_balance[cur_sea].get("env_mod", {}).get(sys, m))
	# 科技体系加成在战斗门面另乘
	return m
