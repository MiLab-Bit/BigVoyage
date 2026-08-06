extends RefCounted
class_name TechService
## 科技树 T1–T4：耗战略资源；跨季继承；effect 汇总进战斗核 / 贸易

static func unlocked() -> Array:
	return GameState.tech_unlocked

static func can_unlock(node_id: String) -> Dictionary:
	var node: Dictionary = _node(node_id)
	if node.is_empty():
		return {"ok": false, "reason": "未知节点"}
	if GameState.tech_unlocked.has(node_id):
		return {"ok": false, "reason": "已研发"}
	for r in node.get("req", []):
		if not GameState.tech_unlocked.has(r):
			return {"ok": false, "reason": "前置未满足：%s" % r}
	if node_id == "T4_tide_core" and not GameState.owned_islands.has("FR_12") and not GameState.owned_islands.has("AB_09"):
		return {"ok": false, "reason": "需占领 Boss 岛（渊眼/海皇座）"}
	var cost := int(node.get("cost", 0))
	if GameState.strategic < cost:
		return {"ok": false, "reason": "战略资源不足（需 %d）" % cost}
	return {"ok": true, "cost": cost, "node": node}

static func unlock(node_id: String) -> Dictionary:
	var check: Dictionary = can_unlock(node_id)
	if not bool(check.get("ok", false)):
		return check
	var cost := int(check.get("cost", 0))
	GameState.strategic -= cost
	GameState.tech_unlocked.append(node_id)
	GameState.tutorial_flags["first_tech"] = true
	GameState.save_game()
	GameState.emit_signal("state_changed")
	GameState.emit_signal("toast", "科技研发完成：%s" % str(check.node.get("name", node_id)))
	return {"ok": true, "node": check.node}

static func trade_mult() -> float:
	var m := 1.0
	if GameState.tech_unlocked.has("T1_trade"):
		m *= float(_effect("T1_trade").get("trade_mult", 1.1))
	return m

static func alliance_bonus_cap() -> int:
	return int(_effect("T2_council").get("alliance_cap", 0)) if GameState.tech_unlocked.has("T2_council") else 0

## 旧接口：保留给兼容调用；战斗核请用 battle_mods()
static func battle_env_bonus(sys: String) -> float:
	var mods: Dictionary = battle_mods()
	match sys:
		"ironwall":
			return float(mods.get("ironwall_atk", 1.0))
		"wind":
			return float(mods.get("wind_seg", 1.0))
		"tide":
			return float(mods.get("tide_shield", 1.0))
		"flame":
			return float(mods.get("flame_dot", 1.0))
		_:
			return 1.0

## 汇总已解锁节点 effect → ResolveBattle env.tech_a
static func battle_mods() -> Dictionary:
	var m := {
		"def_mult": 1.0,
		"spd_bonus": 0,
		"flame_dot": 1.0,
		"ironwall_atk": 1.0,
		"control_dur": 1.0,
		"wind_seg": 1.0,
		"tide_shield": 1.0,
	}
	for nid in GameState.tech_unlocked:
		var eff: Dictionary = _effect(str(nid))
		if eff.is_empty():
			continue
		if eff.has("def_mult"):
			m.def_mult = float(m.def_mult) * float(eff.def_mult)
		if eff.has("spd_hint"):
			m.spd_bonus = int(m.spd_bonus) + int(eff.spd_hint)
		if eff.has("flame_dot"):
			m.flame_dot = float(m.flame_dot) * float(eff.flame_dot)
		if eff.has("ironwall_atk"):
			m.ironwall_atk = float(m.ironwall_atk) * float(eff.ironwall_atk)
		if eff.has("control_dur"):
			m.control_dur = float(m.control_dur) * float(eff.control_dur)
		if eff.has("wind_seg"):
			m.wind_seg = float(m.wind_seg) * float(eff.wind_seg)
		if eff.has("tide_shield"):
			m.tide_shield = float(m.tide_shield) * float(eff.tide_shield)
	return m

static func _effect(node_id: String) -> Dictionary:
	var node: Dictionary = _node(node_id)
	if node.is_empty():
		return {}
	var eff = node.get("effect", {})
	return eff if typeof(eff) == TYPE_DICTIONARY else {}

static func _node(id: String) -> Dictionary:
	for n in GameData.tech_tree.get("nodes", []):
		if str(n.get("id", "")) == id:
			return n
	return {}
