extends SceneTree
## 无头冒烟：godot --headless --path . -s res://tests/smoke.gd
## 验证数据加载 + ResolveBattle 确定性

const ResolveBattleScript = preload("res://systems/ResolveBattle.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var ok := true
	if GameData.cards.is_empty() or GameData.islands.is_empty():
		push_error("FAIL: GameData empty")
		ok = false
	var fleet_a: Array = GameData.starting.get("crew_ids", [])
	var fleet_b: Array = GameData.guards.get("FR_02", {}).get("crew_ids", [])
	var env := {"ship_a": "SHIP_RAFT", "ship_b": "SHIP_IRON", "hp_mult_b": 1.0}
	var r1: Dictionary = ResolveBattleScript.resolve(fleet_a, fleet_b, env, 42)
	var r2: Dictionary = ResolveBattleScript.resolve(fleet_a, fleet_b, env, 42)
	if r1.get("hash") != r2.get("hash"):
		push_error("FAIL: battle not deterministic")
		ok = false
	if str(r1.get("winner", "")) == "":
		push_error("FAIL: no winner")
		ok = false
	print("[smoke] cards=%d islands=%d winner=%s rounds=%s hash=%s" % [
		GameData.cards.size(), GameData.islands.size(),
		r1.get("winner"), r1.get("rounds"), r1.get("hash")
	])
	if ok:
		print("[smoke] OK")
		quit(0)
	else:
		print("[smoke] FAIL")
		quit(1)
