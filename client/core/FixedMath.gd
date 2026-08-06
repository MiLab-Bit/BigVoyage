extends RefCounted
class_name FixedMath
## 十进制定点算术（SCALE=10000）——对齐 battle-core-zk-readiness-audit §2
## 中间量用 int（GDScript 64-bit）；电路侧对应 u64。

const SCALE := 10000
const RESTRAINT_FP := 13000  # 1.3 · 禁止预存 1/1.3

## half-away-from-zero（n≥0, d>0）：round_div(n,d) = (2n+d)/(2d)
static func round_div(n: int, d: int) -> int:
	if d <= 0:
		return 0
	if n < 0:
		return -round_div(-n, d)
	return (2 * n + d) / (2 * d)

## float JSON → 定点（仅加载期；结算内禁止 float）
static func from_float(f: float) -> int:
	return int(round(f * float(SCALE)))

## a(单位) × b_fp → 单位，四舍五入
static func mul_unit(a: int, b_fp: int) -> int:
	return round_div(a * b_fp, SCALE)

## a_fp × b_fp → fp
static func mul_fp(a_fp: int, b_fp: int) -> int:
	return round_div(a_fp * b_fp, SCALE)

## 克制优势：raw × 1.3
static func apply_restraint_adv(raw: int) -> int:
	return round_div(raw * RESTRAINT_FP, SCALE)

## 克制劣势：raw / 1.3（对称环：必须除 RESTRAINT，禁止预存 7692）
static func apply_restraint_disadv(raw: int) -> int:
	return raw * SCALE / RESTRAINT_FP

## 护甲比 floor：def/(def+100) → fp in [0, SCALE)
static func armor_ratio_fp(defense: int) -> int:
	return defense * SCALE / (defense + 100)
