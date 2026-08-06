# -*- coding: utf-8 -*-
# cards_audit：从真实 cards.json 生成 20 卡数值体系表与平衡假设审计
#   指标定义：
#     DPR_ref  = 对参考靶（def=80, heavy 甲, 无克制）的每回合期望伤害，含修正案 C 段衰减
#     EHP_ref  = hp / (1 - armor_reduction(def_eff))   等效生命
#     VAL      = sqrt(DPR_ref * EHP_ref)               综合战力（攻守几何均值）
import json, math
import verify6 as V

SEG_DECAY = 0.60
REF_DEF = 80.0
REF_ARMOR = 55  # SHIP_IRON heavy 参考靶护甲
ARMOR_CAP = 0.90
ARMOR_K = 400.0


def armor_red(dfv):
    return min(ARMOR_CAP, dfv / (dfv + ARMOR_K))


def dpr(atk, spd, seg):
    n = seg
    base = max(1.0, atk - REF_DEF * 0.5)
    base *= (1 - armor_red(REF_DEF + REF_ARMOR))
    return sum(base * SEG_DECAY ** k for k in range(n))


def ehp(hp, dfv):
    return hp / max(0.10, 1 - armor_red(dfv))


SYSNAME = {"flame": "烈焰", "ironwall": "铁壁", "wind": "疾风", "tide": "潮汐"}
RAR = {"R": "R", "SR": "SR", "SSR": "SSR", "UR": "UR"}

rows = []
for cid, (s, cost, atk, dfv, spd, hp) in V.CARDS.items():
    rar = cid.split("_")[1]
    seg = V.FACE.get(cid, 1)
    d = dpr(atk, spd, seg)
    e = ehp(hp, dfv)
    val = math.sqrt(d * e)
    rows.append((s, cost, cid, rar, atk, dfv, spd, hp, seg, d, e, val, val / cost, d / cost, e / cost))

order = {"flame": 0, "ironwall": 1, "wind": 2, "tide": 3}
rows.sort(key=lambda r: (order[r[0]], r[1], r[2]))

print("=== 表 1 · 20 卡数值体系（真实 cards.json + 修正案 C 段数）===")
print(f"{'体系':<6}{'卡ID':<16}{'稀有':<5}{'COST':>5}{'atk':>5}{'def':>5}{'spd':>5}{'hp':>6}"
      f"{'段':>3}{'DPR':>8}{'EHP':>8}{'战力':>8}{'战力/费':>9}")
for r in rows:
    print(f"{SYSNAME[r[0]]:<6}{r[2]:<16}{r[3]:<5}{r[1]:>5}{r[4]:>5}{r[5]:>5}{r[6]:>5}{r[7]:>6}"
          f"{r[8]:>3}{r[9]:>8.1f}{r[10]:>8.0f}{r[11]:>8.1f}{r[12]:>9.1f}")

print("\n=== 表 2 · 稀有度效率审计（每 COST 战力，检验「UR 是否不如两张 R」）===")
print(f"{'稀有度':<7}{'张数':>5}{'平均COST':>9}{'平均战力':>10}{'平均战力/费':>12}{'相对R':>8}")
base = None
for rar in ("R", "SR", "SSR", "UR"):
    g = [r for r in rows if r[3] == rar]
    ac = sum(x[1] for x in g) / len(g)
    av = sum(x[11] for x in g) / len(g)
    ae = sum(x[12] for x in g) / len(g)
    if base is None:
        base = ae
    print(f"{rar:<7}{len(g):>5}{ac:>9.2f}{av:>10.1f}{ae:>12.1f}{ae/base:>8.2f}")

print("\n=== 表 3 · 体系效率审计（检验克制环是否被数值反转）===")
print(f"{'体系':<7}{'张数':>5}{'平均战力/费':>12}{'DPR/费':>9}{'EHP/费':>9}{'定位':>10}")
for s in ("flame", "ironwall", "wind", "tide"):
    g = [r for r in rows if r[0] == s]
    print(f"{SYSNAME[s]:<7}{len(g):>5}{sum(x[12] for x in g)/len(g):>12.1f}"
          f"{sum(x[13] for x in g)/len(g):>9.1f}{sum(x[14] for x in g)/len(g):>9.0f}"
          f"{'':>10}")
vals = {s: sum(r[12] for r in rows if r[0] == s) / 5 for s in order}
mx, mn = max(vals.values()), min(vals.values())
print(f"\n体系极差 = {mx/mn:.2f}  (目标 <=1.35)  -> {'PASS' if mx/mn <= 1.35 else 'FAIL'}")
