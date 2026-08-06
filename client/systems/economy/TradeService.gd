extends RefCounted
class_name TradeService
## 跨港贸易：价差 − 运费 − 风险；联盟税率；三角贸易 A→B→C（跨海终局）

const TechServiceScript := preload("res://systems/economy/TechService.gd")
const AllianceServiceScript := preload("res://systems/social/AllianceService.gd")

static func quote(from_id: String, to_id: String, good: String, units: int = 1) -> Dictionary:
	var tp: Dictionary = GameData.trade_prices
	var ports: Dictionary = tp.get("ports", {})
	if not ports.has(from_id) or not ports.has(to_id):
		return {"ok": false, "reason": "港口未开放贸易价"}
	if not GameState.owned_islands.has(from_id):
		return {"ok": false, "reason": "需拥有出发港"}
	var buy := float(ports[from_id].get(good, 0))
	var sell := float(ports[to_id].get(good, 0))
	if buy <= 0.0 or sell <= 0.0:
		return {"ok": false, "reason": "无此商品"}
	var hops := _hops(from_id, to_id)
	var freight := _freight(from_id, to_id, hops, units)
	var risk := _risk(from_id, to_id, units)
	var mult := _trade_mult(to_id)
	var endgame := _endgame_mult(to_id)
	mult *= endgame
	var gross := (sell - buy) * units * mult
	var pre_tax := gross - freight - risk
	var tax_rate := AllianceServiceScript.tax_rate()
	var tax := int(floor(maxi(0.0, pre_tax) * tax_rate))
	var net := int(floor(pre_tax)) - tax
	return {
		"ok": net > 0,
		"good": good,
		"units": units,
		"buy": buy,
		"sell": sell,
		"freight": freight,
		"risk": risk,
		"mult": mult,
		"endgame": endgame,
		"cross_sea": _sea_of(from_id) != _sea_of(to_id),
		"hops": hops,
		"tax": tax,
		"tax_rate": tax_rate,
		"net": net,
		"route": "%s→%s" % [from_id, to_id],
		"reason": "" if net > 0 else "价差不足以覆盖运费风险/税",
	}

## 三角贸易：A 购 good_ab → B 售；B 购 good_bc → C 售
## 门禁按「整段合计净利」判定（允许单段微亏、靠次段/终局加成回血）
static func quote_triangle(a: String, b: String, c: String, good_ab: String, good_bc: String, units: int = 1) -> Dictionary:
	if not GameState.owned_islands.has(a):
		return {"ok": false, "reason": "需拥有出发港", "net": 0}
	var q1: Dictionary = _quote_leg(a, b, good_ab, units, false)
	var q2: Dictionary = _quote_leg(b, c, good_bc, units, false)
	if str(q1.get("reason", "")) == "港口未开放" or str(q2.get("reason", "")) == "港口未开放":
		return {"ok": false, "reason": "港口未开放", "net": 0}
	if str(q1.get("reason", "")) == "无此商品" or str(q2.get("reason", "")) == "无此商品":
		return {"ok": false, "reason": "无此商品", "net": 0}
	var tax_rate := AllianceServiceScript.tax_rate()
	var raw := int(q1.get("net", 0)) + int(q2.get("net", 0))
	var seas: Dictionary = {}
	for pid in [a, b, c]:
		seas[_sea_of(pid)] = true
	var three_sea := seas.size() >= 3
	var bonus := 1.0
	if three_sea:
		bonus *= float(GameData.trade_prices.get("triangle_three_sea_bonus", 1.15))
	bonus *= _endgame_mult(c)
	# 同海三角小幅贴水，鼓励沿岸转运
	if seas.size() == 1:
		bonus *= 1.08
	raw = int(floor(float(raw) * bonus))
	var tax := int(floor(maxi(0, raw) * tax_rate))
	var net := raw - tax
	return {
		"ok": net > 0,
		"route": "%s→%s→%s" % [a, b, c],
		"goods": [good_ab, good_bc],
		"leg1": q1,
		"leg2": q2,
		"tax": tax,
		"tax_rate": tax_rate,
		"net": net,
		"three_sea": three_sea,
		"endgame": _endgame_mult(c) > 1.0,
		"bonus": bonus,
		"stamina": 4 if not three_sea else 5,
		"reason": "" if net > 0 else "三角航线净利不足",
	}

static func execute(from_id: String, to_id: String, good: String, units: int = 1) -> Dictionary:
	var q: Dictionary = quote(from_id, to_id, good, units)
	if not bool(q.get("ok", false)):
		return q
	if not GameState.spend_stamina(2):
		return {"ok": false, "reason": "体力不足（贸易航行 2）"}
	var net := int(q.get("net", 0))
	var tax := int(q.get("tax", 0))
	GameState.add_strategic(net, "贸易")
	if tax > 0:
		AllianceServiceScript.deposit_tax(tax)
	GameState.tutorial_flags["first_trade"] = true
	GameState.save_game()
	return {"ok": true, "net": net, "tax": tax, "quote": q}

static func execute_triangle(a: String, b: String, c: String, good_ab: String, good_bc: String, units: int = 1) -> Dictionary:
	var q: Dictionary = quote_triangle(a, b, c, good_ab, good_bc, units)
	if not bool(q.get("ok", false)):
		return q
	var stam := int(q.get("stamina", 4))
	if not GameState.spend_stamina(stam):
		return {"ok": false, "reason": "体力不足（三角贸易 %d）" % stam}
	var net := int(q.get("net", 0))
	var tax := int(q.get("tax", 0))
	GameState.add_strategic(net, "三角贸易")
	if tax > 0:
		AllianceServiceScript.deposit_tax(tax)
	GameState.current_island = c
	GameState.tutorial_flags["first_triangle"] = true
	if bool(q.get("three_sea", false)):
		GameState.tutorial_flags["triangle_cross_sea"] = true
	GameState.save_game()
	return {"ok": true, "net": net, "tax": tax, "quote": q}

static func _hops(from_id: String, to_id: String) -> int:
	if from_id == to_id:
		return 0
	if GameData.adjacency.has(from_id) and GameData.adjacency[from_id].has(to_id):
		return 1
	# 同海沿岸：统一按 1 跳计价（压测校准：非邻港贸易港仍有正利空间）
	if _sea_of(from_id) == _sea_of(to_id):
		return 1
	# 跨海：2 跳基线（再乘 cross_sea_*）
	return 2

static func _sea_of(island_id: String) -> String:
	return str(GameData.islands.get(island_id, {}).get("sea", "frozen"))

static func _freight(from_id: String, to_id: String, hops: int, units: int) -> float:
	var tp: Dictionary = GameData.trade_prices
	var sea_to := _sea_of(to_id)
	var per := float(tp.get("freight_by_sea", {}).get(sea_to, tp.get("freight_per_hop", 30)))
	var freight := per * float(hops) * float(units)
	if _sea_of(from_id) != sea_to:
		freight *= float(tp.get("cross_sea_freight_mult", 1.35))
	return freight

static func _risk(from_id: String, to_id: String, units: int) -> float:
	var tp: Dictionary = GameData.trade_prices
	var sea_to := _sea_of(to_id)
	var flat := float(tp.get("risk_by_sea", {}).get(sea_to, tp.get("risk_flat", 20)))
	var risk := flat * float(units)
	if _sea_of(from_id) != sea_to:
		risk *= float(tp.get("cross_sea_risk_mult", 1.45))
	# 信风季风等：LiveOps economy 可降风险（见 OpsDirector.trade_risk_mult）
	risk *= _ops_risk_mult(sea_to)
	return risk

static func _endgame_mult(to_id: String) -> float:
	var ends: Array = GameData.trade_prices.get("endgame_ports", [])
	if ends.has(to_id):
		return float(GameData.trade_prices.get("endgame_bonus", 1.22))
	return 1.0

static func _trade_mult(to_id: String) -> float:
	var mult := TechServiceScript.trade_mult()
	if str(GameData.islands.get(to_id, {}).get("sea", "")) == "tradewind":
		mult *= float(GameData.sea_balance.get("tradewind", {}).get("trade_mult", 1.2))
	if Engine.get_main_loop() != null:
		var ops = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("OpsDirector")
		if ops:
			var dest_sea := str(GameData.islands.get(to_id, {}).get("sea", ""))
			for e in ops.active_events():
				if str(e.get("kind", "")) != "economy":
					continue
				var sea_f := str(e.get("sea", ""))
				if sea_f != "" and sea_f != dest_sea:
					continue
				mult *= float(e.get("mult", 1.05))
	return mult

static func _ops_risk_mult(sea: String) -> float:
	if Engine.get_main_loop() == null:
		return 1.0
	var ops = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("OpsDirector")
	if ops == null or not ops.has_method("trade_risk_mult"):
		return 1.0
	return float(ops.trade_risk_mult(sea))

static func _quote_leg(from_id: String, to_id: String, good: String, units: int, require_own: bool) -> Dictionary:
	var tp: Dictionary = GameData.trade_prices
	var ports: Dictionary = tp.get("ports", {})
	if not ports.has(from_id) or not ports.has(to_id):
		return {"ok": false, "reason": "港口未开放", "net": 0, "tax": 0}
	if require_own and not GameState.owned_islands.has(from_id):
		return {"ok": false, "reason": "需拥有出发港", "net": 0, "tax": 0}
	var buy := float(ports[from_id].get(good, 0))
	var sell := float(ports[to_id].get(good, 0))
	if buy <= 0.0 or sell <= 0.0:
		return {"ok": false, "reason": "无此商品", "net": 0, "tax": 0}
	var hops := _hops(from_id, to_id)
	var freight := _freight(from_id, to_id, hops, units)
	var risk := _risk(from_id, to_id, units) * 0.85
	var mult := _trade_mult(to_id) * _endgame_mult(to_id)
	var pre := (sell - buy) * units * mult - freight - risk
	return {
		"ok": pre > 0.0,
		"net": int(floor(pre)),
		"tax": 0,
		"freight": freight,
		"risk": risk,
		"reason": "" if pre > 0.0 else "段亏损",
	}
