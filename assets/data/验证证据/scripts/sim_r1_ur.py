# -*- coding: utf-8 -*-
"""sim_r1_ur（主理人, 2026-08-02）· R1 UR 独占效果仿真穿刺

验证 r1_ur_exclusive_effect.md §4 的验收判据：
  - 胜方编队含烈焰占比 99.9% -> <=85%（破烈焰主导）
  - FR_12 胜率(Lv4, gm1.15) 维持 5~15%（基线 D13② = 11.96%）

复刻 lock_armor_c 的测量协议：E.FL 全空间(11,443) × gm=1.15 × hm=1.35
× cap=0.80 × seg=0.40 × def_coef=0.30（D13② 已含 DoT 过甲）。

R1 四个独占开关（仅当玩家编队含对应 UR 时激活）：
  - TIDE_UR_01  渊盾吸收 DoT（盾量放宽 x1.8，DoT 先扣盾溢出扣血；焚尽穿透）
  - IRON_UR_01  破甲光环（敌方全队 effectiveArmor -30%，ar*=0.70）
  - WIND_UR_01  真实伤害段（最后一段无视护甲 ar=0）
  - FLAME_UR_01 焚尽（其 DoT 不被渊盾吸收，穿透）
"""
import time
from collections import defaultdict
import bv_engine as E

SEG, CAP = 0.40, 0.80
t0 = time.time()


def log(*a):
    print(*a, flush=True)


def R_r1(fa, fb, sa, sb, ha, hb, gmA=1.0, cap=0.80, seg=0.40, ironflat=0.08,
         def_coef=0.30, r1=True):
    ua = E.spawn2(fa, "A", sa, ha, gmA, None)
    ub = E.spawn2(fb, "B", sb, hb, 1.0, None)
    for side in (ua, ub):
        if any(u["id"] == "FLAME_SR_01" for u in side):
            for u in side:
                if u["sys"] == "flame":
                    u["atk"] *= 1.15
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
            # R1 独占：渊盾量放宽至 baseAtk×1.8 且吸收 DoT；基线(r1=False)沿用 ×0.6
            mult = 1.8 if r1 else 0.6
            for u in side: u["sh"] += min(s["atk"] * mult, u["max_hp"] * 2)
            for u in side: u["absorb_dot"] = r1   # R1: 渊盾吸收 DoT
        else:
            for u in side: u["absorb_dot"] = False
    iron_ur_a = any(u["id"] == "IRON_UR_01" for u in ua)
    iron_ur_b = any(u["id"] == "IRON_UR_01" for u in ub)
    dots = {}; stun = {}; sil = {}; tot = defaultdict(int); st8 = [12345]; r = 0

    def nr(k):
        st8[0] = (st8[0] * 1103515245 + 12345 + k) % 2147483648
        return st8[0] / 2147483648

    while r < E.C["GUARD_MAX_ROUND"] and E.alive(ua) and E.alive(ub):
        r += 1
        for side in (ub, ua):
            for u in side:
                if u["hp"] <= 0 or u["uid"] not in dots: continue
                d = dots[u["uid"]]
                dmg = d["dmg"] * d["stacks"] * E.restraint(d["src"], u["sys"])
                # R1: 渊盾吸收 DoT（焚尽穿透盾）
                if r1 and u.get("absorb_dot") and d.get("src_id") != "FLAME_UR_01" and u["sh"] > 0:
                    a = min(u["sh"], dmg); u["sh"] -= a; dmg -= a
                u["hp"] = max(0, u["hp"] - int(round(dmg)))
        if not E.alive(ua) or not E.alive(ub): break
        for o2 in sorted([u for u in ua + ub if u["hp"] > 0], key=lambda x: -x["spd"]):
            if o2["hp"] <= 0: continue
            if stun.get(o2["uid"], 0) > 0: stun[o2["uid"]] -= 1; continue
            en = ub if o2["side"] == "A" else ua
            if not E.alive(en): break
            tg = E.pick(en, o2)
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
                    tg = E.pick(en, o2)
                    if tg is None: break
                co = E.restraint(o2["sys"], tg["sys"]); tc = E.tcoef(E.dtype(o2["sys"]), tg["armor_type"])
                ar = tg["df"] / (tg["df"] + 100.0)
                if tg["sys"] == "ironwall": ar = min(0.9, ar + ironflat)
                ar = min(cap, ar * (1 + tg["ab"]))
                pi = 0.10 if o2["id"] == "WIND_SSR_01" else 0.0
                if any(x["id"] == "IRON_UR_01" and x["hp"] > 0 for x in en): pi = 0.0
                ar = max(0.0, ar - pi)
                # R1: 铁壁破甲光环（敌方全队 effectiveArmor -30%）
                if r1 and side_has_iron_ur: ar *= 0.70
                # R1: 疾风真实伤害段（最后一段无视护甲）
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
                    dd = int(round(batk * E.DOT_RATE.get(o2["id"], 0.18))); k = tg["uid"]
                    if k not in dots:
                        dots[k] = {"dmg": dd, "stacks": 1, "src": o2["sys"], "src_id": o2["id"]}
                    else:
                        dots[k]["stacks"] = min(E.C["MAX_DOT_STACK"], dots[k]["stacks"] + 1)
                        dots[k]["dmg"] = max(dots[k]["dmg"], dd); dots[k]["src"] = o2["sys"]; dots[k]["src_id"] = o2["id"]
    if E.alive(ua) and not E.alive(ub): return "A", r, E.hpsum(ua), E.hpsum(ub)
    if E.alive(ub) and not E.alive(ua): return "B", r, E.hpsum(ua), E.hpsum(ub)
    return ("A" if E.hpsum(ua) >= E.hpsum(ub) else "B"), r, E.hpsum(ua), E.hpsum(ub)


URS = ["FLAME_UR_01", "IRON_UR_01", "WIND_UR_01", "TIDE_UR_01"]


def run(r1, gm=1.15):
    win, rounds, timeout, flame_win = 0, 0, 0, 0
    ur_win = {u: 0 for u in URS}
    roster, hm = E.FR12_A
    for f in E.FL:
        w, r, ha, hb = R_r1(f, roster, "SHIP_IRON", "SHIP_IRON", 1.0, hm, gmA=gm,
                             cap=CAP, seg=SEG, def_coef=0.30, r1=r1)
        rounds += r
        if r >= E.C["GUARD_MAX_ROUND"]: timeout += 1
        if w == "A":
            win += 1
            if any(E.CARDS[c]["system"] == "flame" for c in f): flame_win += 1
            for u in URS:
                if any(c == u for c in f): ur_win[u] += 1
    n = len(E.FL)
    return dict(win=win / n * 100, rounds=round(rounds / n, 1), timeout=timeout / n * 100,
               flame=flame_win / win * 100 if win else 0,
               ur={u: ur_win[u] / win * 100 for u in URS})


if __name__ == "__main__":
    log("=" * 100)
    log("R1 · UR 独占效果仿真穿刺 |FR12|=1.35 gm=1.15 cap=0.80 seg=0.40 def_coef=0.30(D13②)")
    log(f"全编队空间 |FL|={len(E.FL)}  基线烈焰占比={sum(1 for f in E.FL if any(E.CARDS[c]['system']=='flame' for c in f))/len(E.FL)*100:.1f}%")
    log("=" * 100)
    base = run(False)
    with_r1 = run(True)
    log(f"\n{'配置':<22}{'FR_12胜率':>12}{'平均回合':>10}{'打满占比':>10}{'胜方含烈焰':>14}")
    log(f"{'基线(无R1)':<22}{base['win']:>11.2f}%{base['rounds']:>10.1f}{base['timeout']:>9.1f}%{base['flame']:>13.1f}%")
    log(f"{'R1独占全开':<22}{with_r1['win']:>11.2f}%{with_r1['rounds']:>10.1f}{with_r1['timeout']:>9.1f}%{with_r1['flame']:>13.1f}%")
    log(f"\n胜方含 UR 占比（仅 R1 配置）：")
    for u in URS:
        log(f"  {u:<14}{with_r1['ur'][u]:>6.1f}%")
    log(f"\n验收判据对照：")
    log(f"  烈焰主导 99.9% -> 目标<=85% : 实测 {with_r1['flame']:.1f}%  {'PASS' if with_r1['flame']<=85 else 'FAIL'}")
    log(f"  FR_12 5~15% : 实测 {with_r1['win']:.2f}%  {'PASS' if 5<=with_r1['win']<=15 else 'FAIL'}")
    log(f"\n[总用时 {time.time()-t0:.0f}s]")
