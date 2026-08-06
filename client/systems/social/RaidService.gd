extends RefCounted
class_name RaidService
## GVG：赛季联航战 — 邻岛突袭、敌联 AI、战绩榜（本机完整对抗）

const BattleFacadeScript := preload("res://systems/battle/BattleFacade.gd")
const AllianceServiceScript := preload("res://systems/social/AllianceService.gd")
const StaminaCostsScript := preload("res://systems/economy/StaminaCosts.gd")

static func targets_from(current: String) -> Array:
	var out: Array = []
	var adj: Array = GameData.adjacency.get(current, [])
	for id in adj:
		if GameState.owned_islands.has(id):
			continue
		var isl: Dictionary = GameData.islands.get(id, {})
		if int(isl.get("guard_hp", 0)) <= 0:
			continue
		out.append(str(id))
	# 联航战高潮期：可额外锁定同海非邻 Boss/重镇（仍不可占岛）
	if AllianceServiceScript.war_phase() == "peak":
		var my_sea := str(GameData.islands.get(current, {}).get("sea", ""))
		for isl2 in GameData.island_list:
			var iid := str(isl2.get("id", ""))
			if out.has(iid) or GameState.owned_islands.has(iid):
				continue
			if str(isl2.get("sea", "")) != my_sea:
				continue
			var tier := str(isl2.get("tier", ""))
			if tier == "boss" or iid.ends_with("09") or iid == "FR_12":
				if int(isl2.get("guard_hp", 0)) > 0:
					out.append(iid)
	return out

static func can_raid(island_id: String) -> Dictionary:
	if str(GameState.alliance.get("id", "")) == "":
		return {"ok": false, "reason": "需先加入联盟才能发起 GVG"}
	if island_id == GameState.current_island:
		return {"ok": false, "reason": "不能突袭当前港"}
	if GameState.owned_islands.has(island_id):
		return {"ok": false, "reason": "已占领"}
	var adj_list: Array = GameData.adjacency.get(GameState.current_island, [])
	var adj_ok: bool = adj_list.has(island_id)
	if not adj_ok and AllianceServiceScript.war_phase() != "peak":
		return {"ok": false, "reason": "仅可突袭相邻据点（联航高潮期可扩至同海终核）"}
	if not adj_ok and AllianceServiceScript.war_phase() == "peak":
		var my_sea := str(GameData.islands.get(GameState.current_island, {}).get("sea", ""))
		var their_sea := str(GameData.islands.get(island_id, {}).get("sea", ""))
		if my_sea != their_sea:
			return {"ok": false, "reason": "跨海突袭未开放"}
	if GameState.fleet.is_empty():
		return {"ok": false, "reason": "请先编队"}
	var cost := StaminaCostsScript.raid()
	if AllianceServiceScript.war_phase() == "peak":
		cost = maxi(4, cost - 1)
	if GameState.stamina < cost:
		return {"ok": false, "reason": "体力不足（突袭 %d）" % cost}
	return {"ok": true, "stamina": cost}

static func raid(island_id: String) -> Dictionary:
	var gate: Dictionary = can_raid(island_id)
	if not bool(gate.get("ok", false)):
		return gate
	if not GameState.spend_stamina(int(gate.get("stamina", 8))):
		return {"ok": false, "reason": "体力不足"}
	var seed := GameState.battle_seed + GameState.day * 31 + island_id.hash() + 777
	var result: Dictionary = BattleFacadeScript.fight_guard(
		GameState.fleet, island_id, GameState.ship_id, seed
	)
	result["gvg"] = true
	var won := str(result.get("winner", "")) == "A"
	var loot := 0
	var war_pts := 0
	if won:
		loot = _loot_for(island_id)
		GameState.add_strategic(loot, "GVG 战利品")
		war_pts = AllianceServiceScript.record_gvg_win(loot, island_id)
		GameState.tutorial_flags["first_gvg"] = true
	else:
		AllianceServiceScript.record_gvg_loss()
	GameState.save_game()
	return {
		"ok": true,
		"won": won,
		"loot": loot,
		"war_pts": war_pts,
		"battle": result,
		"island_id": island_id,
		"war": AllianceServiceScript.season_war_snapshot(),
	}

static func _loot_for(island_id: String) -> int:
	var base := 180 + GameState.day * 2
	var isl: Dictionary = GameData.islands.get(island_id, {})
	if str(isl.get("tier", "")) == "boss" or island_id in ["FR_12", "AB_09", "BL_09", "TW_09"]:
		base = int(base * 1.6)
	var phase := AllianceServiceScript.war_phase()
	match phase:
		"warmup":
			base = int(base * 1.0)
		"contend":
			base = int(base * 1.25)
		"peak":
			base = int(base * 1.45)
		_:
			pass
	base = int(float(base) * _ops_loot_mult())
	return base

static func _ops_loot_mult() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var ops = tree.root.get_node_or_null("OpsDirector")
	if ops == null or not ops.has_method("gvg_loot_mult"):
		return 1.0
	return float(ops.gvg_loot_mult())
