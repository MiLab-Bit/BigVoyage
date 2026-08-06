extends RefCounted
class_name ResolveBattle
## 确定性纯函数战斗内核（定点 · BLK-1）
## ResolveBattle.resolve(fleet_a, fleet_b, env, seed) -> {winner, log, hash}
## 对齐：bv_engine.R(seg_mode=geo) + RULESET_LOCK（DEF_COEF/SEG_DECAY/ARMOR_CAP）
## 舍入：FixedMath.round_div；克制劣势用 SCALE/RESTRAINT 除法（禁止预存 1/1.3）

const FixedMath := preload("res://core/FixedMath.gd")

const RING := {"flame": "ironwall", "ironwall": "wind", "wind": "tide", "tide": "flame"}

## 卡面基础段数（GDD-03 §6.3 / bv_engine.BASE_HITS）
const BASE_HITS := {
	"WIND_R_01": 1, "WIND_R_02": 2, "WIND_SR_01": 2, "WIND_SSR_01": 3, "WIND_UR_01": 4,
}

## DoT 系数定点（×SCALE）
const DOT_RATE_FP := {
	"FLAME_R_01": 1500, "FLAME_R_02": 1000, "FLAME_SSR_01": 2500, "FLAME_UR_01": 3000,
}

const CTRL_BASE := {
	"TIDE_R_02": 1500, "TIDE_SR_01": 1000, "TIDE_SSR_01": 3000,
}

## BLK-5 半步：不依赖 autoload 编译期全局名（兼容 --script / -s）
static func _gd() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameData")

static func _elock() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("EngineLock")

static func resolve(fleet_a: Array, fleet_b: Array, env: Dictionary, seed: int) -> Dictionary:
	var C: Dictionary = _gd().constants
	var seg_fp := FixedMath.from_float(float(C.get("SEG_DECAY", 0.40)))
	var armor_cap_fp := FixedMath.from_float(float(C.get("ARMOR_CAP", 0.80)))
	var def_coef_fp := FixedMath.from_float(float(C.get("DEF_COEF", 0.30)))
	var wind_seg := int(C.get("WIND_BONUS_SEGMENT", 20))
	var max_extra := int(C.get("MAX_EXTRA_HIT", 2))
	var max_dot := int(C.get("MAX_DOT_STACK", 5))
	var max_stun := int(C.get("MAX_STUN_ROUND", 3))
	var max_round := int(C.get("GUARD_MAX_ROUND", 30))
	var ironflat_fp := 800  # 0.08
	# 科技树 effect（经 BattleFacade 写入 env.tech_a）
	var tech_a: Dictionary = env.get("tech_a", {})
	var wind_seg_mult := float(tech_a.get("wind_seg", 1.0))
	if wind_seg_mult > 0.0:
		wind_seg = maxi(1, int(round(float(wind_seg) / wind_seg_mult)))
	var control_dur_a := float(tech_a.get("control_dur", 1.0))
	var flame_dot_a := float(tech_a.get("flame_dot", 1.0))

	var rng_state := _seed_init(seed)
	var units_a := _spawn_side(fleet_a, "A", env)
	var units_b := _spawn_side(fleet_b, "B", env)
	var log: Array = []
	var dots: Dictionary = {}  # uid -> {dmg, stacks, source_sys}
	var stun: Dictionary = {}
	var sil: Dictionary = {}
	var stun_tot: Dictionary = {}
	var round_i := 0

	log.append({
		"t": "start", "seed": seed, "a": units_a.size(), "b": units_b.size(),
		"fixed": true, "scale": FixedMath.SCALE,
	})

	while round_i < max_round and _alive(units_a) and _alive(units_b):
		round_i += 1
		# DoT tick
		for side in [units_b, units_a]:
			for u in side:
				if int(u.hp) <= 0:
					continue
				if dots.has(u.uid):
					var d: Dictionary = dots[u.uid]
					var coef_mode := _restraint_mode(str(d.source_sys), str(u.sys))
					var base_dot := int(d.dmg) * int(d.stacks)
					var dmg := _apply_restraint(base_dot, coef_mode)
					u.hp = maxi(0, int(u.hp) - dmg)
					log.append({
						"t": "dot", "r": round_i, "target": u.uid, "dmg": dmg,
						"stacks": int(d.stacks), "restraint": _coef_label(coef_mode),
						"sfx": "sfx_btl_dot_%s" % str(d.source_sys),
					})

		if not _alive(units_a) or not _alive(units_b):
			break

		var order: Array = []
		for u in units_a + units_b:
			if int(u.hp) > 0:
				order.append(u)
		# BLK-4：spd 降序，uid 升序稳定打破平局
		order.sort_custom(func(x, y):
			if int(x.spd) != int(y.spd):
				return int(x.spd) > int(y.spd)
			return str(x.uid) < str(y.uid)
		)

		for u in order:
			if int(u.hp) <= 0:
				continue
			var uid: String = str(u.uid)
			if int(stun.get(uid, 0)) > 0:
				stun[uid] = int(stun[uid]) - 1
				log.append({"t": "stun_skip", "r": round_i, "who": uid})
				continue
			var enemies: Array = units_b if u.side == "A" else units_a
			var allies: Array = units_a if u.side == "A" else units_b
			if not _alive(enemies):
				break
			var target = _pick_target(enemies, u)
			if target == null:
				continue

			# control attempt（确定性 LCG，与 bv_engine.nr 同源）
			var sk_type := str(u.get("skill", {}).get("type", ""))
			if sk_type == "control" and int(sil.get(uid, 0)) <= 0:
				var base_p := int(CTRL_BASE.get(str(u.id), 0))
				if base_p > 0:
					var p := base_p + int(u.get("cb_fp", 0))
					var roll := _nr(rng_state, round_i * 7 + enemies.size())
					rng_state = roll.state
					var tuid: String = str(target.uid)
					if roll.v < p and int(stun_tot.get(tuid, 0)) < max_stun:
						var du := 2 if str(u.id) == "TIDE_SSR_01" else 1
						if _side_has(allies, "TIDE_SR_01"):
							du += 1
						if str(u.side) == "A" and control_dur_a > 1.0:
							du = maxi(1, int(ceil(float(du) * control_dur_a)))
						var ad := mini(du, max_stun - int(stun_tot.get(tuid, 0)))
						if str(u.id) == "TIDE_SSR_01":
							sil[tuid] = ad
						else:
							stun[tuid] = ad
						stun_tot[tuid] = int(stun_tot.get(tuid, 0)) + ad
						log.append({
							"t": "control", "r": round_i, "attacker": uid, "target": tuid,
							"kind": "silence" if str(u.id) == "TIDE_SSR_01" else "stun",
							"dur": ad, "sfx": "sfx_btl_control_tide",
						})

			var hits := 1
			if str(u.sys) == "wind":
				hits = int(BASE_HITS.get(str(u.id), 1))
				var extra := maxi(0, mini(max_extra, int((int(u.spd) - 70) / wind_seg)))
				hits += extra

			for hi in range(hits):
				if int(target.hp) <= 0:
					target = _pick_target(enemies, u)
					if target == null:
						break
				var result := _strike(u, target, enemies, hi, seg_fp, armor_cap_fp, def_coef_fp, ironflat_fp, max_dot, dots, flame_dot_a)
				result["r"] = round_i
				log.append(result)
				if result.get("kill", false):
					log.append({"t": "kill", "r": round_i, "who": target.uid, "sfx": "sfx_btl_kill"})

			if int(sil.get(uid, 0)) > 0:
				sil[uid] = int(sil[uid]) - 1

	var winner := "draw"
	var alive_a := _alive(units_a)
	var alive_b := _alive(units_b)
	if alive_a and not alive_b:
		winner = "A"
	elif alive_b and not alive_a:
		winner = "B"
	elif round_i >= max_round:
		winner = "A" if _hp_sum(units_a) >= _hp_sum(units_b) else "B"

	var fleet_a_ids: Array = []
	var fleet_b_ids: Array = []
	for u in units_a:
		fleet_a_ids.append(str(u.get("id", "")))
	for u in units_b:
		fleet_b_ids.append(str(u.get("id", "")))
	var log_payload := JSON.stringify(log)
	var log_root := log_payload.sha256_text()
	var ruleset_h := str(_elock().RULESET_HASH_DESIGN)
	var env_h := JSON.stringify(env).sha256_text()
	var payload := "|".join([
		ruleset_h,
		"|".join(fleet_a_ids),
		"|".join(fleet_b_ids),
		env_h,
		str(seed),
		str(winner),
		str(round_i),
		log_root,
	])
	var hash_s := payload.sha256_text()
	return {
		"winner": winner,
		"rounds": round_i,
		"log": log,
		"hash": hash_s,
		"log_root": log_root,
		"ruleset_hash": ruleset_h,
		"units_a": units_a,
		"units_b": units_b,
		"fixed_point": true,
		"scale": FixedMath.SCALE,
	}

static func _seed_init(seed: int) -> int:
	# 与 bv_engine 兼容的 LCG 初值；seed 混入避免全场同流
	return (12345 + seed * 2654435761) % 2147483648

static func _nr(state: int, k: int) -> Dictionary:
	var s := (state * 1103515245 + 12345 + k) % 2147483648
	# 返回 [0, SCALE) 的定点「概率」
	var v := int(s * FixedMath.SCALE / 2147483648)
	return {"state": s, "v": v}

static func _spawn_side(fleet: Array, side: String, env: Dictionary) -> Array:
	var out: Array = []
	var ship_id: String = env.get("ship_" + side.to_lower(), env.get("ship_id", "SHIP_RAFT"))
	var gd := _gd()
	var ship: Dictionary = gd.ships.get(ship_id, {"atkMod": 1.0, "defMod": 1.0, "armorType": "light"})
	var hp_mult_fp := FixedMath.from_float(float(env.get("hp_mult_" + side.to_lower(), env.get("hp_mult", 1.0))))
	var gm_fp := FixedMath.from_float(float(env.get("gm_" + side.to_lower(), 1.0)))
	var atk_mod_fp := FixedMath.from_float(float(ship.get("atkMod", 1.0)))
	var def_mod_fp := FixedMath.from_float(float(ship.get("defMod", 1.0)))
	var tech: Dictionary = env.get("tech_a", {}) if side == "A" else {}
	var def_mult_fp := FixedMath.from_float(float(tech.get("def_mult", 1.0)))
	var ironwall_atk_fp := FixedMath.from_float(float(tech.get("ironwall_atk", 1.0)))
	var tide_shield := float(tech.get("tide_shield", 1.0))
	var spd_bonus := int(tech.get("spd_bonus", 0))
	var i := 0
	for cid in fleet:
		if not gd.cards.has(cid):
			continue
		var c: Dictionary = gd.cards[cid]
		var env_fp := FixedMath.from_float(gd.env_mod_for(str(c["system"])))
		var atk := FixedMath.mul_unit(int(c["atk"]), FixedMath.mul_fp(atk_mod_fp, FixedMath.mul_fp(env_fp, gm_fp)))
		if side == "A" and str(c["system"]) == "ironwall" and ironwall_atk_fp != FixedMath.SCALE:
			atk = FixedMath.mul_unit(atk, ironwall_atk_fp)
		var defense := FixedMath.mul_unit(int(c["def"]), def_mod_fp)
		if side == "A" and def_mult_fp != FixedMath.SCALE:
			defense = FixedMath.mul_unit(defense, def_mult_fp)
		var hp := FixedMath.mul_unit(int(c["hp"]), FixedMath.mul_fp(hp_mult_fp, gm_fp))
		var u := {
			"uid": "%s%d_%s" % [side, i, cid],
			"id": cid,
			"name": c.get("name", cid),
			"side": side,
			"sys": c["system"],
			"atk": atk,
			"def": defense,
			"spd": int(c["spd"]) + (spd_bonus if side == "A" else 0),
			"hp": hp,
			"max_hp": hp,
			"armor_type": ship.get("armorType", "light"),
			"skill": c.get("skill", {}),
			"ab_fp": 0,
			"pr_fp": 0,
			"sh": 0,
			"cb_fp": 0,
		}
		out.append(u)
		i += 1
	_apply_passives(out, shield_mult_fp_default())
	if side == "A" and tide_shield > 0.0 and not is_equal_approx(tide_shield, 1.0):
		var sh_fp := FixedMath.from_float(tide_shield)
		for u2 in out:
			u2.sh = FixedMath.mul_unit(int(u2.sh), sh_fp)
	return out

static func shield_mult_fp_default() -> int:
	return FixedMath.from_float(float(_gd().constants.get("MAX_SHIELD_MULT", 2.0)))

static func _apply_passives(side: Array, shield_mult_fp: int) -> void:
	if side.is_empty():
		return
	# FLAME_SR_01：烈焰友军 atk ×1.15
	if _side_has(side, "FLAME_SR_01"):
		for u in side:
			if str(u.sys) == "flame":
				u.atk = FixedMath.mul_unit(int(u.atk), 11500)
	# IRON armor aura
	var bo_fp := 0
	if _side_has(side, "IRON_SR_01"):
		bo_fp += 1500
	if _side_has(side, "IRON_UR_01"):
		bo_fp += 2500
	for u in side:
		u.ab_fp = bo_fp + (3000 if str(u.id) == "IRON_R_01" else 0)
		u.pr_fp = 2500 if str(u.id) == "IRON_SSR_01" else 0
		if str(u.id) == "WIND_SR_01":
			u.spd = int(u.spd) + 15
	if _side_has(side, "IRON_R_02"):
		for u in side:
			u.def = FixedMath.mul_unit(int(u.def), 11000)
	# tide control bias + shields
	var cb_fp := 0
	if _side_has(side, "TIDE_SR_01"):
		cb_fp += 1000
	if _side_has(side, "TIDE_UR_01"):
		cb_fp += 1500
	for u in side:
		u.cb_fp = cb_fp
	if _side_has(side, "TIDE_R_01"):
		var s = _side_first(side, "TIDE_R_01")
		var t = _lowest_hp(side)
		if s != null and t != null:
			var cap := FixedMath.mul_unit(int(t.max_hp), shield_mult_fp)
			var add := mini(FixedMath.mul_unit(int(s.atk), 5000), cap)
			t.sh = int(t.sh) + add
	if _side_has(side, "TIDE_UR_01"):
		var s2 = _side_first(side, "TIDE_UR_01")
		if s2 != null:
			for u in side:
				var cap2 := FixedMath.mul_unit(int(u.max_hp), shield_mult_fp)
				var add2 := mini(FixedMath.mul_unit(int(s2.atk), 6000), cap2)
				u.sh = int(u.sh) + add2

static func _side_has(side: Array, cid: String) -> bool:
	for u in side:
		if str(u.id) == cid:
			return true
	return false

static func _side_first(side: Array, cid: String):
	for u in side:
		if str(u.id) == cid:
			return u
	return null

static func _lowest_hp(side: Array):
	var best = null
	var best_hp := 1 << 30
	for u in side:
		if int(u.hp) < best_hp:
			best_hp = int(u.hp)
			best = u
	return best

static func _alive(units: Array) -> bool:
	for u in units:
		if int(u.hp) > 0:
			return true
	return false

static func _hp_sum(units: Array) -> int:
	var s := 0
	for u in units:
		if int(u.hp) > 0:
			s += int(u.hp)
	return s

static func _pick_target(enemies: Array, attacker: Dictionary):
	var best = null
	var best_score := -999999
	for e in enemies:
		if int(e.hp) <= 0:
			continue
		var score := -int(e.def)
		var mode := _restraint_mode(str(attacker.sys), str(e.sys))
		if mode > 0:
			score += 1000
		elif mode < 0:
			score -= 200
		if score > best_score:
			best_score = score
			best = e
		elif score == best_score and best != null and str(e.uid) < str(best.uid):
			best = e
	return best

static func _restraint_mode(a: String, t: String) -> int:
	if RING.get(a, "") == t:
		return 1
	if RING.get(t, "") == a:
		return -1
	return 0

static func _coef_label(mode: int) -> float:
	if mode > 0:
		return 1.3
	if mode < 0:
		return 1.0 / 1.3
	return 1.0

static func _apply_restraint(raw: int, mode: int) -> int:
	if mode > 0:
		return FixedMath.apply_restraint_adv(raw)
	if mode < 0:
		return FixedMath.apply_restraint_disadv(raw)
	return raw

static func _type_coef_fp(dmg_type: String, armor: String) -> int:
	var table: Dictionary = _gd().constants.get("TYPE_COEF", {})
	return FixedMath.from_float(float(table.get(dmg_type, {}).get(armor, 1.0)))

static func _dmg_type_for(sys: String) -> String:
	match sys:
		"flame":
			return "burn"
		"tide":
			return "energy"
		_:
			return "physical"

static func _strike(
	attacker: Dictionary, target: Dictionary, enemies: Array,
	hi: int, seg_fp: int, armor_cap_fp: int, def_coef_fp: int, ironflat_fp: int,
	max_dot: int, dots: Dictionary, flame_dot_mult: float = 1.0
) -> Dictionary:
	var coef_mode := _restraint_mode(str(attacker.sys), str(target.sys))
	var dmg_type := _dmg_type_for(str(attacker.sys))
	var tcoef_fp := _type_coef_fp(dmg_type, str(target.armor_type))

	# 护甲比 floor
	var ar := FixedMath.armor_ratio_fp(int(target.def))
	if str(target.sys) == "ironwall":
		ar = mini(9000, ar + ironflat_fp)
	# ar *= (1 + ab)；cap
	ar = FixedMath.mul_fp(ar, FixedMath.SCALE + int(target.get("ab_fp", 0)))
	ar = mini(armor_cap_fp, ar)
	# pierce（WIND_SSR）；IRON_UR 存活时免疫
	var pi_fp := 1000 if str(attacker.id) == "WIND_SSR_01" else 0
	if pi_fp > 0:
		for e in enemies:
			if str(e.id) == "IRON_UR_01" and int(e.hp) > 0:
				pi_fp = 0
				break
	ar = maxi(0, ar - pi_fp)

	# 段衰减 geo：sm = SEG_DECAY^hi
	var sm_fp := FixedMath.SCALE
	if hi > 0:
		sm_fp = seg_fp
		for _k in range(1, hi):
			sm_fp = FixedMath.mul_fp(sm_fp, seg_fp)

	# DEF_COEF 减法项
	var eff_atk := int(attacker.atk)
	if def_coef_fp > 0:
		eff_atk = maxi(1, int(attacker.atk) - FixedMath.mul_unit(int(target.def), def_coef_fp))

	# raw = eff_atk * sm * co * tc * (1 - ar)
	var raw := FixedMath.mul_unit(eff_atk, sm_fp)
	raw = _apply_restraint(raw, coef_mode)
	raw = FixedMath.mul_unit(raw, tcoef_fp)
	raw = FixedMath.mul_unit(raw, FixedMath.SCALE - ar)
	if dmg_type == "physical":
		raw = FixedMath.mul_unit(raw, FixedMath.SCALE - int(target.get("pr_fp", 0)))

	var dmg := maxi(1, raw)
	# shield absorb
	if int(target.get("sh", 0)) > 0:
		var absorbed := mini(int(target.sh), dmg)
		target.sh = int(target.sh) - absorbed
		dmg -= absorbed
	if dmg > 0:
		target.hp = maxi(0, int(target.hp) - dmg)

	var apply_dot := false
	var sk: Dictionary = attacker.get("skill", {})
	if str(sk.get("type", "")) == "dot" or str(attacker.sys) == "flame":
		apply_dot = true
		var rate_fp := int(DOT_RATE_FP.get(str(attacker.id), 1800))
		if str(attacker.side) == "A" and str(attacker.sys) == "flame" and flame_dot_mult > 0.0 \
				and not is_equal_approx(flame_dot_mult, 1.0):
			rate_fp = FixedMath.mul_fp(rate_fp, FixedMath.from_float(flame_dot_mult))
		var batk := int(attacker.atk)
		if def_coef_fp > 0:
			batk = maxi(1, int(attacker.atk) - FixedMath.mul_unit(int(target.def), def_coef_fp))
		var dd := FixedMath.mul_unit(batk, rate_fp)
		_apply_dot(dots, str(target.uid), str(attacker.sys), dd, max_dot)

	return {
		"t": "hit",
		"attacker": attacker.uid,
		"target": target.uid,
		"dmg": dmg,
		"restraint": _coef_label(coef_mode),
		"kill": int(target.hp) <= 0,
		"apply_dot": apply_dot,
		"seg": hi,
		"name_a": attacker.name,
		"name_t": target.name,
		"sys_a": attacker.sys,
		"sfx": "sfx_btl_hit_%s" % str(attacker.sys),
	}

static func _apply_dot(dots: Dictionary, uid: String, source_sys: String, base_dot: int, max_stack: int) -> void:
	if not dots.has(uid):
		dots[uid] = {"dmg": base_dot, "stacks": 1, "source_sys": source_sys}
	else:
		dots[uid].stacks = mini(max_stack, int(dots[uid].stacks) + 1)
		dots[uid].dmg = maxi(int(dots[uid].dmg), base_dot)
		dots[uid].source_sys = source_sys
