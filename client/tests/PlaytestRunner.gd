extends Node
## 玩法压测：战斗阶梯 / 90 日赛季 bot / 贸易矩阵 / 科技增量 / LiveOps
## godot --headless --path client res://tests/Playtest.tscn

const BattleFacadeScript := preload("res://systems/battle/BattleFacade.gd")
const FleetRulesScript := preload("res://systems/fleet/FleetRules.gd")
const MapGraphScript := preload("res://systems/map/MapGraph.gd")
const StaminaCostsScript := preload("res://systems/economy/StaminaCosts.gd")
const PoiServiceScript := preload("res://systems/economy/PoiService.gd")
const TradeServiceScript := preload("res://systems/economy/TradeService.gd")
const TechServiceScript := preload("res://systems/economy/TechService.gd")
const AllianceServiceScript := preload("res://systems/social/AllianceService.gd")
const RaidServiceScript := preload("res://systems/social/RaidService.gd")

const BATTLE_SEEDS := 40
const SEASON_BOTS := 8
const SEASON_DAYS := 90
const EVIDENCE_PATH := "res://tests/evidence/playtest_latest.json"

func _ready() -> void:
	if Engine.has_meta("playtest_ran") and bool(Engine.get_meta("playtest_ran")):
		return
	Engine.set_meta("playtest_ran", true)
	await get_tree().process_frame
	App.feature_flags["strict_poi"] = true
	App.feature_flags["demo_soft_poi"] = false
	# 压测开全海，覆盖三角跨海与终核；隔离存档日数对 LiveOps 的污染
	App.feature_flags["full_world"] = true
	GameState.new_game()
	GameState.day = 1
	GameState.tech_unlocked = []
	GameState.tutorial_flags["unlock_all_seas"] = true
	GameData.reload_world_filter(["frozen", "abyss", "blaze", "tradewind"])

	var report := {
		"ok": true,
		"version": "v1.18-playtest",
		"ts": Time.get_datetime_string_from_system(true, true),
		"checks": {},
		"knobs": {
			"battle_seeds": BATTLE_SEEDS,
			"season_bots": SEASON_BOTS,
			"season_days": SEASON_DAYS,
		},
	}
	var ok := true
	ok = _check_battle_ladder(report) and ok
	ok = _check_tech_delta(report) and ok
	ok = _check_trade_matrix(report) and ok
	ok = _check_liveops(report) and ok
	ok = _check_season_bots(report) and ok
	report["ok"] = ok
	_write_evidence(report)
	print("[playtest] report=%s" % JSON.stringify(report))
	if ok:
		print("[playtest] OK · ladder/tech/trade/ops/season PASS")
	else:
		print("[playtest] FAIL · see checks / evidence")
	var code := 0 if ok else 1
	if get_tree() != null:
		get_tree().quit(code)
	else:
		Engine.get_main_loop().quit()

## —— P1 战斗阶梯：开局 / 中盘 / 终局队 × 教学/常规/Boss ——
func _check_battle_ladder(report: Dictionary) -> bool:
	GameState.day = 1
	GameState.tech_unlocked = []
	var fleets := {
		"start": _fleet_start(),
		"mid": _fleet_mid(),
		"end": _fleet_end(),
	}
	var islands := [
		{"id": "FR_02", "label": "teach"},
		{"id": "FR_06", "label": "normal"},
		{"id": "FR_12", "label": "boss"},
	]
	if GameData.islands.has("AB_09"):
		islands.append({"id": "AB_09", "label": "boss_abyss"})
	var matrix: Array = []
	var all_pass := true
	for fname in fleets.keys():
		var fleet: Array = fleets[fname]
		var fv: Dictionary = FleetRulesScript.validate(fleet, fleet)
		if not bool(fv.get("ok", false)):
			push_error("FAIL ladder fleet %s: %s" % [fname, fv.get("reason", "")])
			all_pass = false
			matrix.append({"fleet": fname, "pass": false, "reason": fv.get("reason", "illegal")})
			continue
		for isl in islands:
			if not GameData.guards.has(isl.id):
				continue
			var row := _battle_sample(fleet, str(isl.id), str(isl.label), fname)
			matrix.append(row)
	# 终核门禁用「终局队 + 全科技」：裸双 UR 对 FR_12 设计上偏硬（记录但不卡死）
	GameState.tech_unlocked = []
	for n in GameData.tech_tree.get("nodes", []):
		GameState.tech_unlocked.append(str(n.get("id", "")))
	var end_tech_row := _battle_sample(_fleet_end(), "FR_12", "boss_tech", "end_tech")
	matrix.append(end_tech_row)
	GameState.tech_unlocked = []
	var mid_ok := true
	var end_tech_ok := true
	var abyss_hard_ok := true
	var start_teach: Dictionary = {}
	var start_abyss_wr := -1.0
	for row in matrix:
		if str(row.get("fleet")) == "mid" and str(row.get("island")) == "FR_06":
			mid_ok = float(row.get("win_rate", 0)) >= 0.25
			row["gate"] = "mid>=25%"
			row["gate_pass"] = mid_ok
		if str(row.get("fleet")) == "end_tech" and str(row.get("island")) == "FR_12":
			end_tech_ok = float(row.get("win_rate", 0)) >= 0.25
			row["gate"] = "end_tech_boss>=25%"
			row["gate_pass"] = end_tech_ok
		if str(row.get("fleet")) == "end" and str(row.get("island")) == "FR_12":
			row["gate"] = "end_boss_observed"
			row["gate_pass"] = true
			row["boss_hard"] = float(row.get("win_rate", 0)) < 0.10
		if str(row.get("fleet")) == "start" and str(row.get("island")) == "FR_02":
			start_teach = row
			row["gate"] = "start_teach_observed"
			row["gate_pass"] = true
			row["teach_hard"] = float(row.get("win_rate", 0)) < 0.10
		# AB_09 不得再被开局队碾压（偏软回归门禁）
		if str(row.get("fleet")) == "start" and str(row.get("island")) == "AB_09":
			start_abyss_wr = float(row.get("win_rate", 0))
			abyss_hard_ok = start_abyss_wr <= 0.15
			row["gate"] = "start_AB09<=15%"
			row["gate_pass"] = abyss_hard_ok
	all_pass = all_pass and mid_ok and end_tech_ok and abyss_hard_ok
	report["checks"]["P1_battle_ladder"] = {
		"matrix": matrix,
		"start_teach_win_rate": start_teach.get("win_rate", null),
		"start_abyss_boss_win_rate": start_abyss_wr,
		"mid_ok": mid_ok,
		"end_tech_ok": end_tech_ok,
		"abyss_hard_ok": abyss_hard_ok,
		"end_tech_boss_win_rate": end_tech_row.get("win_rate"),
		"pass": all_pass,
	}
	for row2 in matrix:
		if str(row2.get("fleet")) == "end" and str(row2.get("island")) == "FR_12":
			report["checks"]["P1_battle_ladder"]["end_naked_boss_win_rate"] = row2.get("win_rate")
	if not all_pass:
		push_error("FAIL P1 ladder mid=%s end_tech=%s abyss_hard=%s" % [mid_ok, end_tech_ok, abyss_hard_ok])
	return all_pass

func _battle_sample(fleet: Array, island_id: String, label: String, fleet_name: String) -> Dictionary:
	var wins := 0
	var rounds_sum := 0
	var hash0 := ""
	var mismatch := 0
	for i in BATTLE_SEEDS:
		var seed := 1000 + i * 17 + island_id.hash() % 97
		var r: Dictionary = BattleFacadeScript.fight_guard(fleet, island_id, "SHIP_IRON", seed)
		if str(r.get("winner", "")) == "A":
			wins += 1
		rounds_sum += int(r.get("rounds", 0))
		var h := str(r.get("hash", ""))
		if i == 0:
			hash0 = h
			# 同 seed 复跑确定性
			var r2: Dictionary = BattleFacadeScript.fight_guard(fleet, island_id, "SHIP_IRON", seed)
			if str(r2.get("hash", "")) != h:
				mismatch += 1
	var n := float(BATTLE_SEEDS)
	return {
		"fleet": fleet_name,
		"island": island_id,
		"label": label,
		"wins": wins,
		"win_rate": wins / n,
		"avg_rounds": rounds_sum / n,
		"det_mismatch": mismatch,
		"sample_hash": hash0.substr(0, 12),
		"pass": mismatch == 0,
	}

## —— P2 科技增量：解锁全科技后我方防御/胜场应不劣于基线 ——
func _check_tech_delta(report: Dictionary) -> bool:
	GameState.new_game()
	GameState.owned_cards = _all_card_ids()
	var fleet := _fleet_end()
	GameState.set_fleet(fleet)
	GameState.tech_unlocked = []
	var base_mods: Dictionary = TechServiceScript.battle_mods()
	var base: Dictionary = BattleFacadeScript.fight_guard(fleet, "FR_06", "SHIP_IRON", 4242)
	# 灌满科技（忽略前置/Boss 门）
	GameState.tech_unlocked = []
	for n in GameData.tech_tree.get("nodes", []):
		GameState.tech_unlocked.append(str(n.get("id", "")))
	var tech_mods: Dictionary = TechServiceScript.battle_mods()
	var buffed: Dictionary = BattleFacadeScript.fight_guard(fleet, "FR_06", "SHIP_IRON", 4242)
	var def_up := float(tech_mods.get("def_mult", 1.0)) > float(base_mods.get("def_mult", 1.0))
	var flame_up := float(tech_mods.get("flame_dot", 1.0)) > 1.0
	var wind_up := float(tech_mods.get("wind_seg", 1.0)) > 1.0
	var tide_up := float(tech_mods.get("tide_shield", 1.0)) > 1.0
	var env_diff := JSON.stringify(base.get("env", {})) != JSON.stringify(buffed.get("env", {}))
	# 同 seed 下 hash 应因 tech_a 入 env 而变化
	var hash_changed := str(base.get("hash", "")) != str(buffed.get("hash", ""))
	var passed := def_up and flame_up and wind_up and tide_up and env_diff and hash_changed
	report["checks"]["P2_tech_delta"] = {
		"base_mods": base_mods,
		"tech_mods": tech_mods,
		"base_winner": base.get("winner"),
		"buffed_winner": buffed.get("winner"),
		"hash_changed": hash_changed,
		"pass": passed,
	}
	if not passed:
		push_error("FAIL P2 tech delta")
	GameState.tech_unlocked = []
	return passed

## —— P3 贸易矩阵：正利航线与跨海/终局报价存在 ——
func _check_trade_matrix(report: Dictionary) -> bool:
	GameState.new_game()
	App.feature_flags["full_world"] = true
	GameData.reload_world_filter(["frozen", "abyss", "blaze", "tradewind"])
	# 拥有主要贸易港以便 quote
	for pid in GameData.trade_prices.get("ports", {}).keys():
		if not GameState.owned_islands.has(pid):
			GameState.owned_islands.append(pid)
	GameState.current_island = "FR_01"
	var ports: Array = GameData.trade_prices.get("ports", {}).keys()
	var goods: Array = GameData.trade_prices.get("goods", ["timber"])
	var pos := 0
	var cross := 0
	var endgame := 0
	var scanned := 0
	for a in ports:
		for b in ports:
			if a == b:
				continue
			for g in goods:
				scanned += 1
				var q: Dictionary = TradeServiceScript.quote(str(a), str(b), str(g), 1)
				if bool(q.get("ok", false)):
					pos += 1
					if bool(q.get("cross_sea", false)):
						cross += 1
					if float(q.get("endgame", 1.0)) > 1.0:
						endgame += 1
	var tri_ok := 0
	var tri_three := 0
	var tri_scan := 0
	var hubs := ["FR_01", "AB_01", "BL_01", "TW_01", "FR_06", "TW_09", "BL_09"]
	for a in hubs:
		if not GameData.trade_prices.get("ports", {}).has(a):
			continue
		for b in hubs:
			for c in hubs:
				if a == b or b == c or a == c:
					continue
				for g0 in goods:
					for g1 in goods:
						tri_scan += 1
						if tri_scan > 400:
							break
						var tq: Dictionary = TradeServiceScript.quote_triangle(str(a), str(b), str(c), str(g0), str(g1), 1)
						if bool(tq.get("ok", false)):
							tri_ok += 1
							if bool(tq.get("three_sea", false)):
								tri_three += 1
					if tri_scan > 400:
						break
				if tri_scan > 400:
					break
			if tri_scan > 400:
				break
		if tri_scan > 400:
			break
	var passed := pos >= 8 and cross >= 1 and endgame >= 1 and tri_ok >= 1
	report["checks"]["P3_trade_matrix"] = {
		"scanned": scanned,
		"positive": pos,
		"cross_sea_positive": cross,
		"endgame_positive": endgame,
		"triangle_scanned": tri_scan,
		"triangle_ok": tri_ok,
		"triangle_three_sea": tri_three,
		"pass": passed,
	}
	if not passed:
		push_error("FAIL P3 trade matrix pos=%d cross=%d end=%d tri=%d" % [pos, cross, endgame, tri_ok])
	return passed

## —— P4 LiveOps：关键日掉率/守卫倍率应变化 ——
func _check_liveops(report: Dictionary) -> bool:
	var ops = OpsDirector
	var samples: Array = []
	var days := [5, 15, 58, 70, 88]
	for d in days:
		GameState.day = d
		samples.append({
			"day": d,
			"drop": ops.crew_drop_mult("FR_02"),
			"drop_boss": ops.crew_drop_mult("FR_12"),
			"guard": ops.guard_hp_mult("FR_06", "frozen"),
			"guard_boss": ops.guard_hp_mult("FR_12", "frozen"),
			"gvg": ops.gvg_loot_mult(),
			"risk_tw": ops.trade_risk_mult("tradewind"),
			"active": ops.active_events(d).size(),
		})
	var drop15 := float(samples[1].drop)
	var drop70 := float(samples[3].drop_boss)
	var guard70 := float(samples[3].guard_boss)
	var gvg58 := float(samples[2].gvg)
	# 觉醒期 drop>1；Boss 窗 drop_boss>1；征伐周 gvg>1
	var passed := drop15 > 1.0 and drop70 > 1.0 and guard70 > 1.0 and gvg58 > 1.0
	# 战斗门面确实吃到 ops：同岛不同日 hp_mult_b 应不同
	GameState.day = 15
	GameState.tech_unlocked = []
	var e15: Dictionary = BattleFacadeScript.fight_guard(_fleet_start(), "FR_06", "SHIP_RAFT", 9).get("env", {})
	GameState.day = 70
	var e70: Dictionary = BattleFacadeScript.fight_guard(_fleet_start(), "FR_12", "SHIP_RAFT", 9).get("env", {})
	var facade_ops := float(e15.get("hp_mult_b", 1.0)) > 0.0 and float(e70.get("hp_mult_b", 1.0)) != float(e15.get("hp_mult_b", 1.0))
	passed = passed and facade_ops
	report["checks"]["P4_liveops"] = {
		"samples": samples,
		"facade_hp_day15": e15.get("hp_mult_b"),
		"facade_hp_day70_boss": e70.get("hp_mult_b"),
		"pass": passed,
	}
	if not passed:
		push_error("FAIL P4 liveops")
	GameState.day = 1
	return passed

## —— P5 赛季 bot 压测：多 seed 90 日自动游玩 ——
func _check_season_bots(report: Dictionary) -> bool:
	var runs: Array = []
	var progress_ok := 0
	var trade_ok_n := 0
	var war_ok_n := 0
	var softlock := 0
	var crashes := 0
	for bi in SEASON_BOTS:
		var seed := 7000 + bi * 131
		var one := _run_season_bot(seed)
		runs.append(one)
		if bool(one.get("crash", false)):
			crashes += 1
			continue
		if bool(one.get("softlock", false)):
			softlock += 1
		if int(one.get("islands", 0)) >= 2 or int(one.get("strategic", 0)) >= 2000 or int(one.get("tech", 0)) >= 1:
			progress_ok += 1
		if int(one.get("trades", 0)) >= 8:
			trade_ok_n += 1
		# 联航：终局战绩差不应长期深负（敌分追太快回归）
		var lead := int(one.get("war", {}).get("lead", 0))
		if lead >= -320:
			war_ok_n += 1
	var avg_islands := 0.0
	var avg_strat := 0.0
	var avg_wins := 0.0
	var avg_trades := 0.0
	var avg_lead := 0.0
	for r in runs:
		avg_islands += float(r.get("islands", 0))
		avg_strat += float(r.get("strategic", 0))
		avg_wins += float(r.get("battles_won", 0))
		avg_trades += float(r.get("trades", 0))
		avg_lead += float(r.get("war", {}).get("lead", 0))
	var n := float(maxi(1, runs.size()))
	avg_islands /= n
	avg_strat /= n
	avg_wins /= n
	avg_trades /= n
	avg_lead /= n
	# 门禁：无崩溃；软锁 < 半；进度≥半；贸易强制≥半 bot；联航 lead 门禁≥半
	var passed := crashes == 0 and softlock * 2 <= SEASON_BOTS and progress_ok * 2 >= SEASON_BOTS \
		and trade_ok_n * 2 >= SEASON_BOTS and war_ok_n * 2 >= SEASON_BOTS and avg_trades >= 8.0
	report["checks"]["P5_season_bots"] = {
		"bots": SEASON_BOTS,
		"days": SEASON_DAYS,
		"crashes": crashes,
		"softlocks": softlock,
		"progress_ok": progress_ok,
		"trade_ok_n": trade_ok_n,
		"war_ok_n": war_ok_n,
		"avg_islands": avg_islands,
		"avg_strategic": avg_strat,
		"avg_battles_won": avg_wins,
		"avg_trades": avg_trades,
		"avg_war_lead": avg_lead,
		"runs": runs,
		"pass": passed,
	}
	if not passed:
		push_error("FAIL P5 bots crash=%d soft=%d prog=%d trade=%d war=%d avg_tr=%.1f" % [
			crashes, softlock, progress_ok, trade_ok_n, war_ok_n, avg_trades,
		])
	return passed

func _run_season_bot(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := {
		"seed": seed,
		"islands": 1,
		"strategic": 0,
		"tech": 0,
		"battles_won": 0,
		"battles_lost": 0,
		"trades": 0,
		"triangles": 0,
		"trade_net": 0,
		"gvg_wins": 0,
		"poi": 0,
		"softlock": false,
		"crash": false,
		"day_end": 1,
	}
	# 避免 save 污染玩家档：临时关写盘靠直接改状态；new_game 会 save，可接受
	GameState.new_game()
	GameState.battle_seed = seed
	App.feature_flags["full_world"] = true
	GameState.tutorial_flags["unlock_all_seas"] = true
	GameData.reload_world_filter(["frozen", "abyss", "blaze", "tradewind"])
	# 放宽持卡：赛季中逐步解锁，开局给 owned 全集以便编队成长
	GameState.owned_cards = GameData.starting.get("owned_cards", []).duplicate()
	for cid in _fleet_mid():
		if not GameState.owned_cards.has(cid):
			GameState.owned_cards.append(cid)
	GameState.set_fleet(_fleet_start())
	AllianceServiceScript.join_demo()
	var idle_days := 0
	for d in SEASON_DAYS:
		out.day_end = GameState.day
		var acted := false
		# 中后期换更强编队
		if GameState.day == 20:
			for cid in _fleet_mid():
				if not GameState.owned_cards.has(cid):
					GameState.owned_cards.append(cid)
			GameState.set_fleet(_fleet_mid())
		if GameState.day == 55:
			GameState.owned_cards = _all_card_ids()
			GameState.set_fleet(_fleet_end())
			GameState.ship_id = "SHIP_IRON"
		# 科技
		for n in GameData.tech_tree.get("nodes", []):
			var nid := str(n.get("id", ""))
			var gate: Dictionary = TechServiceScript.can_unlock(nid)
			if bool(gate.get("ok", false)):
				TechServiceScript.unlock(nid)
				acted = true
				break
		# 强制贸易策略：有贸易港且体力够时，优先跑最佳正利 / 三角
		var traded := _bot_force_trade(out)
		if traded:
			acted = true
		# POI（贸易后仍有体力再探索）
		if GameState.stamina >= StaminaCostsScript.poi():
			if GameState.spend_stamina(StaminaCostsScript.poi()):
				var pr: Dictionary = PoiServiceScript.resolve(GameState.current_island, rng)
				GameState.add_strategic(int(pr.get("strategic", 0)), "POI")
				if str(pr.get("crew_id", "")) != "":
					GameState.gain_card(str(pr.crew_id))
				out.poi = int(out.poi) + 1
				acted = true
		# 战斗 / 占领当前岛
		var cur := GameState.current_island
		if not GameState.owned_islands.has(cur):
			var gh := int(GameData.islands.get(cur, {}).get("guard_hp", 0))
			if gh <= 0:
				GameState.capture_island(cur)
				acted = true
			elif GameState.stamina >= StaminaCostsScript.raid():
				var bseed := seed + GameState.day * 13 + cur.hash()
				var br: Dictionary = BattleFacadeScript.fight_guard(GameState.fleet, cur, GameState.ship_id, bseed)
				GameState.spend_stamina(StaminaCostsScript.raid())
				if str(br.get("winner", "")) == "A":
					GameState.capture_island(cur)
					out.battles_won = int(out.battles_won) + 1
				else:
					out.battles_lost = int(out.battles_lost) + 1
				acted = true
		# GVG
		if str(GameState.alliance.get("id", "")) != "" and GameState.day >= 55:
			var targets: Array = RaidServiceScript.targets_from(GameState.current_island)
			for tid in targets:
				var cg: Dictionary = RaidServiceScript.can_raid(str(tid))
				if bool(cg.get("ok", false)):
					var rr: Dictionary = RaidServiceScript.raid(str(tid))
					if bool(rr.get("won", false)):
						out.gvg_wins = int(out.gvg_wins) + 1
					acted = true
					break
		# 出航到未占邻岛 / 随机邻岛
		var neigh: Array = GameData.adjacency.get(GameState.current_island, [])
		var dest := ""
		for n2 in neigh:
			if not GameState.owned_islands.has(n2):
				dest = str(n2)
				break
		if dest == "" and neigh.size() > 0:
			dest = str(neigh[rng.randi() % neigh.size()])
		if dest != "" and dest != GameState.current_island and GameState.stamina >= StaminaCostsScript.sail():
			if MapGraphScript.can_sail(GameState.current_island, dest) or GameData.adjacency.get(GameState.current_island, []).has(dest):
				GameState.spend_stamina(StaminaCostsScript.sail())
				GameState.current_island = dest
				GameState.reveal_island(dest)
				acted = true
		if not acted:
			idle_days += 1
		else:
			idle_days = 0
		if idle_days >= 12:
			out.softlock = true
			break
		GameState.advance_day(1)
	out.islands = GameState.owned_islands.size()
	out.strategic = GameState.strategic
	out.tech = GameState.tech_unlocked.size()
	out.war = AllianceServiceScript.season_war_snapshot()
	return out

## 强制贸易：在已占贸易港中搜最佳直航/三角并执行（每日最多 2 笔）
func _bot_force_trade(out: Dictionary) -> bool:
	var ports: Array = []
	var catalog: Dictionary = GameData.trade_prices.get("ports", {})
	for id in GameState.owned_islands:
		if catalog.has(id):
			ports.append(str(id))
	if ports.size() < 2:
		return false
	var goods: Array = GameData.trade_prices.get("goods", ["timber"])
	var did := false
	var budget := 2
	# 1) 最佳直航
	var best_q: Dictionary = {}
	var best_net := 0
	for a in ports:
		for b in ports:
			if a == b:
				continue
			for g in goods:
				var q: Dictionary = TradeServiceScript.quote(str(a), str(b), str(g), 1)
				if bool(q.get("ok", false)) and int(q.get("net", 0)) > best_net:
					best_net = int(q.net)
					best_q = {"a": a, "b": b, "g": g, "q": q}
	if best_net > 0 and GameState.stamina >= 2:
		var tr: Dictionary = TradeServiceScript.execute(str(best_q.a), str(best_q.b), str(best_q.g), 1)
		if bool(tr.get("ok", false)):
			out.trades = int(out.trades) + 1
			out.trade_net = int(out.trade_net) + int(tr.get("net", 0))
			did = true
			budget -= 1
	# 2) 三角（有 3+ 贸易港时）
	if budget > 0 and ports.size() >= 3 and GameState.stamina >= 4:
		var best_t: Dictionary = {}
		var best_tn := 0
		var scanned := 0
		for a2 in ports:
			for b2 in ports:
				for c2 in ports:
					if a2 == b2 or b2 == c2 or a2 == c2:
						continue
					for g0 in goods:
						for g1 in goods:
							scanned += 1
							if scanned > 120:
								break
							var tq: Dictionary = TradeServiceScript.quote_triangle(str(a2), str(b2), str(c2), str(g0), str(g1), 1)
							if bool(tq.get("ok", false)) and int(tq.get("net", 0)) > best_tn:
								best_tn = int(tq.net)
								best_t = {"a": a2, "b": b2, "c": c2, "g0": g0, "g1": g1}
						if scanned > 120:
							break
					if scanned > 120:
						break
				if scanned > 120:
					break
			if scanned > 120:
				break
		if best_tn > 0:
			var tr2: Dictionary = TradeServiceScript.execute_triangle(
				str(best_t.a), str(best_t.b), str(best_t.c), str(best_t.g0), str(best_t.g1), 1
			)
			if bool(tr2.get("ok", false)):
				out.trades = int(out.trades) + 1
				out.triangles = int(out.triangles) + 1
				out.trade_net = int(out.trade_net) + int(tr2.get("net", 0))
				did = true
	return did

func _fleet_start() -> Array:
	return GameData.starting.get("crew_ids", []).duplicate()

func _fleet_mid() -> Array:
	# COST 内中盘：SSR 烈焰 + 铁壁 SR/R + 疾风/潮汐
	return ["FLAME_SSR_01", "IRON_SSR_01", "IRON_SR_01", "WIND_R_02", "TIDE_R_02"]

func _fleet_end() -> Array:
	## COST 上限 10：双 UR + 两 R
	return ["FLAME_UR_01", "IRON_UR_01", "WIND_R_02", "TIDE_R_02"]

func _all_card_ids() -> Array:
	var out: Array = []
	for id in GameData.cards.keys():
		out.append(str(id))
	return out

func _write_evidence(report: Dictionary) -> void:
	var abs_dir := ProjectSettings.globalize_path("res://tests/evidence")
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var f := FileAccess.open(EVIDENCE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		print("[playtest] evidence → ", EVIDENCE_PATH)
