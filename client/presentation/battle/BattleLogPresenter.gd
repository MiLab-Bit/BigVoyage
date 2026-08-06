extends RefCounted
class_name BattleLogPresenter
## 战报 → 演出/SFX 路由（不回流结算）
## 素材未到前：只映射事件键；SfxRouter 决定是否发声

static func iter_events(result: Dictionary) -> Array:
	return result.get("log", [])

static func summarize(result: Dictionary) -> String:
	var w := str(result.get("winner", "?"))
	var r := int(result.get("rounds", 0))
	var hits := 0
	var restraints := 0
	for e in result.get("log", []):
		if str(e.get("t", "")) == "hit":
			hits += 1
			if float(e.get("restraint", 1.0)) > 1.01:
				restraints += 1
	return "胜负=%s · %d回合 · 命中%d · 克制命中%d" % [w, r, hits, restraints]

static func sfx_key_for(event: Dictionary) -> String:
	var k := str(event.get("sfx", ""))
	if k != "":
		return k
	match str(event.get("t", "")):
		"hit":
			return "sfx_btl_hit_%s" % str(event.get("sys_a", "wind"))
		"dot":
			return "sfx_btl_dot"
		"kill":
			return "sfx_btl_kill"
		"control":
			return "sfx_btl_control_tide"
		_:
			return ""
