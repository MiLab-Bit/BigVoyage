# -*- coding: utf-8 -*-
"""lock_armor_c（BV-Lock, 2026-08-02）· 诊断：为什么 DEF_COEF 0.00 -> 0.30 反而把 FR_12 胜率抬高？
   假设 H：DoT 伤害 `baseAtk × dotRate` **完全不经过护甲通道**（既不减法也不乘法减免），
          因此 DEF_COEF 增大只压制直伤、不压制 DoT ->
          玩家可编入烈焰（DoT）而 FR_12 守卫为纯 铁壁/潮汐/疾风，无 DoT -> 单边受益。
   验证：对 DoT 也施加同一减法项（dot_armor=True），看 FR_12 是否回落。
"""
import time, itertools
from collections import defaultdict
import bv_engine as E

SEG, CAP = 0.40, 0.80
t0 = time.time()


def log(*a):
    print(*a, flush=True)


# ---- 复制 R()，仅增加 dot_armor 开关 ----
def R2(fa, fb, sa, sb, ha, hb, gmA=1.0, cap=0.90, seg=0.40, ironflat=0.08,
       def_coef=0.0, dot_armor=False):
    src = E.R.__code__  # 保证与主引擎同源（仅此函数内联改 DoT 通道）
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
            for u in side: u["sh"] += min(s["atk"] * 0.6, u["max_hp"] * 2)
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
                u["hp"] = max(0, u["hp"] - int(round(d["dmg"] * d["stacks"] * E.restraint(d["src"], u["sys"]))))
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
                sm = 1.0 if hi == 0 else seg ** hi
                eff = o2["atk"] if def_coef <= 0 else max(1.0, o2["atk"] - tg["df"] * def_coef)
                raw = eff * sm * co * tc * (1.0 - ar)
                if E.dtype(o2["sys"]) == "physical": raw *= (1 - tg["pr"])
                d = max(1, int(round(raw)))
                if tg["sh"] > 0:
                    a = min(tg["sh"], d); tg["sh"] -= a; d -= a
                tg["hp"] = max(0, tg["hp"] - d)
                if ty == "dot" or o2["sys"] == "flame":
                    # ★ 诊断开关：DoT 是否也走减法护甲通道
                    batk = o2["atk"] if not (dot_armor and def_coef > 0) else max(1.0, o2["atk"] - tg["df"] * def_coef)
                    dd = int(round(batk * E.DOT_RATE.get(o2["id"], 0.18))); k = tg["uid"]
                    if k not in dots: dots[k] = {"dmg": dd, "stacks": 1, "src": o2["sys"]}
                    else:
                        dots[k]["stacks"] = min(E.C["MAX_DOT_STACK"], dots[k]["stacks"] + 1)
                        dots[k]["dmg"] = max(dots[k]["dmg"], dd); dots[k]["src"] = o2["sys"]
    if E.alive(ua) and not E.alive(ub): return "A", r, E.hpsum(ua), E.hpsum(ub)
    if E.alive(ub) and not E.alive(ua): return "B", r, E.hpsum(ua), E.hpsum(ub)
    return ("A" if E.hpsum(ua) >= E.hpsum(ub) else "B"), r, E.hpsum(ua), E.hpsum(ub)


def run(def_coef, dot_armor, gm=1.15):
    win, rounds, timeout, flame_win = 0, 0, 0, 0
    roster, hm = E.FR12_A
    for f in E.FL:
        w, r, ha, hb = R2(f, roster, "SHIP_IRON", "SHIP_IRON", 1.0, hm, gmA=gm, cap=CAP,
                          seg=SEG, def_coef=def_coef, dot_armor=dot_armor)
        rounds += r
        if r >= E.C["GUARD_MAX_ROUND"]: timeout += 1
        if w == "A":
            win += 1
            if any(E.CARDS[c]["system"] == "flame" for c in f): flame_win += 1
    n = len(E.FL)
    return win / n * 100, rounds / n, timeout / n * 100, (flame_win / win * 100 if win else 0)


if __name__ == "__main__":
    log("=" * 100)
    log("C · 诊断：DEF_COEF 抬高 FR_12 胜率的根因（DoT 是否绕过护甲通道）")
    log(f"固定 SEG_DECAY={SEG} ARMOR_CAP={CAP} gm=1.15 FR_12 cost12 hm1.35 |FL|={len(E.FL)}")
    log("=" * 100)
    log(f"\n{'DEF_COEF':>9}{'DoT走护甲?':>12}{'FR_12胜率':>12}{'平均回合':>10}{'打满30回合占比':>16}{'胜方含烈焰占比':>16}")
    base_flame = sum(1 for f in E.FL if any(E.CARDS[c]["system"] == "flame" for c in f)) / len(E.FL) * 100
    for dc, da in [(0.00, False), (0.30, False), (0.30, True)]:
        w, ar, to, fw = run(dc, da)
        log(f"{dc:>9.2f}{('是' if da else '否'):>12}{w:>11.2f}%{ar:>10.1f}{to:>15.1f}%{fw:>15.1f}%")
    log(f"\n参照：全编队空间中含烈焰卡的占比 = {base_flame:.1f}%"
        f"（胜方占比显著高于此值 = 烈焰/DoT 存在选择性优势）")
    log(f"\n[总用时 {time.time()-t0:.0f}s]")
