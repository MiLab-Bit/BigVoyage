# -*- coding: utf-8 -*-
# cards_audit3：(a) SEG_DECAY 扫描 —— 让克制环指数在两个参考靶上同时 >=1.00
#               (b) 减法护甲项造成的「低费卡对高防目标失效」断层量化与修复方案对比
import verify6 as V

ARMOR_CAP, ARMOR_K = 0.90, 400.0
TARGETS = {"轻甲靶": (30.0, 20), "重甲靶": (80.0, 55)}


def armor_red(d):
    return min(ARMOR_CAP, d / (d + ARMOR_K))


def dpr(atk, seg, tdef, tarmor, decay, mode="sub", k=0.5):
    if mode == "sub":                      # 现状：减法 atk - def*0.5
        base = max(1.0, atk - tdef * k)
    else:                                  # 方案：除法 atk * (1 - def/(def+K2))
        base = atk * (1 - tdef / (tdef + 200.0))
    base *= (1 - armor_red(tdef + tarmor))
    return sum(base * decay ** i for i in range(seg))


def sys_eff(tdef, tarmor, decay, mode="sub"):
    out = {}
    for s in ("flame", "ironwall", "wind", "tide"):
        g = [(c, v) for c, v in V.CARDS.items() if v[0] == s]
        out[s] = sum(dpr(v[2], V.FACE.get(c, 1), tdef, tarmor, decay, mode) / v[1] for c, v in g) / len(g)
    return out


def ring_index(e):
    return (e["flame"] * 1.3) / max(1e-9, e["wind"] / 1.3)


if __name__ == "__main__":
    print("=== 表 7 · SEG_DECAY 扫描：克制环指数需在两靶上同时 >= 1.00 ===")
    print(f"{'SEG_DECAY':>10}{'轻甲靶指数':>12}{'重甲靶指数':>12}{'轻甲极差':>10}{'重甲极差':>10}{'判定':>8}")
    # ★ BUGFIX 2026-08-02（BV-Finalize）：原实现为
    #     if ok and best is None: best = d
    #   在升序扫描中取到的是【第一个】PASS，即扫描区间的【最小】通过值（恰好等于下界 0.15），
    #   却被打印成「最大 SEG_DECAY」，导致 COMPILATION-REPORT §8.1 误判"正文 0.40 与脚本自相矛盾"。
    #   实际表格 0.15~0.40 全 PASS，最大通过值是 0.40（细扫见 cards_audit4.py：真实上界 0.43）。
    passing = []
    for d10 in range(15, 65, 5):
        d = d10 / 100
        ea, eb = sys_eff(30.0, 20, d), sys_eff(80.0, 55, d)
        ia, ib = ring_index(ea), ring_index(eb)
        sa = max(ea.values()) / min(ea.values())
        sb = max(eb.values()) / min(eb.values())
        ok = ia >= 1.0 and ib >= 1.0
        if ok:
            passing.append(d)
        print(f"{d:>10.2f}{ia:>12.2f}{ib:>12.2f}{sa:>10.2f}{sb:>10.2f}{'PASS' if ok else 'FAIL':>8}")
    if passing:
        lo, hi = min(passing), max(passing)
        print(f"\n通过区间 = [{lo:.2f}, {hi:.2f}]（本扫描步长 0.05，下界受 range 起点限制）")
        print(f"满足两靶同时达标的最大 SEG_DECAY = {hi:.2f}"
              f"（现行提案 0.60 -> {'需下调' if hi < 0.60 else '可保持'}）")
        print("细粒度上界见 cards_audit4.py（步长 0.01，实测真实上界 = 0.43）")
    else:
        print("\n无通过值")

    print("\n=== 表 8 · 减法护甲项造成的低费卡断层，及两种修复方案 ===")
    print(f"{'方案':<28}{'R 卡重甲/轻甲效率比':>22}{'UR 卡同比':>12}{'断层倍数':>10}")
    for name, kw in [("现状 atk − def×0.50", dict(mode="sub", k=0.50)),
                     ("温和 atk − def×0.30", dict(mode="sub", k=0.30)),
                     ("温和 atk − def×0.20", dict(mode="sub", k=0.20)),
                     ("改除法 atk×(1−def/(def+200))", dict(mode="div"))]:
        def eff(rar, td, ta):
            g = [(c, v) for c, v in V.CARDS.items() if c.split("_")[1] == rar]
            return sum(dpr(v[2], V.FACE.get(c, 1), td, ta, 0.60, **kw) / v[1] for c, v in g) / len(g)
        r = eff("R", 80.0, 55) / max(1e-9, eff("R", 30.0, 20))
        u = eff("UR", 80.0, 55) / max(1e-9, eff("UR", 30.0, 20))
        print(f"{name:<28}{r:>22.3f}{u:>12.3f}{u/max(1e-9,r):>10.1f}")
    print("\n断层倍数 = UR 的跨靶保值率 ÷ R 的跨靶保值率；=1 表示稀有度与靶护甲解耦（理想）")
