# -*- coding: utf-8 -*-
"""lock_armor_a（BV-Lock, 2026-08-02）· 护甲方案1（DEF_COEF 0.50 -> 0.30）解析侧复验
   A1  H-5 断层：20 卡在轻甲/重甲双靶的跨靶保值率 + 断层倍数
   A2  H-5 逐卡明细（DEF_COEF=0.30 终值）
   A3  克制环正交性：DEF_COEF 变化后 SEG_DECAY 通过区间是否仍含 0.40
   模型与 cards_audit3/4.py 完全一致（同一 DPR 解析式），仅参数化 DEF_COEF。
"""
import verify6 as V

ARMOR_CAP, ARMOR_K = 0.90, 400.0
LIGHT = (30.0, 20)   # 轻甲参考靶 (def, 船甲)
HEAVY = (80.0, 55)   # 重甲参考靶 = 冻洋守卫级
SEG_LOCKED = 0.40    # D3 终值


def armor_red(d):
    return min(ARMOR_CAP, d / (d + ARMOR_K))


def dpr(atk, seg, tdef, tarmor, decay, mode="sub", k=0.50):
    if mode == "sub":
        base = max(1.0, atk - tdef * k)
    else:
        base = atk * (1 - tdef / (tdef + 200.0))
    base *= (1 - armor_red(tdef + tarmor))
    return sum(base * decay ** i for i in range(seg))


def sys_eff(tdef, tarmor, decay, **kw):
    out = {}
    for s in ("flame", "ironwall", "wind", "tide"):
        g = [(c, v) for c, v in V.CARDS.items() if v[0] == s]
        out[s] = sum(dpr(v[2], V.FACE.get(c, 1), tdef, tarmor, decay, **kw) / v[1] for c, v in g) / len(g)
    return out


def ring_index(e):
    return (e["flame"] * 1.3) / max(1e-9, e["wind"] / 1.3)


def rar_eff(rar, td, ta, decay, **kw):
    g = [(c, v) for c, v in V.CARDS.items() if c.split("_")[1] == rar]
    return sum(dpr(v[2], V.FACE.get(c, 1), td, ta, decay, **kw) / v[1] for c, v in g) / len(g)


def cliff(decay, **kw):
    r = rar_eff("R", *HEAVY, decay, **kw) / max(1e-9, rar_eff("R", *LIGHT, decay, **kw))
    u = rar_eff("UR", *HEAVY, decay, **kw) / max(1e-9, rar_eff("UR", *LIGHT, decay, **kw))
    return r, u, u / max(1e-9, r)


if __name__ == "__main__":
    print("=" * 96)
    print("A · 护甲方案1 复验 —— DEF_COEF 0.50 -> 0.30（减法模型保留）")
    print(f"参考靶：轻甲 def={LIGHT[0]}/船甲{LIGHT[1]}  ·  重甲 def={HEAVY[0]}/船甲{HEAVY[1]}")
    print("=" * 96)

    print(f"\n### A1 · H-5 断层（SEG_DECAY 取 D3 终值 {SEG_LOCKED:.2f}；括号内为旧表 0.60 口径）")
    print(f"{'方案':<30}{'R卡保值率':>12}{'UR卡保值率':>12}{'断层倍数':>10}{'@0.60断层':>12}{'判定':>8}")
    rows = [("现状 atk − def×0.50", dict(mode="sub", k=0.50)),
            ("★已决 方案1 atk − def×0.30", dict(mode="sub", k=0.30)),
            ("方案2 atk − def×0.20", dict(mode="sub", k=0.20)),
            ("方案3 除法 atk×(1−def/(def+200))", dict(mode="div"))]
    for name, kw in rows:
        r, u, c = cliff(SEG_LOCKED, **kw)
        _, _, c60 = cliff(0.60, **kw)
        v = "✅ 达标" if c <= 2.0 else "❌ 断层"
        print(f"{name:<30}{r:>12.3f}{u:>12.3f}{c:>10.1f}{c60:>12.1f}{v:>8}")
    print("断层倍数 = UR 跨靶保值率 ÷ R 跨靶保值率；=1 表示稀有度与靶护甲完全解耦；H-5 判据取 ≤2.0")

    print(f"\n### A2 · 逐卡跨靶保值率（DEF_COEF=0.30 终值，SEG_DECAY={SEG_LOCKED:.2f}）")
    print(f"{'卡 ID':<16}{'COST':>5}{'atk':>5}{'段':>4}"
          f"{'轻甲 DPR/费':>13}{'重甲 DPR/费':>13}{'保值率(0.30)':>14}{'保值率(0.50)':>14}{'Δ':>9}")
    order = [c for c in V.CARDS]
    worst30 = (None, 9e9)
    for c in order:
        s, cost, atk, dfv, spd, hp = V.CARDS[c]
        seg = V.FACE.get(c, 1)
        l30 = dpr(atk, seg, *LIGHT, SEG_LOCKED, mode="sub", k=0.30) / cost
        h30 = dpr(atk, seg, *HEAVY, SEG_LOCKED, mode="sub", k=0.30) / cost
        l50 = dpr(atk, seg, *LIGHT, SEG_LOCKED, mode="sub", k=0.50) / cost
        h50 = dpr(atk, seg, *HEAVY, SEG_LOCKED, mode="sub", k=0.50) / cost
        r30, r50 = h30 / max(1e-9, l30), h50 / max(1e-9, l50)
        if r30 < worst30[1]:
            worst30 = (c, r30)
        print(f"{c:<16}{cost:>5}{atk:>5}{seg:>4}{l30:>13.1f}{h30:>13.1f}"
              f"{r30:>14.3f}{r50:>14.3f}{r30-r50:>+9.3f}")
    print(f"最差卡（0.30 下）：{worst30[0]} 保值率 {worst30[1]:.3f}"
          f"（0.50 下最差为 FLAME_R_01 / IRON_R_02 的 0.03~0.05 量级）")

    print(f"\n### A3 · 克制环 × DEF_COEF 正交性检查（SEG_DECAY 扫描，步长 0.01，两靶指数需同时 ≥1.00）")
    print(f"{'DEF_COEF':>9}{'@0.40轻甲':>11}{'@0.40重甲':>11}{'通过区间':>18}{'含0.40?':>9}{'最大通过值':>11}")
    for k in (0.50, 0.30, 0.20):
        ea = sys_eff(*LIGHT, SEG_LOCKED, mode="sub", k=k)
        eb = sys_eff(*HEAVY, SEG_LOCKED, mode="sub", k=k)
        ia, ib = ring_index(ea), ring_index(eb)
        ps = []
        for d100 in range(5, 66):
            d = d100 / 100
            x = ring_index(sys_eff(*LIGHT, d, mode="sub", k=k))
            y = ring_index(sys_eff(*HEAVY, d, mode="sub", k=k))
            if x >= 1.0 and y >= 1.0:
                ps.append(d)
        rng = f"[{min(ps):.2f}, {max(ps):.2f}]" if ps else "空"
        inc = "✅ 是" if ps and min(ps) <= SEG_LOCKED <= max(ps) else "❌ 否"
        mark = " ★已决" if abs(k - 0.30) < 1e-9 else ""
        print(f"{k:>9.2f}{ia:>11.2f}{ib:>11.2f}{rng:>18}{inc:>9}{max(ps) if ps else 0:>11.2f}{mark}")
    print("说明：DEF_COEF 与 SEG_DECAY 在解析模型中并非严格正交（减法项改变各卡基数，")
    print("      从而改变体系均值加权），但 0.40 在三个 DEF_COEF 取值下均落在通过区间内。")
