extends RefCounted
class_name DisplayNames
## C-6：角色 ID / 机制名 / 真名（设定集）

const SHAPE := {"flame": "▲", "ironwall": "▣", "wind": "◆", "tide": "●"}

const TRUE_NAME := {
	"FLAME_R_01": "燧生",
	"FLAME_R_02": "燎帆",
	"FLAME_SR_01": "范铸",
	"FLAME_SSR_01": "赤焰",
	"FLAME_UR_01": "祝融之裔",
	"IRON_R_01": "铁砧",
	"IRON_R_02": "玄铁",
	"IRON_SR_01": "督战",
	"IRON_SSR_01": "山岳守望",
	"IRON_UR_01": "霜铁之王",
	"WIND_R_01": "信风",
	"WIND_R_02": "疾羽",
	"WIND_SR_01": "游骑",
	"WIND_SSR_01": "长风破阵",
	"WIND_UR_01": "追风之翼",
	"TIDE_R_01": "潮歌",
	"TIDE_R_02": "渊潮",
	"TIDE_SR_01": "深渊回响",
	"TIDE_SSR_01": "海皇低语",
	"TIDE_UR_01": "波塞冬·深渊之主",
}

static func for_card(card_id: String) -> Dictionary:
	var c: Dictionary = {}
	if Engine.get_main_loop() != null:
		var gd = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameData")
		if gd != null and gd.cards.has(card_id):
			c = gd.cards[card_id]
	var mechanism := str(c.get("name", card_id))
	var true_name := str(TRUE_NAME.get(card_id, ""))
	var sys := str(c.get("system", ""))
	return {
		"id": card_id,
		"mechanism": mechanism,
		"true_name": true_name,
		"archetype": str(c.get("archetype", "")),
		"system": sys,
		"shape": SHAPE.get(sys, "•"),
		"display": true_name if true_name != "" else mechanism,
		"line": ("%s（%s）" % [true_name, mechanism]) if true_name != "" else mechanism,
	}

static func display(card_id: String) -> String:
	return str(for_card(card_id).get("display", card_id))

static func shape(sys: String) -> String:
	return str(SHAPE.get(sys, "•"))
