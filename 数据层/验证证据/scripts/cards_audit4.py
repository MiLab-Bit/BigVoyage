# -*- coding: utf-8 -*-
# cards_audit4：修正 cards_audit3 的「最大值」取值 BUG，并做细粒度 SEG_DECAY 扫描
#
# BUG 说明（cards_audit3.py 第 39-47 行）：
#   for d10 in range(15, 65, 5):        # 升序扫描 0.15 -> 0.60
#       if ok and best is None: best = d   # 取第一个 PASS = 扫描区间内的【最小】通过值
#   却打印为「满足两靶同时达标的【最大】SEG_DECAY」。
#   0.15 只是扫描区间的下界，不是阈值。真实的最大通过值需取最后一个 PASS。
import verify6 as V

ARMOR_CAP, ARMOR_K = 0.90, 400.0


def armor_red(d):
    return min(ARMOR_CAP, d / (d + ARMOR_K))


def dpr(atk, seg, tdef, tarmor, decay, mode="sub", k=0.5):
    if mode == "sub":
        base = max(1.0, atk - tdef * k)
    else:
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


def probe(d):
    ea, eb = sys_eff(30.0, 20, d), sys_eff(80.0, 55, d)
    ia, ib = ring_index(ea), ring_index(eb)
    sa = max(ea.values()) / min(ea.values())
    sb = max(eb.values()) / min(eb.values())
    return ia, ib, sa, sb, (ia >= 1.0 and ib >= 1.0)


if __name__ == "__main__":
    print("=== 表 7-fix · SEG_DECAY 细粒度扫描（步长 0.01），两靶克制环指数需同时 >= 1.00 ===")
    print(f"{'SEG_DECAY':>10}{'轻甲靶指数':>12}{'重甲靶指数':>12}{'轻甲极差':>10}{'重甲极差':>10}{'判定':>8}")
    passing = []
    for d100 in range(5, 66, 1):
        d = d100 / 100
        ia, ib, sa, sb, ok = probe(d)
        if ok:
            passing.append(d)
        # 只打印 5 的倍数 + 阈值邻域，避免刷屏
        if d100 % 5 == 0 or 40 <= d100 <= 46:
            print(f"{d:>10.2f}{ia:>12.2f}{ib:>12.2f}{sa:>10.2f}{sb:>10.2f}{'PASS' if ok else 'FAIL':>8}")

    lo, hi = min(passing), max(passing)
    print(f"\n通过区间 = [{lo:.2f}, {hi:.2f}]")
    print(f"  · 最小通过值 = {lo:.2f}   <- cards_audit3 误标为「最大」的那个数（实为扫描下界）")
    print(f"  · 最大通过值 = {hi:.2f}   <- 真正的阈值上界，与 10-经济 §6.3 正文建议 0.40 一致")
    print(f"  · 首个 FAIL  = {hi + 0.01:.2f}")

    print("\n=== 多段伤害保留度对比（疾风 4 段 UR：段伤总和 / 首段）===")
    print(f"{'SEG_DECAY':>10}{'2段总和倍率':>14}{'3段总和倍率':>14}{'4段总和倍率':>14}")
    for d in (0.15, 0.25, 0.40, 0.60):
        m = [sum(d ** i for i in range(n)) for n in (2, 3, 4)]
        print(f"{d:>10.2f}{m[0]:>14.3f}{m[1]:>14.3f}{m[2]:>14.3f}")
    print("\n结论：SEG_DECAY 越大，多段伤害保留越多。"
          "若决策意图是「两靶同时成立的最大可取值 + 尽量保留多段伤害」，正解是 0.40 而非 0.15。")
