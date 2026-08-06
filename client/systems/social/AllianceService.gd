extends RefCounted
class_name AllianceService
## 赛季联航：本机完整对抗（敌联 AI 日推 + 战报），税率/金库/GVG

const TechServiceScript := preload("res://systems/economy/TechService.gd")
const TAX_CAP := 0.05
const BASE_CAP := 10
const RIVAL_NAME := "赤潮联航"
const LOG_CAP := 12

static func state() -> Dictionary:
	return GameState.alliance

static func tax_rate() -> float:
	if str(GameState.alliance.get("id", "")) == "":
		return 0.0
	return clampf(float(GameState.alliance.get("tax", 0.0)), 0.0, TAX_CAP)

static func create(name: String) -> Dictionary:
	if str(GameState.alliance.get("id", "")) != "":
		return {"ok": false, "reason": "已在联盟中"}
	if name.strip_edges() == "":
		return {"ok": false, "reason": "名称不能为空"}
	GameState.alliance = _blank_alliance(
		"AL_%s" % str(Time.get_unix_time_from_system()),
		name.strip_edges(),
		GameState.player_name,
		[GameState.player_name],
		0
	)
	GameState.tutorial_flags["first_alliance"] = true
	GameState.save_game()
	GameState.emit_signal("state_changed")
	return {"ok": true, "alliance": GameState.alliance}

## 加入赛季联航（北洋旗舰 NPC + 敌联「赤潮联航」对抗）
static func join_season_league(name: String = "北洋联航") -> Dictionary:
	if str(GameState.alliance.get("id", "")) != "":
		return {"ok": false, "reason": "已在联盟中"}
	GameState.alliance = _blank_alliance(
		"AL_SEASON_NORTH",
		name,
		"寒潮旗舰",
		["寒潮旗舰", "霜帆执事", GameState.player_name],
		500
	)
	GameState.alliance["rival_name"] = RIVAL_NAME
	_push_log("赛季开启：对阵 %s" % RIVAL_NAME)
	GameState.tutorial_flags["first_alliance"] = true
	GameState.save_game()
	GameState.emit_signal("state_changed")
	return {"ok": true, "alliance": GameState.alliance}

## 兼容旧调用名
static func join_demo(name: String = "北洋联航") -> Dictionary:
	return join_season_league(name)

static func ensure_enrolled() -> void:
	if str(GameState.alliance.get("id", "")) == "":
		join_season_league()

static func set_tax(rate: float) -> Dictionary:
	if str(GameState.alliance.get("id", "")) == "":
		return {"ok": false, "reason": "无联盟"}
	var r := clampf(rate, 0.0, TAX_CAP)
	GameState.alliance["tax"] = r
	GameState.save_game()
	return {"ok": true, "tax": r}

static func deposit_tax(amount: int) -> void:
	if amount <= 0 or str(GameState.alliance.get("id", "")) == "":
		return
	GameState.alliance["treasury"] = int(GameState.alliance.get("treasury", 0)) + amount

static func contribute(amount: int) -> Dictionary:
	if str(GameState.alliance.get("id", "")) == "":
		return {"ok": false, "reason": "无联盟"}
	if amount <= 0 or GameState.strategic < amount:
		return {"ok": false, "reason": "战略不足"}
	GameState.strategic -= amount
	GameState.alliance["treasury"] = int(GameState.alliance.get("treasury", 0)) + amount
	GameState.save_game()
	GameState.emit_signal("state_changed")
	return {"ok": true, "treasury": GameState.alliance.treasury}

static func record_gvg_win(loot: int, island_id: String = "") -> int:
	if str(GameState.alliance.get("id", "")) == "":
		return 0
	GameState.alliance["gvg_wins"] = int(GameState.alliance.get("gvg_wins", 0)) + 1
	var share_rate := 0.35
	match war_phase():
		"contend":
			share_rate = 0.42
		"peak":
			share_rate = 0.5
	var share := int(floor(loot * share_rate))
	deposit_tax(share)
	var pts := 14 + int(loot / 30)
	if island_id in ["FR_12", "AB_09", "BL_09", "TW_09"]:
		pts += 30
	GameState.alliance["war_score"] = int(GameState.alliance.get("war_score", 0)) + pts
	_push_log("我方突袭 %s 成功 · +%d 战绩" % [island_id if island_id != "" else "据点", pts])
	return pts

static func record_gvg_loss() -> void:
	if str(GameState.alliance.get("id", "")) == "":
		return
	GameState.alliance["gvg_losses"] = int(GameState.alliance.get("gvg_losses", 0)) + 1
	GameState.alliance["rival_score"] = int(GameState.alliance.get("rival_score", 180)) + 2
	_push_log("我方突袭受挫 · 敌联 +2")

## 日推：敌联 AI 行动 + 阶段涨分
static func tick_rival_daily() -> void:
	if str(GameState.alliance.get("id", "")) == "":
		return
	_ensure_war_fields()
	var add := 0
	match war_phase():
		"warmup":
			add = 1
		"contend":
			add = 2
		"peak":
			add = 2
		_:
			add = 0
	if add > 0:
		GameState.alliance["rival_score"] = int(GameState.alliance.get("rival_score", 180)) + add
	_simulate_rival_sortie()

static func _simulate_rival_sortie() -> void:
	var phase := war_phase()
	if phase == "idle":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.day * 9973 + int(GameState.alliance.get("rival_score", 0))
	# 友方 NPC 联航日推：寒潮旗舰出征
	if phase in ["warmup", "contend", "peak"] and rng.randf() < 0.55:
		var ally_pts := 4 + rng.randi_range(0, 5)
		if phase == "peak":
			ally_pts += 3
		GameState.alliance["war_score"] = int(GameState.alliance.get("war_score", 0)) + ally_pts
		_push_log("寒潮旗舰出征 · 我方 +%d" % ally_pts)
	var chance := 0.28
	match phase:
		"contend":
			chance = 0.42
		"peak":
			chance = 0.5
	if rng.randf() > chance:
		return
	var gain := 3 + rng.randi_range(0, 4)
	if phase == "peak":
		gain += 2
	GameState.alliance["rival_score"] = int(GameState.alliance.get("rival_score", 180)) + gain
	GameState.alliance["rival_sorties"] = int(GameState.alliance.get("rival_sorties", 0)) + 1
	var seas: PackedStringArray = ["冻洋", "渊海", "瀚海", "信风"]
	var sea: String = seas[rng.randi() % seas.size()]
	_push_log("%s 突袭%s航线 · 敌绩 +%d" % [RIVAL_NAME, sea, gain])
	if rng.randf() < 0.22:
		var tip := 20 + rng.randi_range(0, 40)
		deposit_tax(tip)
		_push_log("截获敌联辎重 · 金库 +%d" % tip)

static func war_phase() -> String:
	var d := GameState.day
	if d >= 61 and d <= 84:
		return "peak"
	if d >= 55 and d <= 60:
		return "contend"
	if d >= 25 and d <= 54:
		return "warmup"
	return "idle"

static func season_war_snapshot() -> Dictionary:
	_ensure_war_fields()
	var us := int(GameState.alliance.get("war_score", 0))
	var them := int(GameState.alliance.get("rival_score", 0))
	return {
		"phase": war_phase(),
		"war_score": us,
		"rival_score": them,
		"rival_name": str(GameState.alliance.get("rival_name", RIVAL_NAME)),
		"lead": us - them,
		"wins": int(GameState.alliance.get("gvg_wins", 0)),
		"losses": int(GameState.alliance.get("gvg_losses", 0)),
		"rival_sorties": int(GameState.alliance.get("rival_sorties", 0)),
		"log": GameState.alliance.get("war_log", []),
		"claim_ready": us > them and war_phase() == "peak" and not bool(GameState.tutorial_flags.get("war_chest_claimed", false)),
	}

static func claim_war_chest() -> Dictionary:
	var snap: Dictionary = season_war_snapshot()
	if not bool(snap.get("claim_ready", false)):
		return {"ok": false, "reason": "未满足联航战领奖条件（领先且高潮期）"}
	var reward := 400 + int(snap.war_score)
	GameState.add_strategic(reward, "联航战金库")
	GameState.tutorial_flags["war_chest_claimed"] = true
	_push_log("领取联航金库 · +%d" % reward)
	GameState.save_game()
	return {"ok": true, "reward": reward}

static func daily_stamina_bonus() -> int:
	if str(GameState.alliance.get("id", "")) == "":
		return 0
	var b := 10
	if war_phase() == "peak":
		b += 5
	return b

static func member_cap() -> int:
	return BASE_CAP + TechServiceScript.alliance_bonus_cap()

static func leave() -> void:
	GameState.alliance = {}
	GameState.save_game()
	GameState.emit_signal("state_changed")

static func _blank_alliance(id: String, name: String, leader: String, members: Array, treasury: int) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"leader": leader,
		"members": members,
		"tax": 0.03,
		"treasury": treasury,
		"gvg_wins": 0,
		"gvg_losses": 0,
		"war_score": 0,
		"rival_score": 180,
		"rival_name": RIVAL_NAME,
		"rival_sorties": 0,
		"war_log": [],
		"created_day": GameState.day,
	}

static func _push_log(line: String) -> void:
	_ensure_war_fields()
	var log: Array = GameState.alliance.get("war_log", [])
	log.push_front("D%d · %s" % [GameState.day, line])
	while log.size() > LOG_CAP:
		log.pop_back()
	GameState.alliance["war_log"] = log

static func _ensure_war_fields() -> void:
	if str(GameState.alliance.get("id", "")) == "":
		return
	if not GameState.alliance.has("war_score"):
		GameState.alliance["war_score"] = 0
	if not GameState.alliance.has("rival_score"):
		GameState.alliance["rival_score"] = 180
	if not GameState.alliance.has("gvg_losses"):
		GameState.alliance["gvg_losses"] = 0
	if not GameState.alliance.has("rival_name"):
		GameState.alliance["rival_name"] = RIVAL_NAME
	if not GameState.alliance.has("war_log"):
		GameState.alliance["war_log"] = []
	if not GameState.alliance.has("rival_sorties"):
		GameState.alliance["rival_sorties"] = 0
