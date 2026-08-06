extends RefCounted
class_name FleetRules
## 编队合法性（COST / 槽位 / 同体系软顶）— 与 GameState.set_fleet 同口径

static func validate(fleet: Array, owned: Array = []) -> Dictionary:
	var C: Dictionary = _gd().constants
	var slots := int(C.get("FLEET_SLOTS", 5))
	var cap := int(C.get("FLEET_CAPACITY", 10))
	var soft := int(C.get("SAME_SYS_SOFT_CAP", 4))
	if fleet.size() > slots:
		return {"ok": false, "reason": "槽位不足（最多 %d）" % slots}
	var cost := 0
	var sys_count := {}
	for id in fleet:
		if owned.size() > 0 and not owned.has(id):
			return {"ok": false, "reason": "未拥有该卡"}
		if not _gd().cards.has(id):
			return {"ok": false, "reason": "未知卡 %s" % id}
		var c: Dictionary = _gd().cards[id]
		cost += int(_gd().rarity_cost(str(c["rarity"])))
		var sys := str(c["system"])
		sys_count[sys] = int(sys_count.get(sys, 0)) + 1
	if cost > cap:
		return {"ok": false, "reason": "COST 超限（>%d）" % cap, "cost": cost}
	for s in sys_count.keys():
		if int(sys_count[s]) > soft:
			return {"ok": false, "reason": "同体系不得超过 %d 张" % soft}
	return {"ok": true, "cost": cost, "sys_count": sys_count}

static func cost_of(fleet: Array) -> int:
	var n := 0
	for id in fleet:
		if _gd().cards.has(id):
			n += int(_gd().rarity_cost(str(_gd().cards[id]["rarity"])))
	return n

static func _gd() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
