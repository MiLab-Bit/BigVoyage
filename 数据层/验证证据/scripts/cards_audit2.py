# -*- coding: utf-8 -*-
# cards_audit2：双参考靶对照 —— 定位「UR 效率最高 / 最低」两派结论的分歧根因
#   靶 A 轻甲（def=30, 船甲 20，木筏级）   靶 B 重甲（def=80, 船甲 55，冻洋守卫级）
import math
import verify6 as V

SEG_DECAY, ARMOR_CAP, ARMOR_K = 0.60, 0.90, 400.0
TARGETS = {"轻甲靶(def30/甲20)": (30.0, 20), "重甲靶(def80/甲55)": (80.0, 55)}


def armor_red(d):
    return min(ARMOR_CAP, d / (d + ARMOR_K))


def dpr(atk, seg, tdef, tarmor):
    base = max(1.0, atk - tdef * 0.5) * (1 - armor_red(tdef + tarmor))
    return sum(base * SEG_DECAY ** k for k in range(seg))


SYS = {"flame": "烈焰", "ironwall": "铁壁", "wind": "疾风", "tide": "潮汐"}

if __name__ == "__main__":
    print("=== 表 4 · 稀有度「每 COST 输出效率」对参考靶护甲的敏感度 ===")
    print(f"{'靶':<20}{'R':>9}{'SR':>9}{'SSR':>9}{'UR':>9}{'UR/R':>8}{'结论':>26}")
    for tn, (td, ta) in TARGETS.items():
        eff = {}
        for rar in ("R", "SR", "SSR", "UR"):
            g = [(c, v) for c, v in V.CARDS.items() if c.split("_")[1] == rar]
            eff[rar] = sum(dpr(v[2], V.FACE.get(c, 1), td, ta) / v[1] for c, v in g) / len(g)
        ratio = eff["UR"] / max(1e-9, eff["R"])
        verdict = "UR 明显更强" if ratio > 1.5 else ("R 更划算" if ratio < 0.9 else "基本等价")
        print(f"{tn:<20}{eff['R']:>9.1f}{eff['SR']:>9.1f}{eff['SSR']:>9.1f}{eff['UR']:>9.1f}"
              f"{ratio:>8.2f}{verdict:>26}")

    print("\n=== 表 5 · 单卡对两靶的输出效率（暴露双峰断层）===")
    print(f"{'卡ID':<16}{'费':>3}{'atk':>5}{'轻甲 DPR/费':>13}{'重甲 DPR/费':>13}{'衰减倍率':>10}")
    rows = sorted(V.CARDS.items(), key=lambda kv: (kv[1][1], kv[0]))
    for cid, v in rows:
        s, cost, atk, dfv, spd, hp = v
        seg = V.FACE.get(cid, 1)
        a = dpr(atk, seg, 30.0, 20) / cost
        b = dpr(atk, seg, 80.0, 55) / cost
        print(f"{cid:<16}{cost:>3}{atk:>5}{a:>13.1f}{b:>13.1f}{b/max(1e-9,a):>10.3f}")

    print("\n=== 表 6 · 体系「每 COST 输出效率」×靶（克制环有效性检验）===")
    print(f"{'靶':<20}{'烈焰':>8}{'铁壁':>8}{'疾风':>8}{'潮汐':>8}{'极差':>7}{'克制环指数':>11}")
    for tn, (td, ta) in TARGETS.items():
        e = {}
        for s in ("flame", "ironwall", "wind", "tide"):
            g = [(c, v) for c, v in V.CARDS.items() if v[0] == s]
            e[s] = sum(dpr(v[2], V.FACE.get(c, 1), td, ta) / v[1] for c, v in g) / len(g)
        # 冻洋守卫为 ironwall：烈焰克铁壁(×1.3)，铁壁克疾风 → 疾风被克(÷1.3)
        idx = (e["flame"] * 1.3) / max(1e-9, e["wind"] / 1.3)
        spread = max(e.values()) / max(1e-9, min(e.values()))
        print(f"{tn:<20}{e['flame']:>8.1f}{e['ironwall']:>8.1f}{e['wind']:>8.1f}{e['tide']:>8.1f}"
              f"{spread:>7.2f}{idx:>11.2f}")
    print("\n克制环指数 = (烈焰效率×1.3) / (疾风效率÷1.3)，应 > 1.00 才说明克制环没被数值反转")
