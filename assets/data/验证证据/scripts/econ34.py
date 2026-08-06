# -*- coding: utf-8 -*-
# econ34：定位 D5 峰值的结构性根因，并验证「可重复 sink」修复方案
#   假设 H1：峰值来自 sink 断崖（造船在第 26 日投满后，当日盈余无处可去）
#   修复 R1：新增「船体改装 refit」——可重复、无总量上限、边际收益递减的常驻 sink
import io, contextlib
import econ31 as E

ADJ, POI, TIER = E.ADJ, E.POI, E.TIER


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


HOPS = {i: hops(i) for i in POI}


def run(invest_rate=0.90, refit=False, adj=0.10, decay_slope=0.06, hoard=0.10):
    """refit=True 时启用可重复 sink：吸收全部剩余可支配盈余的 REFIT_ABSORB 比例"""
    REFIT_ABSORB = 0.85
    DEC = lambda n: max(0.40, 1.0 - decay_slope * (n - 1))
    pool, owned = E.P0, []
    lvl_s = ship_s = refit_s = 0
    peak = 0.0
    series = []
    for d in range(1, 31):
        if d in E.SCHED:
            owned.append(E.SCHED[d])
        sta = E.STAMINA
        battle = 1 if d in E.SCHED and E.SCHED[d] != "FR_01" else 0
        sta -= battle * E.BATTLE_STA
        reach = set(owned)
        for i in list(reach):
            for j in ADJ[i]:
                reach.add(j)
        cand = []
        for i in sorted(reach):
            cc = sum(E.CHARGES[p] for p in POI[i]) * E.POI_STA
            inc = sum(E.CHARGES[p] * E.YIELD_POI[p] for p in POI[i])
            if i == "FR_12" and "FR_12" not in owned:
                inc = 0
            tot = cc + HOPS[i] * E.VOY_STA
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
            yld += round(E.YIELD[TIER[i]] * DEC(k + 1) * (1 + adj * nb))
        upk = sum(E.UPKEEP[TIER[i]] for i in owned)
        gross = poi_inc + yld
        supply = battle * 200 + len(owned) * 30
        disp = max(0, gross - upk - supply)
        budget = int(disp * invest_rate)
        lvl = min(int(budget * 0.78), E.TOTAL_LVL_COST - lvl_s)
        lvl_s += lvl
        shp = min(int(budget * 0.22), E.SHIP_BUILD_TOTAL - ship_s)
        ship_s += shp
        rft = 0
        if refit:
            rft = int((budget - lvl - shp) * REFIT_ABSORB)
            refit_s += rft
        hd = int(max(0, pool - E.SOFT_CAP) * hoard)
        net = gross - upk - supply - lvl - shp - rft - hd
        op = pool
        pool += net
        infl = net / max(1, op) * 100
        peak = max(peak, infl)
        series.append((d, infl, pool, lvl + shp + rft))
    return peak, pool, refit_s, series


if __name__ == "__main__":
    print("=== 表 A · 假设 H1 验证：峰值出现在哪一天，与 sink 耗尽是否同步 ===")
    with contextlib.redirect_stdout(io.StringIO()):
        p, _, _, s = run(invest_rate=0.90, refit=False)
    print(f"{'日':>4}{'日通胀%':>10}{'当日总投入':>12}{'池存':>10}")
    for d, infl, pool, spend in s:
        if d >= 23:
            mark = "  <== 峰值" if abs(infl - p) < 1e-9 else ""
            print(f"{d:>4}{infl:>10.2f}{spend:>12}{pool:>10}{mark}")

    print("\n=== 表 B · 修复 R1（可重复 sink「船体改装」）全投入率区间复跑 ===")
    print(f"{'投入率':>7}{'无 refit 峰值%':>16}{'有 refit 峰值%':>16}{'refit 累计':>12}{'D5':>7}")
    allpass = True
    for r in [round(0.05 * i, 2) for i in range(21)]:
        with contextlib.redirect_stdout(io.StringIO()):
            p0, _, _, _ = run(invest_rate=r, refit=False)
            p1, _, rs, _ = run(invest_rate=r, refit=True)
        ok = p1 <= 5
        allpass &= ok
        if r in (0.0, 0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0):
            print(f"{r:>7.2f}{p0:>16.2f}{p1:>16.2f}{rs:>12}{'PASS' if ok else 'FAIL':>7}")
    print(f"\n全投入率区间 (0.00~1.00, 步长 0.05) 是否全部达标：{'是 ✅' if allpass else '否 ❌'}")
