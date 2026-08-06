extends RefCounted
class_name MapGraph
## 海图邻接查询（D1）

static func neighbors(island_id: String) -> Array:
	return _gd().adjacency.get(island_id, [])

static func can_sail(from_id: String, to_id: String) -> bool:
	if from_id == to_id:
		return true
	return neighbors(from_id).has(to_id)

static func island(island_id: String) -> Dictionary:
	return _gd().islands.get(island_id, {})

static func is_owned(island_id: String, owned: Array) -> bool:
	return owned.has(island_id)

static func start_island() -> String:
	return "FR_01"

static func _gd() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
