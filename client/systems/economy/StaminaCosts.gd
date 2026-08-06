extends RefCounted
class_name StaminaCosts
## 体力消耗单一读取口（[B1] POI=6）

static func sail() -> int:
	return int(_c().get("STAMINA_COST_SAIL", 1))

static func poi() -> int:
	return int(_c().get("STAMINA_COST_POI", 6))

static func raid() -> int:
	return int(_c().get("STAMINA_COST_RAID", 8))

static func max_stamina() -> int:
	return int(_c().get("STAMINA_MAX", 120))

static func _c() -> Dictionary:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameData").constants
