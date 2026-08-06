# -*- coding: utf-8 -*-
"""sim_r1_v3（主理人, 2026-08-02）· 验证"削烈焰卡牌基础攻击"是否破主导且不破 FR_12 区间

假设：主导根因是烈焰卡牌 atk+克制+DoT 三重叠加的 stat 优势（非 DoT 对护甲问题）。
杠杆：对所有 flame 卡 atk 乘 flame_atk_mult（属 stat_table_version 数据层改动，不碰战斗常量）。
测 ×0.90 / ×0.85 / ×0.80，看烈焰胜率是否落 <=85% 且 FR_12 仍 5~15%。
"""
import time
from collections import defaultdict
import bv_engine as E

SEG, CAP = 0.40, 0.80
t0 = time.time()


def log(*a):
    print(*a, flush=True)


# 复制 bv_engine.spawn2 但支持 flame atk 缩放
import json
BASE = "C:/Users/Administrator/AppData/Local/Temp/bv/"
CD = json.load(open(BASE + "data_cards.json", encoding="utf-8"))
CARDS = {c["id"]: c for c in CD["cards"]}
SHIPS = E.SHIPS
SEASON_MOD = E.IS["sea_theme"]["env_bias"]["season_mod"]


def spawn3(fleet, side, ship_id, hm, gmA=1.0, env=None, flame_atk_mult=1.0):
    sp = SHIPS.get(ship_id, {"atkMod": 1.0, "defMod": 1.0, "armorType": "light"}); out = []
    E2 = env if env is not None else SEASON_MOD
    for i, cid in enumerate(fleet):
        c = CARDS.get(cid)
        if not c: continue
        atk = c["atk"] * (flame_atk_mult if c["system"] == "flame" else 1.0)
        out.append(dict(uid=f"{side}{i}_{cid}", id=cid, side=side, sys=c["system"],
                        atk=atk * sp.get("atkMod", 1.0) * E2.get(c["system"], 1.0) * gmA,
                        df=c["def"] * sp.get("defMod", 1.0), spd=float(c["spd"]),
                        hp=c["hp"] * hm * gmA, max_hp=c["hp"] * hm * gmA,
                        armor_type=sp.get("armorType", "light"), skill=c.get("skill", {})))
    return out


def R(fa, fb, sa, sb, ha, hb, gmA=1.0, cap=0.80, seg=0.40, ironflat=0.08,
      def_coef=0.30, r1=True, flame_atk_mult=1.0):
    ua = spawn3(fa, "A", sa, ha, gmA, None, flame_atk_mult)
    ub = spawn3(fb, "B", sb, hb, 1.0, None, flame_atk_mult)
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
            for u in side: u["sh"] += min(s["atk"] * 1.8, u["max_hp"] * 2)
        for u in side: u["absorb_dot"] = r1 and any(x["id"] == "TIDE_UR_01" for x in side)
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
                if u.get("absorb_dot") and d.get("src_id") != "FLAME_UR_01" and u["sh"] > 0:
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
                    dd = int(round(batk * E.DOT_RATE.get(o2["id"], 0.18))); k = tg["uid"]
                    if k not in dots:
                        dots[k] = {"dmg": dd, "stacks": 1, "src": o2["sys"], "src_id": o2["id"]}
                    else:
                        dots[k]["stacks"] = min(E.C["MAX_DOT_STACK"], dots[k]["stacks"] + 1)
                        dots[k]["dmg"] = max(dots[k]["dmg"], dd); dots[k]["src"] = o2["sys"]; dots[k]["src_id"] = o2["id"]
    if E.alive(ua) and not E.alive(ub): return "A", r, E.hpsum(ua), E.hpsum(ub)
    if E.alive(ub) and not E.alive(ua): return "B", r, E.hpsum(ua), E.hpsum(ub)
    return ("A" if E.hpsum(ua) >= E.hpsum(ub) else "B"), r, E.hpsum(ua), E.hpsum(ub)


def run(fam, gm=1.15):
    win, flame_win = 0, 0
    roster, hm = E.FR12_A
    for f in E.FL:
        w, r, ha, hb = R(f, roster, "SHIP_IRON", "SHIP_IRON", 1.0, hm, gmA=gm, cap=CAP,
                         seg=SEG, def_coef=0.30, r1=True, flame_atk_mult=fam)
        if w == "A":
            win += 1
            if any(E.CARDS[c]["system"] == "flame" for c in f): flame_win += 1
    n = len(E.FL)
    return win / n * 100, (flame_win / win * 100 if win else 0)


if __name__ == "__main__":
    log("=" * 100)
    log("R1 v3 · 削烈焰卡牌基础攻击是否破主导 |FR12| hm1.35 gm1.15 def_coef=0.30(D13②)+R1全开")
    log("=" * 100)
    log(f"\n{'flame_atk_mult':<18}{'FR_12胜率':>12}{'胜方含烈焰':>14}{'判定':>12}")
    for fam in [1.0, 0.90, 0.85, 0.80]:
        w, fw = run(fam)
        verdict = "PASS" if (5 <= w <= 15 and fw <= 85) else ("FR_12超界" if not (5 <= w <= 15) else "主导未破")
        log(f"{fam:<18}{w:>11.2f}%{fw:>13.1f}%{verdict:>12}")
    log(f"\n基线烈焰占比=75.8%  目标烈焰<=85%（主导间隙<=9.2pp）")
    log(f"\n[总用时 {time.time()-t0:.0f}s]")
