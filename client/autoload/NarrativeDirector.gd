extends Node
## 叙事章节导演：关键帧过场（大沉没→黄金彼岸→…）
## 资产：AssetDB.narrative / sfx_nar_*

signal chapter_finished(chapter_id: String)

const CHAPTERS := {
	"prologue": {
		"title": "大沉没",
		"frames": [
			{"art": "nar_great_sinking", "line": "世界沉没。洋流重新书写航线。", "sfx": "sfx_nar_cutscene_start"},
			{"art": "nar_golden_shore", "line": "传说中的黄金彼岸，仍在潮汐尽头。", "sfx": "sfx_nar_chapter_title"},
			{"art": "nar_compass_ritual", "line": "罗盘苏醒——你是被选中的掌舵者。", "sfx": "sfx_nar_choir"},
		],
	},
	"first_sail": {
		"title": "初航",
		"frames": [
			{"art": "nar_compass_ritual", "line": "第一道航迹切开雾墙。海开始记住你的名字。", "sfx": "sfx_nar_leit_wind"},
		],
	},
	"first_trade": {
		"title": "通商",
		"frames": [
			{"art": "nar_harbor_rebuild", "line": "货舱入港，关税入账。贸易是另一种战争。", "sfx": "sfx_nar_leit_iron"},
		],
	},
	"first_tech": {
		"title": "研索",
		"frames": [
			{"art": "nar_tide_core", "line": "图纸展开。每一分战略，都在改写下一场海战的系数。", "sfx": "sfx_nar_chapter_title"},
		],
	},
	"alliance_join": {
		"title": "联航旗号",
		"frames": [
			{"art": "nar_harbor_rebuild", "line": "北洋联航升起旗号。赤潮那边，也听见了鼓点。", "sfx": "sfx_nar_choir"},
		],
	},
	"war_chest": {
		"title": "金库开封",
		"frames": [
			{"art": "nar_golden_shore", "line": "联航金库开封。这一季的血与税，兑成下一程补给。", "sfx": "sfx_nar_leit_tide"},
		],
	},
	"abyss_enter": {
		"title": "渊海门槛",
		"frames": [
			{"art": "nar_sea_emperor_herald", "line": "冻洋退到身后。渊海的黑水，不欢迎观光客。", "sfx": "sfx_nar_boss_herald"},
		],
	},
	"tide_core": {
		"title": "潮汐之核",
		"frames": [
			{"art": "nar_tide_core", "line": "潮核脉动，海域意志苏醒。", "sfx": "sfx_nar_leit_tide"},
		],
	},
	"boss_herald": {
		"title": "海皇预兆",
		"lock_skip": true,
		"frames": [
			{"art": "nar_sea_emperor_herald", "line": "渊眼睁开。海皇的使者在注视你。", "sfx": "sfx_nar_boss_herald"},
			{"art": "nar_sea_emperor_herald", "line": "失守之卫苏醒——踏入终核岛，即向深渊宣战。", "sfx": "sfx_nar_choir"},
		],
	},
	"boss_clash": {
		"title": "海皇之战",
		"lock_skip": true,
		"frames": [
			{"art": "nar_sea_emperor_herald", "line": "星渊巨兽抬起脊背。这一战，胜负在出航前已写定。", "sfx": "sfx_nar_boss_herald"},
		],
	},
	"harbor": {
		"title": "港湾重建",
		"frames": [
			{"art": "nar_harbor_rebuild", "line": "占领即秩序。港口将记住你的旗帜。", "sfx": "sfx_nar_leit_iron"},
		],
	},
}

var _busy := false

func play_chapter(chapter_id: String, on_done: Callable = Callable()) -> void:
	if _busy:
		return
	if not App.flag("narrative", true):
		if on_done.is_valid():
			on_done.call()
		return
	var ch: Dictionary = CHAPTERS.get(chapter_id, {})
	if ch.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_busy = true
	var scene: CanvasLayer = preload("res://ui/NarrativeCutscene.tscn").instantiate()
	get_tree().root.add_child(scene)
	await scene.play(ch)
	_busy = false
	GameState.tutorial_flags["nar_%s" % chapter_id] = true
	GameState.save_game()
	chapter_finished.emit(chapter_id)
	if on_done.is_valid():
		on_done.call()

## 仅首次触发；不打断时返回 false
func try_chapter(chapter_id: String) -> bool:
	if bool(GameState.tutorial_flags.get("nar_%s" % chapter_id, false)):
		return false
	if _busy:
		return false
	if not CHAPTERS.has(chapter_id):
		return false
	play_chapter(chapter_id)
	return true

func play_prologue_then(cb: Callable) -> void:
	if bool(GameState.tutorial_flags.get("nar_prologue", false)):
		if cb.is_valid():
			cb.call()
		return
	await play_chapter("prologue", cb)
