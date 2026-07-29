extends Node
## 单一真源：加载 data/*.json

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
	for i in island_list:
		islands[i["id"]] = i
	var ship_raw: Dictionary = _read_json("res://data/ships.json")
	for s in ship_raw.get("ships", []):
		ships[s["id"]] = s
	guards = _read_json("res://data/guards.json").get("guards", {})
	adjacency = _read_json("res://data/adjacency.json")
	starting = _read_json("res://data/starting_deck.json")
	resources_meta = _read_json("res://data/resources.json")
	print("[GameData] cards=%d islands=%d ships=%d" % [cards.size(), islands.size(), ships.size()])

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
	return float(bias.get(sys, 1.0))
