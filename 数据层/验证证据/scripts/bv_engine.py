# -*- coding: utf-8 -*-
"""bv_engine：把 bvd1_sim8.py 的战斗结算器抽成可复用模块，供 D3 级联复跑使用。

与 bvd1_sim8.py 的唯一差异：R() 增加 seg_mode 参数
  - "geo"  第 k 段 = base × SEG_DECAY^(k-1)   ← GDD-03 §6.3 规格 / verify6 / cards_audit3-4 用的模型
  - "flat" 第 k 段 = base × SEG_DECAY (k>=2)  ← bvd1_sim8 原实现（13.65% 出处）
两者在 <=2 段时等价；疾风 SSR(3段)/UR(4段) 上分叉。
"""
import json, itertools
from collections import defaultdict

BASE = "C:/Users/Administrator/AppData/Local/Temp/bv/"
C  = json.load(open(BASE + "data_constants.json", encoding="utf-8"))
CD = json.load(open(BASE + "data_cards.json", encoding="utf-8"))
IS = json.load(open(BASE + "data_islands.json", encoding="utf-8"))
GU = json.load(open(BASE + "data_guards.json", encoding="utf-8"))
SH = json.load(open(BASE + "data_ships.json", encoding="utf-8"))
CARDS = {c["id"]: c for c in CD["cards"]}
SHIPS = {s["id"]: s for s in SH["ships"]}
ISLANDS = {i["id"]: i for i in IS["islands"]}
RING = C["RING"]
SEASON_MOD = IS["sea_theme"]["env_bias"]["season_mod"]

BASE_HITS = {"WIND_R_01": 1, "WIND_R_02": 2, "WIND_SR_01": 2, "WIND_SSR_01": 3, "WIND_UR_01": 4}
DOT_RATE = {"FLAME_R_01": 0.15, "FLAME_R_02": 0.10, "FLAME_SSR_01": 0.25, "FLAME_UR_01": 0.30}


def restraint(a, t):
    if RING.get(a) == t: return C["RESTRAINT"]
    if RING.get(t) == a: return C["RESTRAINT_DISADV"]
    return 1.0


def dtype(s): return {"flame": "burn", "tide": "energy"}.get(s, "physical")
def tcoef(d, a): return C["TYPE_COEF"].get(d, {}).get(a, 1.0)
def alive(u): return any(x["hp"] > 0 for x in u)
def hpsum(u): return sum(x["hp"] for x in u if x["hp"] > 0)


def pick(en, a):
    best = None; bs = -9999.0
    for e in en:
        if e["hp"] <= 0: continue
        s = -e["df"]; co = restraint(a["sys"], e["sys"])
        s += 1000.0 if co > 1.0 else (-200.0 if co < 1.0 else 0.0)
        if s > bs: bs = s; best = e
    return best


def spawn2(fleet, side, ship_id, hm, gm=1.0, env=None):
    sp = SHIPS.get(ship_id, {"atkMod": 1.0, "defMod": 1.0, "armorType": "light"}); out = []
    E = env if env is not None else SEASON_MOD
    for i, cid in enumerate(fleet):
        c = CARDS.get(cid)
        if not c: continue
        out.append(dict(uid=f"{side}{i}_{cid}", id=cid, side=side, sys=c["system"],
                        atk=c["atk"] * sp.get("atkMod", 1.0) * E.get(c["system"], 1.0) * gm,
                        df=c["def"] * sp.get("defMod", 1.0), spd=float(c["spd"]),
                        hp=c["hp"] * hm * gm, max_hp=c["hp"] * hm * gm,
                        armor_type=sp.get("armorType", "light"), skill=c.get("skill", {})))
    return out


def R(fa, fb, sa, sb, ha, hb, gmA=1.0, cap=0.90, env=None, seg=0.55, ironflat=0.08, seg_mode="geo",
      def_coef=0.0):
    """def_coef（2026-08-02 新增，BV-Lock）：护甲减法系数 DEF_COEF。
       0.0  = 本引擎历史行为（纯乘法减免，无减法项）—— 所有既往胜率快照均在此下产出
       0.30 = 用户决策"方案1"终值（10-经济 §6.4）
       0.50 = 10-经济 §6.1 DPR 解析模型的原系数
       减法项落点：eff_atk = max(1, atk − target.def × DEF_COEF)，再乘段衰减/克制/类型/护甲减免。"""
    ua = spawn2(fa, "A", sa, ha, gmA, env); ub = spawn2(fb, "B", sb, hb, 1.0, env)
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
            for u in side: u["sh"] += min(s["atk"] * 0.6, u["max_hp"] * 2)
    dots = {}; stun = {}; sil = {}; tot = defaultdict(int); st8 = [12345]; r = 0

    def nr(k):
        st8[0] = (st8[0] * 1103515245 + 12345 + k) % 2147483648
        return st8[0] / 2147483648

    while r < C["GUARD_MAX_ROUND"] and alive(ua) and alive(ub):
        r += 1
        for side in (ub, ua):
            for u in side:
                if u["hp"] <= 0 or u["uid"] not in dots: continue
                d = dots[u["uid"]]
                u["hp"] = max(0, u["hp"] - int(round(d["dmg"] * d["stacks"] * restraint(d["src"], u["sys"]))))
        if not alive(ua) or not alive(ub): break
        for o2 in sorted([u for u in ua + ub if u["hp"] > 0], key=lambda x: -x["spd"]):
            if o2["hp"] <= 0: continue
            if stun.get(o2["uid"], 0) > 0: stun[o2["uid"]] -= 1; continue
            en = ub if o2["side"] == "A" else ua
            if not alive(en): break
            tg = pick(en, o2)
            if tg is None: continue
            ty = o2.get("skill", {}).get("type", "")
            if ty == "control" and sil.get(o2["uid"], 0) <= 0:
                b = {"TIDE_R_02": 0.15, "TIDE_SR_01": 0.10, "TIDE_SSR_01": 0.30}.get(o2["id"], 0)
                if b and nr(r * 7 + len(en)) < b + o2["cb"] and tot[tg["uid"]] < C["MAX_STUN_ROUND"]:
                    du = (2 if o2["id"] == "TIDE_SSR_01" else 1) + (1 if any(x["id"] == "TIDE_SR_01" for x in (ua if o2["side"] == "A" else ub)) else 0)
                    ad = min(du, C["MAX_STUN_ROUND"] - tot[tg["uid"]])
                    (sil if o2["id"] == "TIDE_SSR_01" else stun)[tg["uid"]] = ad
                    tot[tg["uid"]] += ad
            hits = 1
            if o2["sys"] == "wind":
                hits = BASE_HITS.get(o2["id"], 1) + max(0, min(C["MAX_EXTRA_HIT"], int((o2["spd"] - 70) // C["WIND_BONUS_SEGMENT"])))
            for hi in range(hits):
                if tg["hp"] <= 0:
                    tg = pick(en, o2)
                    if tg is None: break
                co = restraint(o2["sys"], tg["sys"]); tc = tcoef(dtype(o2["sys"]), tg["armor_type"])
                ar = tg["df"] / (tg["df"] + 100.0)
                if tg["sys"] == "ironwall": ar = min(0.9, ar + ironflat)
                ar = min(cap, ar * (1 + tg["ab"]))
                pi = 0.10 if o2["id"] == "WIND_SSR_01" else 0.0
                if any(x["id"] == "IRON_UR_01" and x["hp"] > 0 for x in en): pi = 0.0
                ar = max(0.0, ar - pi)
                # ★ 唯一改动点：段衰减模型
                if hi == 0:
                    sm = 1.0
                elif seg_mode == "geo":
                    sm = seg ** hi           # GDD-03 §6.3 规格：SEG_DECAY^(k-1)
                else:
                    sm = seg                 # bvd1_sim8 原实现（flat）
                eff_atk = o2["atk"] if def_coef <= 0 else max(1.0, o2["atk"] - tg["df"] * def_coef)
                raw = eff_atk * sm * co * tc * (1.0 - ar)
                if dtype(o2["sys"]) == "physical": raw *= (1 - tg["pr"])
                d = max(1, int(round(raw)))
                if tg["sh"] > 0:
                    a = min(tg["sh"], d); tg["sh"] -= a; d -= a
                tg["hp"] = max(0, tg["hp"] - d)
                if ty == "dot" or o2["sys"] == "flame":
                    # [D13②] DoT 也过减法扣甲：max(1, atk×rate − def×DEF_COEF)（与 ResolveBattle v0.4 对齐）
                    batk = o2["atk"] if def_coef <= 0 else max(1.0, o2["atk"] - tg["df"] * def_coef)
                    dd = int(round(batk * DOT_RATE.get(o2["id"], 0.18))); k = tg["uid"]
                    if k not in dots: dots[k] = {"dmg": dd, "stacks": 1, "src": o2["sys"]}
                    else:
                        dots[k]["stacks"] = min(C["MAX_DOT_STACK"], dots[k]["stacks"] + 1)
                        dots[k]["dmg"] = max(dots[k]["dmg"], dd); dots[k]["src"] = o2["sys"]
    if alive(ua) and not alive(ub): return "A", r, hpsum(ua), hpsum(ub)
    if alive(ub) and not alive(ua): return "B", r, hpsum(ua), hpsum(ub)
    return ("A" if hpsum(ua) >= hpsum(ub) else "B"), r, hpsum(ua), hpsum(ub)


# ---- 编队空间（与 bvd1_sim8/10 完全一致：n in (3,4,5), cost<=10, 同体系<=4）----
def cost(f): return sum(CARDS[c]["cost"] for c in f)


def legal(f, cap_cost=10):
    if cost(f) > cap_cost: return False
    cn = defaultdict(int)
    for c in f: cn[CARDS[c]["system"]] += 1
    return max(cn.values()) <= 4


ALL = list(CARDS.keys())
FL = [list(f) for n in (3, 4, 5) for f in itertools.combinations(ALL, n) if legal(list(f))]
ST = json.load(open(BASE + "data_starting_deck.json", encoding="utf-8"))["owned_cards"]
SF = [f for f in FL if all(c in ST for c in f)]

# FR_12 推荐终配（GDD-02 §6.4 方案 a / bvd1_out10.txt 13.65% 出处）
FR12_A = (["IRON_UR_01", "IRON_SSR_01", "TIDE_SSR_01", "IRON_R_01", "WIND_R_02"], 1.35)


def winrate(pool, ship, roster, hm, gm, seg, cap=0.80, seg_mode="geo", guard_ship="SHIP_IRON",
            def_coef=0.0):
    w = 0
    for f in pool:
        if R(f, roster, ship, guard_ship, 1.0, hm, gmA=gm, cap=cap, seg=seg, seg_mode=seg_mode,
             def_coef=def_coef)[0] == "A":
            w += 1
    return w / len(pool) * 100
