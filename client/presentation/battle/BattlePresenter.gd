extends RefCounted
class_name BattlePresenter
## 战斗四段式导演（需求文档/02-动画演出/01）：开场→交战→拉锯→终结
## 只消费 ResolveBattle.log，禁止另算胜负

enum Phase { OPENING, ENGAGE, GRIND, FINALE, DONE }

const OPENING_SEC := 0.55
const FINALE_SEC := 0.85
const HIT_DELAY := 0.07
const HIT_DELAY_IRON := 0.11
const HIT_DELAY_WIND := 0.045

static func classify_phase(entry: Dictionary, hit_index: int, total_hits: int) -> int:
	var t := str(entry.get("t", ""))
	if t == "start":
		return Phase.OPENING
	if t == "kill" or hit_index >= maxi(1, int(float(total_hits) * 0.85)):
		return Phase.FINALE if t == "kill" else Phase.GRIND
	if hit_index < maxi(1, int(float(total_hits) * 0.55)):
		return Phase.ENGAGE
	return Phase.GRIND

static func delay_for(entry: Dictionary) -> float:
	var sys := str(entry.get("sys_a", ""))
	match sys:
		"wind":
			return HIT_DELAY_WIND
		"ironwall":
			return HIT_DELAY_IRON
		_:
			return HIT_DELAY

static func phase_label(p: int) -> String:
	match p:
		Phase.OPENING:
			return "开场"
		Phase.ENGAGE:
			return "交战"
		Phase.GRIND:
			return "拉锯"
		Phase.FINALE:
			return "终结"
		_:
			return ""

static func count_hits(log: Array) -> int:
	var n := 0
	for e in log:
		if str(e.get("t", "")) == "hit":
			n += 1
	return n
