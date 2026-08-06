extends Node
## 场景冒烟：godot --headless --path . res://tests/Smoke.tscn

const ResolveBattleScript = preload("res://systems/battle/ResolveBattle.gd")
const FixedMathScript = preload("res://core/FixedMath.gd")
const FleetRulesScript = preload("res://systems/fleet/FleetRules.gd")
const BattleFacadeScript = preload("res://systems/battle/BattleFacade.gd")
const MapGraphScript = preload("res://systems/map/MapGraph.gd")
const StaminaCostsScript = preload("res://systems/economy/StaminaCosts.gd")

func _ready() -> void:
	await get_tree().process_frame
	var ok := true
	if GameData.cards.is_empty() or GameData.islands.is_empty():
		push_error("FAIL: GameData empty")
		ok = false
	if StaminaCostsScript.poi() != 6:
		push_error("FAIL: POI stamina != 6")
		ok = false
	if not MapGraphScript.can_sail("FR_01", "FR_02") and MapGraphScript.neighbors("FR_01").is_empty():
		push_error("FAIL: map graph empty")
		ok = false

	var fleet_a: Array = GameData.starting.get("crew_ids", [])
	var v: Dictionary = FleetRulesScript.validate(fleet_a, fleet_a)
	if not bool(v.get("ok", false)):
		push_error("FAIL: starting fleet illegal %s" % str(v))
		ok = false

	var r1: Dictionary = BattleFacadeScript.fight_guard(fleet_a, "FR_02", "SHIP_RAFT", 42)
	var env1: Dictionary = r1.get("env", {
		"ship_a": "SHIP_RAFT", "ship_b": "SHIP_IRON", "hp_mult_b": 1.0
	})
	var r2: Dictionary = ResolveBattleScript.resolve(
		fleet_a,
		GameData.guards.get("FR_02", {}).get("crew_ids", []),
		env1,
		42
	)
	if r1.get("hash") != r2.get("hash"):
		push_error("FAIL: BattleFacade != ResolveBattle")
		ok = false
	if r1.get("hash") != ResolveBattleScript.resolve(
		fleet_a,
		GameData.guards.get("FR_02", {}).get("crew_ids", []),
		env1,
		42
	).get("hash"):
		push_error("FAIL: not deterministic")
		ok = false

	var receipt: Dictionary = ChainGateway.commit_battle(r1, {"island_id": "FR_02"})
	if not bool(receipt.get("ok", false)) or str(receipt.get("commit", "")) == "":
		push_error("FAIL: chain mock commit")
		ok = false

	var seg2 := FixedMathScript.mul_fp(
		FixedMathScript.from_float(0.40),
		FixedMathScript.from_float(0.40)
	)
	if seg2 != 1600:
		push_error("FAIL: FixedMath")
		ok = false

	var cov: Dictionary = AssetDB.coverage_snapshot()
	var art_ok := bool(cov.get("has_map", false)) and int(cov.get("cards_full", 0)) >= 20 and int(cov.get("islands_full", 0)) >= 12
	var mus_ok := AssetDB.music_path("bgm_sea_frozen_bed") != "" and AssetDB.music_path("bgm_battle_frozen") != ""
	if not art_ok:
		push_error("FAIL: art coverage cards=%s islands=%s" % [cov.get("cards_full"), cov.get("islands_full")])
		ok = false
	if not mus_ok:
		push_error("FAIL: missing BGM bed/battle")
		ok = false

	print("[smoke] skeleton ok=%s art=%s mus=%s cards=%s islands=%s winner=%s" % [
		ok, art_ok, mus_ok, cov.get("cards_full"), cov.get("islands_full"), r1.get("winner")
	])
	if ok:
		print("[smoke] OK")
		get_tree().quit(0)
	else:
		print("[smoke] FAIL")
		get_tree().quit(1)
