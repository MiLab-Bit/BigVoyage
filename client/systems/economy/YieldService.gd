extends RefCounted
class_name YieldService
## 护岛日产（D5）— 与 GameState.advance_day 同口径的可复用计算

static func daily_total(owned_islands: Array) -> Dictionary:
	var gd = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	var yield_amt := int(gd.constants.get("ISLAND_DAILY_YIELD", 120))
	var per: Dictionary = {}
	var total := 0
	for id in owned_islands:
		var y := int(yield_amt * 0.5) if str(id) == "FR_01" else yield_amt
		per[str(id)] = y
		total += y
	return {"total": total, "per_island": per}
