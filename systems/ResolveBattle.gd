extends RefCounted
class_name ResolveBattle
## 确定性纯函数战斗内核
## ResolveBattle.resolve(fleet_a, fleet_b, env, seed) -> {winner, log, hash}

const RING := {"flame": "ironwall", "ironwall": "wind", "wind": "tide", "tide": "flame"}

static func resolve(fleet_a: Array, fleet_b: Array, env: Dictionary, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var units_a := _spawn_side(fleet_a, "A", env)
	var units_b := _spawn_side(fleet_b, "B", env)
	var log: Array = []
	var dots: Dictionary = {} # unit_uid -> {dmg_per_tick, stacks, source_sys}
	var round_i := 0
	var max_round := int(GameData.constants.get("GUARD_MAX_ROUND", 30))

	log.append({"t": "start", "seed": seed, "a": units_a.size(), "b": units_b.size()})

	while round_i < max_round and _alive(units_a) and _alive(units_b):
		round_i += 1
		# DoT tick first
		for side in [units_b, units_a]:
			for u in side:
				if u.hp <= 0:
					continue
				if dots.has(u.uid):
					var d: Dictionary = dots[u.uid]
					var coef := _restraint(d.source_sys, u.sys)
					var dmg := int(round(float(d.dmg) * float(d.stacks) * coef))
					u.hp = max(0, u.hp - dmg)
					log.append({"t": "dot", "r": round_i, "target": u.uid, "dmg": dmg, "stacks": d.stacks, "restraint": coef})

		if not _alive(units_a) or not _alive(units_b):
			break

		var order: Array = []
		for u in units_a + units_b:
			if u.hp > 0:
				order.append(u)
		order.sort_custom(func(x, y): return x.spd > y.spd)

		for u in order:
			if u.hp <= 0:
				continue
			var enemies: Array = units_b if u.side == "A" else units_a
			if not _alive(enemies):
				break
			var target = _pick_target(enemies, u)
			if target == null:
				continue
			var hits := 1
			if u.sys == "wind":
				var seg := int(GameData.constants.get("WIND_BONUS_SEGMENT", 20))
				var extra := mini(int(GameData.constants.get("MAX_EXTRA_HIT", 2)), int(u.spd / seg) - 1)
				hits += max(0, extra)
			for h in hits:
				if target.hp <= 0:
					target = _pick_target(enemies, u)
					if target == null:
						break
				var result := _strike(u, target, env)
				log.append(result)
				if result.get("apply_dot", false):
					_apply_dot(dots, target.uid, u, result.get("dot_dmg", 0))
				if result.get("kill", false):
					log.append({"t": "kill", "r": round_i, "who": target.uid})

	var winner := "draw"
	var alive_a := _alive(units_a)
	var alive_b := _alive(units_b)
	if alive_a and not alive_b:
		winner = "A"
	elif alive_b and not alive_a:
		winner = "B"
	elif round_i >= max_round:
		var ha := _hp_sum(units_a)
		var hb := _hp_sum(units_b)
		winner = "A" if ha >= hb else "B"

	var payload := "%s|%d|%d" % [winner, seed, log.size()]
	var hash_s := payload.sha256_text().substr(0, 16)
	return {
		"winner": winner,
		"rounds": round_i,
		"log": log,
		"hash": hash_s,
		"units_a": units_a,
		"units_b": units_b,
	}

static func _spawn_side(fleet: Array, side: String, env: Dictionary) -> Array:
	var out: Array = []
	var ship_id: String = env.get("ship_" + side.to_lower(), env.get("ship_id", "SHIP_RAFT"))
	var ship: Dictionary = GameData.ships.get(ship_id, {"atkMod": 1.0, "defMod": 1.0, "armorType": "light"})
	var hp_mult: float = float(env.get("hp_mult_" + side.to_lower(), env.get("hp_mult", 1.0)))
	var i := 0
	for cid in fleet:
		if not GameData.cards.has(cid):
			continue
		var c: Dictionary = GameData.cards[cid]
		var u := {
			"uid": "%s%d_%s" % [side, i, cid],
			"id": cid,
			"name": c.get("name", cid),
			"side": side,
			"sys": c["system"],
			"atk": float(c["atk"]) * float(ship.get("atkMod", 1.0)),
			"def": float(c["def"]) * float(ship.get("defMod", 1.0)),
			"spd": float(c["spd"]),
			"hp": float(c["hp"]) * hp_mult,
			"max_hp": float(c["hp"]) * hp_mult,
			"armor_type": ship.get("armorType", "light"),
			"skill": c.get("skill", {}),
		}
		# env bias as atk mod for matching system
		u.atk *= GameData.env_mod_for(u.sys)
		out.append(u)
		i += 1
	return out

static func _alive(units: Array) -> bool:
	for u in units:
		if u.hp > 0:
			return true
	return false

static func _hp_sum(units: Array) -> float:
	var s := 0.0
	for u in units:
		if u.hp > 0:
			s += u.hp
	return s

static func _pick_target(enemies: Array, attacker: Dictionary):
	# Prefer units we restrain; else lowest def
	var best = null
	var best_score := -9999.0
	for e in enemies:
		if e.hp <= 0:
			continue
		var score := -e.def
		var coef := _restraint(attacker.sys, e.sys)
		if coef > 1.0:
			score += 1000.0
		elif coef < 1.0:
			score -= 200.0
		if score > best_score:
			best_score = score
			best = e
	return best

static func _restraint(a: String, t: String) -> float:
	if RING.get(a, "") == t:
		return float(GameData.constants.get("RESTRAINT", 1.3))
	if RING.get(t, "") == a:
		return float(GameData.constants.get("RESTRAINT_DISADV", 1.0 / 1.3))
	return 1.0

static func _type_coef(dmg_type: String, armor: String) -> float:
	var table: Dictionary = GameData.constants.get("TYPE_COEF", {})
	return float(table.get(dmg_type, {}).get(armor, 1.0))

static func _dmg_type_for(sys: String) -> String:
	match sys:
		"flame":
			return "burn"
		"tide":
			return "energy"
		_:
			return "physical"

static func _strike(attacker: Dictionary, target: Dictionary, env: Dictionary) -> Dictionary:
	var coef := _restraint(attacker.sys, target.sys)
	var dmg_type := _dmg_type_for(attacker.sys)
	var tcoef := _type_coef(dmg_type, target.armor_type)
	# ironwall env: defenders get effective armor bump when ironwall sea
	var armor_ratio := target.def / (target.def + 100.0)
	if target.sys == "ironwall":
		armor_ratio = min(0.9, armor_ratio + 0.08)
	var raw := attacker.atk * coef * tcoef * (1.0 - armor_ratio)
	var dmg := max(1, int(round(raw)))
	target.hp = max(0, target.hp - dmg)
	var apply_dot := false
	var dot_dmg := 0
	var sk: Dictionary = attacker.get("skill", {})
	if str(sk.get("type", "")) == "dot" or attacker.sys == "flame":
		apply_dot = true
		dot_dmg = int(round(attacker.atk * 0.18))
	return {
		"t": "hit",
		"attacker": attacker.uid,
		"target": target.uid,
		"dmg": dmg,
		"restraint": coef,
		"kill": target.hp <= 0,
		"apply_dot": apply_dot,
		"dot_dmg": dot_dmg,
		"name_a": attacker.name,
		"name_t": target.name,
		"sys_a": attacker.sys,
	}

static func _apply_dot(dots: Dictionary, uid: String, source: Dictionary, base_dot: int) -> void:
	var max_stack := int(GameData.constants.get("MAX_DOT_STACK", 5))
	if not dots.has(uid):
		dots[uid] = {"dmg": base_dot, "stacks": 1, "source_sys": source.sys}
	else:
		dots[uid].stacks = mini(max_stack, int(dots[uid].stacks) + 1)
		dots[uid].dmg = max(int(dots[uid].dmg), base_dot)
		dots[uid].source_sys = source.sys
