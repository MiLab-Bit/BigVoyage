# -*- coding: utf-8 -*-
# econ32：GDD-04 边界情况 E8 / E9 与 6.5 ADJ_BONUS 调参的实跑验证
import importlib, io, contextlib
import econ31 as E


def run(no_boss=False, invest_rate=0.90, adj=0.10, decay_slope=0.06, hoard=0.10):
    POI, ADJ, TIER = E.POI, E.ADJ, E.TIER
    CH, YP = E.CHARGES, E.YIELD_POI
    YIELD, UPKEEP, DIVTID = E.YIELD, E.UPKEEP, E.DIVTID
    SCHED = dict(E.SCHED)
    if no_boss:
        SCHED = {d: i for d, i in SCHED.items() if i != "FR_12"}
    DEC = lambda n: max(0.40, 1.0 - decay_slope * (n - 1))

    def bfs(o):
        s = set(o)
        for i in list(s):
            for j in ADJ[i]:
                s.add(j)
        return s

    def hops(t):
        d = {"FR_01": 0}
        q = ["FR_01"]
        while q:
            c = q.pop(0)
            for n in ADJ[c]:
                if n not in d:
                    d[n] = d[c] + 1
                    q.append(n)
        return d.get(t, 99)

    pool, owned, tide = E.P0, [], 0
    lvl_s = ship_s = 0
    peak = 0.0
    for d in range(1, 31):
        if d in SCHED:
            owned.append(SCHED[d])
        sta = E.STAMINA
        battle = 1 if d in SCHED and SCHED[d] != "FR_01" else 0
        sta -= battle * E.BATTLE_STA
        cand = []
        for i in sorted(bfs(owned)):
            cc = sum(CH[p] for p in POI[i]) * E.POI_STA
            inc = sum(CH[p] * YP[p] for p in POI[i])
            if i == "FR_12" and "FR_12" not in owned:
                inc = 0
            tot = cc + hops(i) * E.VOY_STA
            cand.append((inc / max(1, tot), i, tot, inc))
        cand.sort(reverse=True)
        poi_inc = 0
        for _, i, c, inc in cand:
            if sta >= c:
                sta -= c
                poi_inc += inc
        yld = 0
        for k, i in enumerate(owned):
            nb = sum(1 for j in ADJ[i] if j in owned)
            yld += round(YIELD[TIER[i]] * DEC(k + 1) * (1 + adj * nb))
        upk = sum(UPKEEP[TIER[i]] for i in owned)
        tide += sum(DIVTID[TIER[i]] for i in owned)
        gross = poi_inc + yld
        supply = battle * 200 + len(owned) * 30
        disp = max(0, gross - upk - supply)
        lvl = min(int(disp * invest_rate * 0.78), E.TOTAL_LVL_COST - lvl_s)
        lvl_s += lvl
        shp = min(int(disp * invest_rate * 0.22), E.SHIP_BUILD_TOTAL - ship_s)
        ship_s += shp
        hd = int(max(0, pool - E.SOFT_CAP) * hoard)
        net = gross - upk - supply - lvl - shp - hd
        op = pool
        pool += net
        peak = max(peak, net / max(1, op) * 100)
    return peak, pool, tide


CASES = [
    ("基线（复现 econ31 口径）", dict()),
    ("E8 · Boss 岛始终无主", dict(no_boss=True)),
    ("E9 · 玩家 100% 囤积（零投入）", dict(invest_rate=0.0)),
    ("E9b · 囤积且关掉囤积衰减", dict(invest_rate=0.0, hoard=0.0)),
    ("6.5 ADJ_BONUS=0.25（不改衰减）", dict(adj=0.25)),
    ("6.5 ADJ=0.25 + DECAY 斜率 0.075", dict(adj=0.25, decay_slope=0.075)),
]

if __name__ == "__main__":
    res = []
    for name, kw in CASES:
        with contextlib.redirect_stdout(io.StringIO()):
            res.append((name, run(**kw)))
    print(f"{'情形':<32}{'峰值日通胀%':>13}{'30日末池':>11}{'$TIDE':>8}{'D5':>7}")
    for n, r in res:
        print(f"{n:<32}{r[0]:>13.2f}{r[1]:>11}{r[2]:>8}{'PASS' if r[0] <= 5 else 'FAIL':>7}")
