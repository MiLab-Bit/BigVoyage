extends RefCounted
class_name PoiService
## POI 结算骨架（[B4] 单次独立伯努利）
## crew_ur 岛对齐 rarity_bias=UR

static func resolve(island_id: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var gd = (Engine.get_main_loop() as SceneTree).root.get_node("GameData")
	var isl: Dictionary = gd.islands.get(island_id, {})
	var poi: Array = isl.get("poi", ["resource"])
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var roll := r.randf()
	var gained_res := int(gd.constants.get("POI_RESOURCE_BASE", 500))
	var crew_rate := float(gd.constants.get("POI_DROP_CREW_RATE", 1.0 / 480.0))
	var ship_rate := float(gd.constants.get("POI_DROP_SHIP_RATE", 1.0 / 960.0))
	var ops_m := _ops_drop_mult(island_id)
	crew_rate *= ops_m
	ship_rate *= ops_m
	var out := {
		"island_id": island_id,
		"poi": poi,
		"strategic": gained_res,
		"crew_id": "",
		"ship_scrap": false,
		"roll": roll,
		"ur_biased": poi.has("crew_ur"),
		"ops_drop_mult": ops_m,
	}
	var soft := _demo_soft_enabled()
	if poi.has("crew") or poi.has("crew_ur"):
		var hit := roll < crew_rate
		if soft and poi.has("crew_ur") and roll < 0.2:
			hit = true
		if hit:
			var want_ur := poi.has("crew_ur")
			out.crew_id = _pick_crew(gd, r, want_ur)
	var ship_mul := 20.0 if soft else 1.0
	if poi.has("ship") and r.randf() < ship_rate * ship_mul:
		out.ship_scrap = true
		out.strategic = int(out.strategic) + 300
	return out

static func _ops_drop_mult(island_id: String) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var ops = tree.root.get_node_or_null("OpsDirector")
	if ops == null or not ops.has_method("crew_drop_mult"):
		return 1.0
	return float(ops.crew_drop_mult(island_id))

static func _demo_soft_enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var app = tree.root.get_node_or_null("App")
	if app == null:
		return false
	if bool(app.feature_flags.get("strict_poi", false)):
		return false
	return bool(app.feature_flags.get("demo_soft_poi", true))

static func _pick_crew(gd: Node, r: RandomNumberGenerator, ur_only: bool) -> String:
	var pool: Array = []
	for c in gd.card_list:
		var id := str(c.get("id", ""))
		if ur_only and str(c.get("rarity", "")) != "UR":
			continue
		if not GameState.owned_cards.has(id):
			pool.append(id)
	if pool.is_empty() and ur_only:
		for c2 in gd.card_list:
			if str(c2.get("rarity", "")) == "UR":
				pool.append(str(c2["id"]))
	if pool.is_empty():
		for c3 in gd.card_list:
			if not GameState.owned_cards.has(c3["id"]):
				pool.append(c3["id"])
	if pool.is_empty():
		pool = gd.cards.keys()
	if pool.is_empty():
		return ""
	return str(pool[r.randi() % pool.size()])
