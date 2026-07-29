extends Node
## 玩家进度 / 日循环 / 存档

signal state_changed
signal day_advanced(day: int)
signal toast(msg: String)
signal island_captured(island_id: String)
signal resources_gained(amount: int, reason: String)

var day: int = 1
var stamina: int = 120
var strategic: int = 800
var tide: int = 0
var player_name: String = "θ"
var ship_id: String = "SHIP_RAFT"
var owned_cards: Array = [] # card ids
var fleet: Array = [] # up to 5 card ids in slots
var owned_islands: Array = [] # island ids
var revealed: Array = ["FR_01"]
var current_island: String = "FR_01"
var island_yield_bank: Dictionary = {} # id -> accumulated
var battle_seed: int = 20260729
var tutorial_flags: Dictionary = {}

const SAVE_PATH := "user://voyage_save.json"

func _ready() -> void:
	if not load_game():
		new_game()

func new_game() -> void:
	day = 1
	stamina = int(GameData.constants.get("STAMINA_MAX", 120))
	strategic = 800
	tide = 0
	ship_id = GameData.starting.get("ship_id", "SHIP_RAFT")
	owned_cards = GameData.starting.get("owned_cards", []).duplicate()
	fleet = GameData.starting.get("crew_ids", []).duplicate()
	owned_islands = ["FR_01"]
	revealed = ["FR_01"]
	for n in GameData.adjacency.get("FR_01", []):
		if not revealed.has(n):
			revealed.append(n)
	current_island = "FR_01"
	island_yield_bank.clear()
	for id in owned_islands:
		island_yield_bank[id] = 0
	tutorial_flags = {"first_poi": false, "first_battle": false, "restraint_tip": false}
	battle_seed = randi()
	emit_signal("toast", "启航。洋流会挑选它的孩子。")
	emit_signal("state_changed")
	save_game()

func save_game() -> void:
	var data := {
		"day": day,
		"stamina": stamina,
		"strategic": strategic,
		"tide": tide,
		"ship_id": ship_id,
		"owned_cards": owned_cards,
		"fleet": fleet,
		"owned_islands": owned_islands,
		"revealed": revealed,
		"current_island": current_island,
		"island_yield_bank": island_yield_bank,
		"battle_seed": battle_seed,
		"tutorial_flags": tutorial_flags,
		"player_name": player_name,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	day = int(data.get("day", 1))
	stamina = int(data.get("stamina", 120))
	strategic = int(data.get("strategic", 0))
	tide = int(data.get("tide", 0))
	ship_id = str(data.get("ship_id", "SHIP_RAFT"))
	owned_cards = data.get("owned_cards", [])
	fleet = data.get("fleet", [])
	owned_islands = data.get("owned_islands", ["FR_01"])
	revealed = data.get("revealed", ["FR_01"])
	current_island = str(data.get("current_island", "FR_01"))
	island_yield_bank = data.get("island_yield_bank", {})
	battle_seed = int(data.get("battle_seed", 1))
	tutorial_flags = data.get("tutorial_flags", {})
	player_name = str(data.get("player_name", "θ"))
	emit_signal("state_changed")
	return true

func fleet_cost() -> int:
	var cost := 0
	for id in fleet:
		if GameData.cards.has(id):
			cost += GameData.rarity_cost(GameData.cards[id]["rarity"])
	return cost

func same_sys_count(sys: String) -> int:
	var n := 0
	for id in fleet:
		if GameData.cards.has(id) and GameData.cards[id]["system"] == sys:
			n += 1
	return n

func can_sail_to(island_id: String) -> bool:
	if island_id == current_island:
		return true
	var neighbors: Array = GameData.adjacency.get(current_island, [])
	return neighbors.has(island_id)

func reveal_island(island_id: String) -> void:
	if not revealed.has(island_id):
		revealed.append(island_id)
		emit_signal("state_changed")

func spend_stamina(n: int) -> bool:
	if stamina < n:
		emit_signal("toast", "体力不足。空格键可推进一日。")
		Juice.deny_pulse()
		return false
	stamina -= n
	emit_signal("state_changed")
	return true

func add_strategic(n: int, reason: String = "") -> void:
	strategic += n
	emit_signal("resources_gained", n, reason)
	emit_signal("state_changed")

func gain_card(card_id: String) -> void:
	if not owned_cards.has(card_id):
		owned_cards.append(card_id)
		var nm = GameData.cards.get(card_id, {}).get("name", card_id)
		emit_signal("toast", "获得船员：「%s」" % nm)
		Juice.celebrate()
	else:
		emit_signal("toast", "重复卡化为碎片（Demo：+80 战略资源）")
		add_strategic(80, "dupe")
	emit_signal("state_changed")

func capture_island(island_id: String) -> void:
	if not owned_islands.has(island_id):
		owned_islands.append(island_id)
		island_yield_bank[island_id] = 0
		emit_signal("island_captured", island_id)
		var nm = GameData.islands.get(island_id, {}).get("name", island_id)
		emit_signal("toast", "占领「%s」！护岛者开始产出。" % nm)
		Juice.celebrate()
	current_island = island_id
	reveal_island(island_id)
	save_game()
	emit_signal("state_changed")

func advance_day(n: int = 1) -> void:
	var total := 0
	var yield_amt := int(GameData.constants.get("ISLAND_DAILY_YIELD", 120))
	for _i in n:
		day += 1
		# 正式口径：每日刷新清空未用完体力
		stamina = int(GameData.constants.get("STAMINA_MAX", 120))
		for id in owned_islands:
			var y := int(yield_amt * 0.5) if id == "FR_01" else yield_amt
			total += y
			island_yield_bank[id] = int(island_yield_bank.get(id, 0)) + y
	if total > 0:
		add_strategic(total, "护岛产出")
	emit_signal("day_advanced", day)
	save_game()
	emit_signal("state_changed")
	if n <= 1:
		emit_signal("toast", "第 %d 日 · 体力已刷新" % day)
	else:
		emit_signal("toast", "推进 %d 日 → 第 %d 日 · 护岛 +%d" % [n, day, total])

func set_fleet(new_fleet: Array) -> bool:
	if new_fleet.size() > int(GameData.constants.get("FLEET_SLOTS", 5)):
		emit_signal("toast", "槽位不足（最多 5）")
		return false
	var cost := 0
	var sys_count := {}
	for id in new_fleet:
		if not owned_cards.has(id):
			emit_signal("toast", "未拥有该卡")
			return false
		var c: Dictionary = GameData.cards[id]
		cost += GameData.rarity_cost(c["rarity"])
		sys_count[c["system"]] = int(sys_count.get(c["system"], 0)) + 1
	if cost > int(GameData.constants.get("FLEET_CAPACITY", 10)):
		emit_signal("toast", "COST 超限（>%d）" % int(GameData.constants.get("FLEET_CAPACITY", 10)))
		Juice.deny_pulse()
		return false
	var soft := int(GameData.constants.get("SAME_SYS_SOFT_CAP", 4))
	for s in sys_count.keys():
		if int(sys_count[s]) > soft:
			emit_signal("toast", "同体系不得超过 %d 张" % soft)
			Juice.deny_pulse()
			return false
	fleet = new_fleet.duplicate()
	save_game()
	emit_signal("state_changed")
	return true
