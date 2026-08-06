# -*- coding: utf-8 -*-
# verify7：(a) 施加 STAT_CAP.def=200 截断  (b) 评估 guards 修订案 v0.2  (c) 养成轴对 heavy/boss 的作用
import sys
import verify6 as V

STAT_CAP = {"atk": 200, "def": 200}

def build(ids, ship_id, side, hp_mult=1.0, growth=1.0):
    at, ar, am, dm = V.SHIPS[ship_id]
    out = []
    for i, cid in enumerate(ids):
        s, cost, atk, dfv, spd, hp = V.CARDS[cid]
        eff_def = min(STAT_CAP["def"], dfv*dm + ar)        # ★ SSOT STAT_CAP 截断
        eff_atk = min(STAT_CAP["atk"], atk*am*growth)
        out.append({"cid":cid,"sys":s,"atk":eff_atk*V.ENV[s],"def":eff_def,"spd":spd,
                    "hp":hp*hp_mult*growth,"arm":at,"side":side,"slot":i,
                    "seg":V.FACE.get(cid,1)})
    return out

# ---- guards 修订案 v0.2（设计提案，未合入工程）----
G2 = {
 "FR_02":(["IRON_R_01","IRON_R_02","IRON_SR_01"],1.00),
 "FR_03":(["IRON_R_01","IRON_R_02","WIND_R_01"],1.10),
 "FR_04":(["IRON_R_01","IRON_SR_01","TIDE_R_02"],1.00),
 "FR_05":(["IRON_R_02","IRON_SR_01","TIDE_R_01"],1.00),
 "FR_06":(["IRON_SSR_01","IRON_SR_01","IRON_R_01","IRON_R_02","FLAME_R_01"],1.20),
 "FR_07":(["IRON_R_01","WIND_R_02","IRON_SR_01"],1.05),
 "FR_08":(["IRON_R_02","IRON_SR_01","TIDE_R_02"],1.05),
 "FR_09":(["IRON_SSR_01","IRON_SR_01","TIDE_SR_01","IRON_R_01","WIND_R_01"],1.20),
 "FR_10":(["IRON_SR_01","IRON_R_01","IRON_R_02"],1.00),
 "FR_11":(["IRON_R_01","WIND_SR_01","IRON_SR_01"],1.00),
 "FR_12":(["IRON_UR_01","IRON_SSR_01","IRON_SR_01","TIDE_SSR_01","WIND_SSR_01"],1.40)}

STARTER_F = V.legal(V.STARTER)
ALL_F     = V.legal(V.ALL)

def winrate(pool, ship, G, growth=1.0):
    w = 0
    for f in pool:
        if V.resolve(build(list(f), ship, 0, 1.0, growth), G) == 0: w += 1
    return w/len(pool)*100

mode = sys.argv[1] if len(sys.argv) > 1 else ("all" if __name__ == "__main__" else "none")

if mode in ("all", "rev"):
    print("=== guards 修订案 v0.2 + STAT_CAP 截断（玩家统一 SHIP_RAFT）===", flush=True)
    print(f"{'岛':>6}{'实际HP':>8}{'标称':>6}{'起始12卡%':>11}{'全收集20卡%':>13}", flush=True)
    for iid in sorted(G2):
        ids, hm = G2[iid]
        G = build(ids, "SHIP_IRON", 1, hm)
        hp = int(sum(u["hp"] for u in G))
        a = winrate(STARTER_F, "SHIP_RAFT", G)
        b = winrate(ALL_F, "SHIP_RAFT", G)
        print(f"{iid:>6}{hp:>8}{V.ISL_HP[iid]:>6}{a:>11.1f}{b:>13.1f}", flush=True)

if mode in ("all", "grow"):
    print("\n=== 养成轴（Lv1→10，atk/hp 各 +5%/级）对 heavy/boss 的作用 ===", flush=True)
    print(f"{'岛':>6}{'Lv1%':>8}{'Lv5(x1.20)%':>13}{'Lv10(x1.45)%':>14}", flush=True)
    for iid in ["FR_06", "FR_09", "FR_12"]:
        ids, hm = G2[iid]
        G = build(ids, "SHIP_IRON", 1, hm)
        r = [winrate(ALL_F, "SHIP_RAFT", G, g) for g in (1.00, 1.20, 1.45)]
        print(f"{iid:>6}{r[0]:>8.1f}{r[1]:>13.1f}{r[2]:>14.1f}", flush=True)
