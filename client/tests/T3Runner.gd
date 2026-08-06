extends Node
## T3 机检：B1 / D3×100×3 / B4 蒙特卡洛 / D1–D5 路径骨架
## godot --headless --path . res://tests/T3.tscn

const ResolveBattleScript = preload("res://systems/battle/ResolveBattle.gd")
const BattleFacadeScript = preload("res://systems/battle/BattleFacade.gd")
const FleetRulesScript = preload("res://systems/fleet/FleetRules.gd")
const MapGraphScript = preload("res://systems/map/MapGraph.gd")
const StaminaCostsScript = preload("res://systems/economy/StaminaCosts.gd")
const PoiServiceScript = preload("res://systems/economy/PoiService.gd")

const D3_RUNS := 100
const B4_SAMPLES := 9600

func _ready() -> void:
	await get_tree().process_frame
	# T3 强制严格 POI（关闭 Demo 软化）
	App.feature_flags["strict_poi"] = true
	App.feature_flags["demo_soft_poi"] = false

	var report := {
		"ok": true,
		"checks": {},
		"ruleset_hint": "client/data/constants.json",
	}
	var ok := true

	ok = _check_b1(report) and ok
	ok = _check_map_d1(report) and ok
	ok = _check_d3(report) and ok
	ok = _check_b4(report) and ok
	ok = _check_path_d2_d5(report) and ok
	ok = _check_chain(report) and ok

	report["ok"] = ok
	print("[t3] report=%s" % JSON.stringify(report))
	if ok:
		print("[t3] OK · B1/D3×%d×3/B4/D-path PASS" % D3_RUNS)
		get_tree().quit(0)
	else:
		print("[t3] FAIL")
		get_tree().quit(1)

func _check_b1(report: Dictionary) -> bool:
	var poi := StaminaCostsScript.poi()
	var sail := StaminaCostsScript.sail()
	var raid := StaminaCostsScript.raid()
	var passed := poi == 6 and sail == 1 and raid == 8
	report["checks"]["B1_stamina"] = {"poi": poi, "sail": sail, "raid": raid, "pass": passed}
	if not passed:
		push_error("FAIL B1: expected poi=6 sail=1 raid=8 got %d/%d/%d" % [poi, sail, raid])
	return passed

func _check_map_d1(report: Dictionary) -> bool:
	GameState.new_game()
	var at_home := GameState.current_island == "FR_01"
	var can := MapGraphScript.can_sail("FR_01", "FR_02")
	var passed := at_home and can
	report["checks"]["D1_boot_map"] = {"current": GameState.current_island, "can_sail_02": can, "pass": passed}
	if not passed:
		push_error("FAIL D1: boot map")
	return passed

func _check_d3(report: Dictionary) -> bool:
	var fleet: Array = GameData.starting.get("crew_ids", [])
	var cases := [
		{"id": "FR_02", "seed": 42, "label": "teach"},
		{"id": "FR_06", "seed": 77, "label": "normal"},
		{"id": "FR_12", "seed": 99, "label": "boss"},
	]
	var all_pass := true
	var case_reports: Array = []
	for c in cases:
		var island_id: String = c["id"]
		var seed: int = c["seed"]
		var base: Dictionary = BattleFacadeScript.fight_guard(fleet, island_id, "SHIP_RAFT", seed)
		if bool(base.get("empty_guard", false)):
			push_error("FAIL D3: empty guard %s" % island_id)
			all_pass = false
			case_reports.append({"id": island_id, "pass": false, "reason": "empty_guard"})
			continue
		var base_key := _result_key(base)
		var mismatch := 0
		for i in D3_RUNS:
			var r: Dictionary = BattleFacadeScript.fight_guard(fleet, island_id, "SHIP_RAFT", seed)
			if _result_key(r) != base_key:
				mismatch += 1
			if i == 0:
				var env: Dictionary = r.get("env", {})
				var direct: Dictionary = ResolveBattleScript.resolve(
					fleet,
					GameData.guards.get(island_id, {}).get("crew_ids", []),
					env,
					seed
				)
				if str(direct.get("hash", "")) != str(base.get("hash", "")):
					mismatch += 1
					push_error("FAIL D3: Facade!=Resolve on %s" % island_id)
		var case_ok := mismatch == 0
		all_pass = all_pass and case_ok
		case_reports.append({
			"id": island_id,
			"label": c["label"],
			"runs": D3_RUNS,
			"winner": base.get("winner"),
			"rounds": base.get("rounds"),
			"hash": str(base.get("hash", "")).substr(0, 12),
			"mismatch": mismatch,
			"pass": case_ok,
		})
		if not case_ok:
			push_error("FAIL D3: %s mismatches=%d" % [island_id, mismatch])
	report["checks"]["D3_determinism"] = {"cases": case_reports, "pass": all_pass}
	return all_pass

func _result_key(r: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		str(r.get("winner", "")),
		str(r.get("rounds", "")),
		str(r.get("hash", "")),
		str(_hp_sum(r.get("units_a", []))) + "/" + str(_hp_sum(r.get("units_b", []))),
	]

func _hp_sum(units: Array) -> int:
	var s := 0
	for u in units:
		s += int(u.get("hp", 0))
	return s

func _check_b4(report: Dictionary) -> bool:
	var crew_rate := float(GameData.constants.get("POI_DROP_CREW_RATE", 1.0 / 480.0))
	var ship_rate := float(GameData.constants.get("POI_DROP_SHIP_RATE", 1.0 / 960.0))
	var crew_hits := 0
	var ship_hits := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260806
	for i in B4_SAMPLES:
		var crew_res: Dictionary = PoiServiceScript.resolve("FR_02", rng)
		if str(crew_res.get("crew_id", "")) != "":
			crew_hits += 1
		var ship_res: Dictionary = PoiServiceScript.resolve("FR_06", rng)
		if bool(ship_res.get("ship_scrap", false)):
			ship_hits += 1
	var n := float(B4_SAMPLES)
	var crew_p := float(crew_hits) / n
	var ship_p := float(ship_hits) / n
	var crew_sigma := sqrt(crew_rate * (1.0 - crew_rate) / n)
	var ship_sigma := sqrt(ship_rate * (1.0 - ship_rate) / n)
	# 机检用 3σ（手册建议 2σ 人工复核）
	var crew_ok := absf(crew_p - crew_rate) <= 3.0 * crew_sigma + 1.0 / n
	var ship_ok := absf(ship_p - ship_rate) <= 3.0 * ship_sigma + 1.0 / n
	var ur_hits := 0
	var ur_rng := RandomNumberGenerator.new()
	ur_rng.seed = 99
	for i in 2000:
		if str(PoiServiceScript.resolve("FR_12", ur_rng).get("crew_id", "")) != "":
			ur_hits += 1
	var ur_p := float(ur_hits) / 2000.0
	var ur_ok := ur_p < 0.05
	var passed := crew_ok and ship_ok and ur_ok
	report["checks"]["B4_poi_rates"] = {
		"samples": B4_SAMPLES,
		"crew_hits": crew_hits,
		"crew_p": crew_p,
		"crew_expect": crew_rate,
		"crew_ok": crew_ok,
		"ship_hits": ship_hits,
		"ship_p": ship_p,
		"ship_expect": ship_rate,
		"ship_ok": ship_ok,
		"ur_soft_gate_disabled": ur_ok,
		"ur_p_sample2000": ur_p,
		"pass": passed,
	}
	if not passed:
		push_error("FAIL B4: crew_p=%.6f ship_p=%.6f ur_p=%.4f" % [crew_p, ship_p, ur_p])
	return passed

func _check_path_d2_d5(report: Dictionary) -> bool:
	GameState.new_game()
	var fleet: Array = GameData.starting.get("crew_ids", [])
	var fv: Dictionary = FleetRulesScript.validate(fleet, fleet)
	if not bool(fv.get("ok", false)):
		report["checks"]["D_path"] = {"pass": false, "reason": "fleet"}
		push_error("FAIL path: fleet")
		return false
	GameState.set_fleet(fleet)

	var sta0 := GameState.stamina
	if not GameState.spend_stamina(StaminaCostsScript.poi()):
		report["checks"]["D_path"] = {"pass": false, "reason": "poi_stamina"}
		return false
	var poi_res: Dictionary = PoiServiceScript.resolve("FR_01")
	GameState.add_strategic(int(poi_res.get("strategic", 0)), "POI")
	var d2_ok := GameState.stamina == sta0 - 6

	var battle: Dictionary = BattleFacadeScript.fight_guard(fleet, "FR_02", GameState.ship_id, 123)
	var receipt: Dictionary = ChainGateway.commit_battle(battle, {"island_id": "FR_02"})
	var d4_ok := bool(receipt.get("ok", false))
	if str(battle.get("winner", "")) == "A":
		GameState.capture_island("FR_02")

	var bank0 := int(GameState.island_yield_bank.get("FR_01", 0))
	var day0 := GameState.day
	GameState.advance_day(30)
	var bank1 := int(GameState.island_yield_bank.get("FR_01", 0))
	var d5_ok := GameState.day == day0 + 30 and bank1 > bank0

	var passed := d2_ok and d4_ok and d5_ok
	report["checks"]["D_path"] = {
		"d2_poi_stamina": d2_ok,
		"d4_commit": d4_ok,
		"d5_yield_days30": d5_ok,
		"day": GameState.day,
		"pass": passed,
	}
	if not passed:
		push_error("FAIL D-path d2=%s d4=%s d5=%s" % [d2_ok, d4_ok, d5_ok])
	return passed

func _check_chain(report: Dictionary) -> bool:
	var fleet: Array = GameData.starting.get("crew_ids", [])
	var r: Dictionary = BattleFacadeScript.fight_guard(fleet, "FR_02", "SHIP_RAFT", 7)
	var receipt: Dictionary = ChainGateway.commit_battle(r, {"island_id": "FR_02", "t3": true})
	var passed := bool(receipt.get("ok", false)) and str(receipt.get("commit", "")) != ""
	report["checks"]["chain_mock"] = {"pass": passed, "commit": str(receipt.get("commit", "")).substr(0, 12)}
	if not passed:
		push_error("FAIL chain mock")
	return passed
