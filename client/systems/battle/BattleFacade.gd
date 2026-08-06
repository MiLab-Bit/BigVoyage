extends RefCounted
class_name BattleFacade
## 战斗门面：组 env → ResolveBattle →（可选）链承诺
## UI 只应调用本门面，不直接拼结算细节

const ResolveBattleScript := preload("res://systems/battle/ResolveBattle.gd")
const TechServiceScript := preload("res://systems/economy/TechService.gd")

static func fight_guard(fleet: Array, island_id: String, ship_id: String, seed: int) -> Dictionary:
	var gd = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	var guard: Dictionary = gd.guards.get(island_id, {})
	var enemy: Array = guard.get("crew_ids", [])
	if enemy.is_empty():
		return {"winner": "A", "rounds": 0, "log": [], "hash": "", "empty_guard": true}
	var isl: Dictionary = gd.islands.get(island_id, {})
	var sea := str(isl.get("sea", "frozen"))
	var hp_mult := float(guard.get("hp_mult", 1.0))
	var bal: Dictionary = gd.sea_balance.get(sea, {})
	var tier := str(isl.get("tier", "light"))
	var is_boss := _is_boss_island(island_id, isl)
	if not bal.is_empty():
		hp_mult *= float(bal.get("guard_scale", {}).get(tier if not is_boss else "boss", 1.0))
		# 海域终核额外倍率（原先未接线）
		if is_boss and bal.has("boss_hp_mult"):
			hp_mult *= float(bal.get("boss_hp_mult", 1.0))
	# LiveOps：battle / boss / season 真改守卫血量
	hp_mult *= _ops_guard_mult(island_id, sea)
	var tech_a: Dictionary = TechServiceScript.battle_mods()
	var env := {
		"ship_a": ship_id,
		"ship_b": guard.get("ship_id", "SHIP_IRON"),
		"hp_mult_b": hp_mult,
		"tech_a": tech_a,
	}
	var result: Dictionary = ResolveBattleScript.resolve(fleet, enemy, env, seed)
	result["island_id"] = island_id
	result["env"] = env
	result["sea"] = sea
	result["boss"] = _is_boss_island(island_id, isl)
	return result

static func _is_boss_island(island_id: String, isl: Dictionary) -> bool:
	if str(isl.get("tier", "")) == "boss":
		return true
	return island_id in ["FR_12", "AB_09", "BL_09", "TW_09"]

static func _ops_guard_mult(island_id: String, sea: String) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var ops = tree.root.get_node_or_null("OpsDirector")
	if ops == null or not ops.has_method("guard_hp_mult"):
		return 1.0
	return float(ops.guard_hp_mult(island_id, sea))
