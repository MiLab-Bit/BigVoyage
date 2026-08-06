extends RefCounted
class_name GachaFacade
## 抽卡：保底 + UR 独占池；可选写入船籍（gacha_grants）

const UrExclusiveScript := preload("res://systems/gacha/UrExclusive.gd")

const RARITY_WEIGHT := {"R": 70, "SR": 20, "SSR": 8, "UR": 2}
const PITY_UR := 70
const PITY_SSR := 10

static func pity_progress() -> Dictionary:
	var pulls := int(GameState.tutorial_flags.get("gacha_pulls", 0))
	var since_ur := int(GameState.tutorial_flags.get("gacha_since_ur", 0))
	var since_ssr := int(GameState.tutorial_flags.get("gacha_since_ssr", 0))
	return {
		"total": pulls,
		"since_ur": since_ur,
		"since_ssr": since_ssr,
		"pity_ur": PITY_UR,
		"pity_ssr": PITY_SSR,
		"ur_in": maxi(0, PITY_UR - since_ur),
		"ssr_in": maxi(0, PITY_SSR - since_ssr),
	}

static func pull_one(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var since_ur := int(GameState.tutorial_flags.get("gacha_since_ur", 0)) + 1
	var since_ssr := int(GameState.tutorial_flags.get("gacha_since_ssr", 0)) + 1
	var rarity := _roll_rarity(r, since_ur, since_ssr)
	var card_id := _pick_card(rarity, r)
	GameState.tutorial_flags["gacha_pulls"] = int(GameState.tutorial_flags.get("gacha_pulls", 0)) + 1
	if rarity == "UR":
		GameState.tutorial_flags["gacha_since_ur"] = 0
		GameState.tutorial_flags["gacha_since_ssr"] = 0
	elif rarity == "SSR":
		GameState.tutorial_flags["gacha_since_ur"] = since_ur
		GameState.tutorial_flags["gacha_since_ssr"] = 0
	else:
		GameState.tutorial_flags["gacha_since_ur"] = since_ur
		GameState.tutorial_flags["gacha_since_ssr"] = since_ssr
	var granted := false
	if _grants_enabled() and not GameState.owned_cards.has(card_id):
		GameState.gain_card(card_id)
		granted = true
	GameState.save_game()
	return {
		"card_id": card_id,
		"rarity": rarity,
		"display_only": not _grants_enabled(),
		"granted": granted,
		"owned": GameState.owned_cards.has(card_id),
		"exclusive": UrExclusiveScript.blurb(card_id),
	}

static func pull_ten(rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []
	for i in 10:
		out.append(pull_one(rng))
	return out

static func _grants_enabled() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var app = tree.root.get_node_or_null("App")
	if app == null:
		return false
	return bool(app.feature_flags.get("gacha_grants", true))

static func _roll_rarity(r: RandomNumberGenerator, since_ur: int, since_ssr: int) -> String:
	if since_ur >= PITY_UR:
		return "UR"
	if since_ssr >= PITY_SSR:
		return "SSR"
	var total := 0
	for w in RARITY_WEIGHT.values():
		total += int(w)
	var roll := r.randi() % total
	var acc := 0
	for k in ["R", "SR", "SSR", "UR"]:
		acc += int(RARITY_WEIGHT[k])
		if roll < acc:
			return k
	return "R"

static func _pick_card(rarity: String, r: RandomNumberGenerator) -> String:
	var pool: Array = []
	for c in GameData.card_list:
		if str(c.get("rarity", "")) == rarity:
			pool.append(str(c["id"]))
	if pool.is_empty():
		for c2 in GameData.card_list:
			pool.append(str(c2["id"]))
	if pool.is_empty():
		return "FLAME_R_01"
	# UR：优先未拥有的独占核
	if rarity == "UR":
		var unowned: Array = []
		for id in pool:
			if not GameState.owned_cards.has(id):
				unowned.append(id)
		if not unowned.is_empty():
			pool = unowned
	return str(pool[r.randi() % pool.size()])
