# -*- coding: utf-8 -*-
"""sim_r1_scan（主理人, 2026-08-02）· 三维扫描找 stat_table_version 补丁

目标：FR_12(Lv4, gm1.15, hm1.35) ∈ [5,15] 且 胜方含烈焰 ≤ 85%。
结论（2026-08-02）：三维/四维扫描均 0 通过 —— 该判据与"铁壁 B3 仅被烈焰克制"结构性耦合，是死判据；
跨 12 真实守卫聚合烈焰占比 79.4%≈基线，无全局主导。详见 r1_dominance_diagnostic.md。
三个可调维度（均属 stat_table_version 数据层，不碰战斗常量 / 不触发 ruleset_hash 重冻）：
  - flame_atk_mult     : 所有 flame 卡 atk 乘子
  - flame_dot_mult     : 所有 flame 卡 DoT 率乘子
  - restraint_fi       : flame→ironwall 克制优势系数（覆盖 C["RESTRAINT"] 该单一配对）

复刻锁链测量协议：gm=1.15 hm=1.35 cap=0.80 seg=0.40 def_coef=0.30(D13②) + R1 独占全开。
分阶段：Phase A 粗扫（采样舰队）定位可行区；Phase B 对通过项跑全量 11,443 复核。
"""
import time, sys, random
from collections import defaultdict
import bv_engine as E

SEG, CAP, HM, GM, DEF_COEF = 0.40, 0.80, 1.35, 1.15, 0.30
BASE = "C:/Users/Administrator/AppData/Local/Temp/bv/"
CD = __import__("json").load(open(BASE + "data_cards.json", encoding="utf-8"))
CARDS = {c["id"]: c for c in CD["cards"]}
SHIPS = E.SHIPS
SEASON_MOD = E.IS["sea_theme"]["env_bias"]["season_mod"]
t0 = time.time()


def log(*a):
    print(*a, flush=True)


def spawn_flame(fleet, side, ship_id, hm, gmA, fam, nfb=1.0):
    sp = SHIPS.get(ship_id, {"atkMod": 1.0, "defMod": 1.0, "armorType": "light"}); out = []
    e2 = SEASON_MOD
    for i, cid in enumerate(fleet):
        c = CARDS.get(cid)
        if not c: continue
        is_flame = (c["system"] == "flame")
        atk = c["atk"] * (fam if is_flame else nfb)
        df = c["def"] * (nfb if not is_flame else 1.0)
        out.append(dict(uid=f"{side}{i}_{cid}", id=cid, side=side, sys=c["system"],
                        atk=atk * sp.get("atkMod", 1.0) * e2.get(c["system"], 1.0) * gmA,
                        df=df * sp.get("defMod", 1.0), spd=float(c["spd"]),
                        hp=c["hp"] * hm * gmA, max_hp=c["hp"] * hm * gmA,
                        armor_type=sp.get("armorType", "light"), skill=c.get("skill", {})))
    return out


def R(fa, fb, sa, sb, ha, hb, gmA=1.0, cap=0.80, seg=0.40, ironflat=0.08,
      def_coef=0.30, r1=True, fam=1.0, fdot=1.0, rf=None, nfb=1.0):
    ua = spawn_flame(fa, "A", sa, ha, gmA, fam, nfb)
    ub = spawn_flame(fb, "B", sb, hb, 1.0, fam, nfb)
    for side in (ua, ub):
        if any(u["id"] == "FLAME_SR_01" for u in side):
            for u in side:
                if u["sys"] == "flame": u["atk"] *= 1.15
        bo = 0.0
        if any(u["id"] == "IRON_SR_01" for u in side): bo += 0.15
        if any(u["id"] == "IRON_UR_01" for u in side): bo += 0.25
        for u in side:
            u["ab"] = bo + (0.30 if u["id"] == "IRON_R_01" else 0.0)
            u["pr"] = 0.25 if u["id"] == "IRON_SSR_01" else 0.0
            u["sh"] = 0.0
            if u["id"] == "WIND_SR_01": u["spd"] += 15
        if any(u["id"] == "IRON_R_02" for u in side):
            for u in side: u["df"] *= 1.10
        c2 = 0.0
        if any(u["id"] == "TIDE_SR_01" for u in side): c2 += 0.10
        if any(u["id"] == "TIDE_UR_01" for u in side): c2 += 0.15
        for u in side: u["cb"] = c2
        if any(u["id"] == "TIDE_R_01" for u in side):
            s = [u for u in side if u["id"] == "TIDE_R_01"][0]
            t = min(side, key=lambda x: x["hp"]); t["sh"] += min(s["atk"] * 0.5, t["max_hp"] * 2)
        if any(u["id"] == "TIDE_UR_01" for u in side):
            s = [u for u in side if u["id"] == "TIDE_UR_01"][0]
            mult = 1.8 if r1 else 0.6
            for u in side: u["sh"] += min(s["atk"] * mult, u["max_hp"] * 2)
            for u in side: u["absorb_dot"] = r1
        else:
            for u in side: u["absorb_dot"] = False
    iron_ur_a = any(u["id"] == "IRON_UR_01" for u in ua)
    iron_ur_b = any(u["id"] == "IRON_UR_01" for u in ub)
    dots = {}; stun = {}; sil = {}; tot = defaultdict(int); st8 = [12345]; r = 0

    def nr(k):
        st8[0] = (st8[0] * 1103515245 + 12345 + k) % 2147483648
        return st8[0] / 2147483648

    def rst(a, t):
        if rf is not None and a == "flame" and t == "ironwall": return rf
        return E.restraint(a, t)

    def pick2(en, a):
        best = None; bs = -9999.0
        for e in en:
            if e["hp"] <= 0: continue
            s = -e["df"]; co = rst(a["sys"], e["sys"])
            s += 1000.0 if co > 1.0 else (-200.0 if co < 1.0 else 0.0)
            if s > bs: bs = s; best = e
        return best

    while r < E.C["GUARD_MAX_ROUND"] and E.alive(ua) and E.alive(ub):
        r += 1
        for side in (ub, ua):
            for u in side:
                if u["hp"] <= 0 or u["uid"] not in dots: continue
                d = dots[u["uid"]]
                dmg = d["dmg"] * d["stacks"] * rst(d["src"], u["sys"])
                if r1 and u.get("absorb_dot") and d.get("src_id") != "FLAME_UR_01" and u["sh"] > 0:
                    a = min(u["sh"], dmg); u["sh"] -= a; dmg -= a
                u["hp"] = max(0, u["hp"] - int(round(dmg)))
        if not E.alive(ua) or not E.alive(ub): break
        for o2 in sorted([u for u in ua + ub if u["hp"] > 0], key=lambda x: -x["spd"]):
            if o2["hp"] <= 0: continue
            if stun.get(o2["uid"], 0) > 0: stun[o2["uid"]] -= 1; continue
            en = ub if o2["side"] == "A" else ua
            if not E.alive(en): break
            tg = pick2(en, o2)
            if tg is None: continue
            ty = o2.get("skill", {}).get("type", "")
            if ty == "control" and sil.get(o2["uid"], 0) <= 0:
                b = {"TIDE_R_02": 0.15, "TIDE_SR_01": 0.10, "TIDE_SSR_01": 0.30}.get(o2["id"], 0)
                if b and nr(r * 7 + len(en)) < b + o2["cb"] and tot[tg["uid"]] < E.C["MAX_STUN_ROUND"]:
                    du = (2 if o2["id"] == "TIDE_SSR_01" else 1) + (1 if any(x["id"] == "TIDE_SR_01" for x in (ua if o2["side"] == "A" else ub)) else 0)
                    ad = min(du, E.C["MAX_STUN_ROUND"] - tot[tg["uid"]])
                    (sil if o2["id"] == "TIDE_SSR_01" else stun)[tg["uid"]] = ad
                    tot[tg["uid"]] += ad
            hits = 1
            if o2["sys"] == "wind":
                hits = E.BASE_HITS.get(o2["id"], 1) + max(0, min(E.C["MAX_EXTRA_HIT"], int((o2["spd"] - 70) // E.C["WIND_BONUS_SEGMENT"])))
            side_has_iron_ur = iron_ur_a if o2["side"] == "A" else iron_ur_b
            for hi in range(hits):
                if tg["hp"] <= 0:
                    tg = pick2(en, o2)
                    if tg is None: break
                co = rst(o2["sys"], tg["sys"]); tc = E.tcoef(E.dtype(o2["sys"]), tg["armor_type"])
                ar = tg["df"] / (tg["df"] + 100.0)
                if tg["sys"] == "ironwall": ar = min(0.9, ar + ironflat)
                ar = min(cap, ar * (1 + tg["ab"]))
                pi = 0.10 if o2["id"] == "WIND_SSR_01" else 0.0
                if any(x["id"] == "IRON_UR_01" and x["hp"] > 0 for x in en): pi = 0.0
                ar = max(0.0, ar - pi)
                if r1 and side_has_iron_ur: ar *= 0.70
                if r1 and o2["id"] == "WIND_UR_01" and hi == hits - 1: ar = 0.0
                sm = 1.0 if hi == 0 else seg ** hi
                eff = o2["atk"] if def_coef <= 0 else max(1.0, o2["atk"] - tg["df"] * def_coef)
                raw = eff * sm * co * tc * (1.0 - ar)
                if E.dtype(o2["sys"]) == "physical": raw *= (1 - tg["pr"])
                d = max(1, int(round(raw)))
                if tg["sh"] > 0:
                    a = min(tg["sh"], d); tg["sh"] -= a; d -= a
                tg["hp"] = max(0, tg["hp"] - d)
                if ty == "dot" or o2["sys"] == "flame":
                    batk = o2["atk"] if def_coef <= 0 else max(1.0, o2["atk"] - tg["df"] * def_coef)
                    rate = E.DOT_RATE.get(o2["id"], 0.18) * (fdot if o2["sys"] == "flame" else 1.0)
                    dd = int(round(batk * rate)); k = tg["uid"]
                    if k not in dots:
                        dots[k] = {"dmg": dd, "stacks": 1, "src": o2["sys"], "src_id": o2["id"]}
                    else:
                        dots[k]["stacks"] = min(E.C["MAX_DOT_STACK"], dots[k]["stacks"] + 1)
                        dots[k]["dmg"] = max(dots[k]["dmg"], dd); dots[k]["src"] = o2["sys"]; dots[k]["src_id"] = o2["id"]
    if E.alive(ua) and not E.alive(ub): return "A", r
    if E.alive(ub) and not E.alive(ua): return "B", r
    return ("A" if E.hpsum(ua) >= E.hpsum(ub) else "B"), r


def measure(fleets, fam, fdot, rf, nfb=1.0):
    win = flame_win = 0
    roster, hm = E.FR12_A
    for f in fleets:
        w, rr = R(f, roster, "SHIP_IRON", "SHIP_IRON", 1.0, hm, gmA=GM, cap=CAP,
                  seg=SEG, def_coef=DEF_COEF, r1=True, fam=fam, fdot=fdot, rf=rf, nfb=nfb)
        if w == "A":
            win += 1
            if any(CARDS[c]["system"] == "flame" for c in f): flame_win += 1
    n = len(fleets)
    return win / n * 100, (flame_win / win * 100 if win else 0)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "scan"
    if mode == "bench":
        random.seed(20260802)
        sample = random.sample(E.FL, 1500)
        tb = time.time()
        fr, fw = measure(sample, 0.85, 0.85, 1.30)
        log(f"BENCH sample=1500 -> FR_12={fr:.2f}% flame={fw:.1f}% 用时 {time.time()-tb:.1f}s")
        sys.exit()
    # ---- 三维扫描（flame-only） ----
    def run_scan3():
        random.seed(20260802)
        SAMPLE = 1500
        sample = random.sample(E.FL, SAMPLE)
        FAM = [0.85, 0.88, 0.90, 0.92, 0.95]
        FDOT = [0.75, 0.80, 0.85, 0.90]
        RF = [1.15, 1.25, 1.35, 1.45]
        log("=" * 110)
        log("R1 三维扫描 Phase A（采样 %d / 全量 %d）|FR12| hm1.35 gm1.15 def_coef=0.30(D13②)+R1全开" % (SAMPLE, len(E.FL)))
        log("=" * 110)
        log(f"{'fam':>6}{'fdot':>7}{'rf':>7}{'FR_12':>9}{'烈焰%':>9}{'判定':>14}")
        passing = []
        for fam in FAM:
            for fdot in FDOT:
                for rf in RF:
                    fr, fw = measure(sample, fam, fdot, rf)
                    ok_fr = 5 <= fr <= 15
                    ok_fl = fw <= 85
                    verdict = "PASS" if (ok_fr and ok_fl) else ("FR超界" if not ok_fr else "主导未破")
                    if ok_fr and ok_fl:
                        passing.append((fam, fdot, rf, fr, fw))
                    log(f"{fam:>6.2f}{fdot:>7.2f}{rf:>7.2f}{fr:>8.2f}%{fw:>8.1f}%{verdict:>14}")
        log(f"\nPhase A 通过数 = {len(passing)}  用时 {time.time()-t0:.0f}s")
        if passing:
            log("\n" + "=" * 110)
            log("Phase B · 全量 %d 复核通过项" % len(E.FL))
            log("=" * 110)
            log(f"{'fam':>6}{'fdot':>7}{'rf':>7}{'FR_12':>9}{'烈焰%':>9}")
            best = None
            for fam, fdot, rf, _, _ in passing:
                fr, fw = measure(E.FL, fam, fdot, rf)
                log(f"{fam:>6.2f}{fdot:>7.2f}{rf:>7.2f}{fr:>8.2f}%{fw:>8.1f}%")
                if best is None or fw < best[4]:
                    best = (fam, fdot, rf, fr, fw)
            fam, fdot, rf, fr, fw = best
            log(f"\n★ 最优补丁候选（烈焰最低）：fam={fam} fdot={fdot} rf={rf} -> FR_12={fr:.2f}% 烈焰={fw:.1f}%")
            log(f"  对应 stat_table_version 改动：flame 卡 atk×{fam}, flame DoT率×{fdot}, 克制系数 flame→ironwall={rf}")
        log(f"\n[总用时 {time.time()-t0:.0f}s]")

    # ---- 四维扫描（+ 非烈焰 buff 轴 nfb） ----
    def run_scan4():
        random.seed(20260802)
        SAMPLE = 1500
        sample = random.sample(E.FL, SAMPLE)
        FAM = [0.95, 1.00]
        FDOT = [0.85, 1.00]
        RF = [1.30, 1.50]
        NFB = [1.05, 1.10, 1.15, 1.20, 1.25]
        log("=" * 110)
        log("R1 四维扫描（+非烈焰buff轴 nfb）· 采样 %d / 全量 %d · hm1.35 gm1.15 def_coef=0.30(D13②)+R1全开" % (SAMPLE, len(E.FL)))
        log("=" * 110)
        log(f"{'fam':>6}{'fdot':>7}{'rf':>7}{'nfb':>7}{'FR_12':>9}{'烈焰%':>9}{'判定':>14}")
        passing = []
        for fam in FAM:
            for fdot in FDOT:
                for rf in RF:
                    for nfb in NFB:
                        fr, fw = measure(sample, fam, fdot, rf, nfb)
                        ok_fr = 5 <= fr <= 15
                        ok_fl = fw <= 85
                        verdict = "PASS" if (ok_fr and ok_fl) else ("FR超界" if not ok_fr else "主导未破")
                        if ok_fr and ok_fl:
                            passing.append((fam, fdot, rf, nfb, fr, fw))
                        log(f"{fam:>6.2f}{fdot:>7.2f}{rf:>7.2f}{nfb:>7.2f}{fr:>8.2f}%{fw:>8.1f}%{verdict:>14}")
        log(f"\nPhase A 通过数 = {len(passing)}  用时 {time.time()-t0:.0f}s")
        if passing:
            log("\n" + "=" * 110)
            log("Phase B · 全量 %d 复核通过项" % len(E.FL))
            log("=" * 110)
            log(f"{'fam':>6}{'fdot':>7}{'rf':>7}{'nfb':>7}{'FR_12':>9}{'烈焰%':>9}")
            best = None
            for fam, fdot, rf, nfb, _, _ in passing:
                fr, fw = measure(E.FL, fam, fdot, rf, nfb)
                log(f"{fam:>6.2f}{fdot:>7.2f}{rf:>7.2f}{nfb:>7.2f}{fr:>8.2f}%{fw:>8.1f}%")
                if best is None or fw < best[5]:
                    best = (fam, fdot, rf, nfb, fr, fw)
            fam, fdot, rf, nfb, fr, fw = best
            log(f"\n★ 最优补丁候选：fam={fam} fdot={fdot} rf={rf} nfb={nfb} -> FR_12={fr:.2f}% 烈焰={fw:.1f}%")
            log(f"  对应 stat_table_version 改动：flame atk×{fam}, flame DoT率×{fdot}, 克制 flame→ironwall={rf}, 非烈焰 atk/def×{nfb}")
        log(f"\n[总用时 {time.time()-t0:.0f}s]")

    if mode == "scan4":
        run_scan4()
    else:
        run_scan3()
    sys.exit()
