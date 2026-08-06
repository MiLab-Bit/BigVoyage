# -*- coding: utf-8 -*-
# verify6：用 assets/data 分支的**真实** guards.json / ships.json 重跑进度曲线
# 与 verify5 的差别：守卫不是抽象 (units,atk,def)，而是「卡牌编成 + 旗舰 + hp_mult」
from itertools import combinations

CARDS = {
 "FLAME_R_01":("flame",1,40,25,50,200),"FLAME_R_02":("flame",1,45,22,48,190),
 "FLAME_SR_01":("flame",2,70,40,55,340),"FLAME_SSR_01":("flame",3,110,60,72,580),
 "FLAME_UR_01":("flame",4,160,95,85,900),
 "IRON_R_01":("ironwall",1,35,45,38,260),"IRON_R_02":("ironwall",1,33,50,35,280),
 "IRON_SR_01":("ironwall",2,60,75,42,460),"IRON_SSR_01":("ironwall",3,95,115,50,760),
 "IRON_UR_01":("ironwall",4,140,170,55,1150),
 "WIND_R_01":("wind",1,42,24,65,190),"WIND_R_02":("wind",1,44,22,62,185),
 "WIND_SR_01":("wind",2,72,38,80,330),"WIND_SSR_01":("wind",3,115,58,95,560),
 "WIND_UR_01":("wind",4,165,90,110,880),
 "TIDE_R_01":("tide",1,38,30,52,210),"TIDE_R_02":("tide",1,40,28,50,205),
 "TIDE_SR_01":("tide",2,68,48,58,350),"TIDE_SSR_01":("tide",3,108,70,74,600),
 "TIDE_UR_01":("tide",4,158,105,88,960)}
SHIPS = {"SHIP_RAFT":("light",20,1.00,1.00),"SHIP_IRON":("heavy",55,1.00,1.08),
         "SHIP_FLAME":("light",25,1.06,1.00)}
GUARDS = {
 "FR_02":(["IRON_R_01","IRON_R_02","IRON_SR_01"],1.00),
 "FR_03":(["IRON_R_01","IRON_R_02","WIND_R_01"],1.00),
 "FR_04":(["IRON_R_01","IRON_SR_01","IRON_SSR_01"],1.00),
 "FR_05":(["IRON_R_02","IRON_SR_01","TIDE_R_01"],1.00),
 "FR_06":(["IRON_SSR_01","IRON_SR_01","IRON_R_01","IRON_R_02","FLAME_R_01"],1.35),
 "FR_07":(["IRON_R_01","WIND_R_02","IRON_SR_01"],1.00),
 "FR_08":(["IRON_R_02","IRON_SSR_01","TIDE_R_02"],1.00),
 "FR_09":(["IRON_SSR_01","IRON_SR_01","IRON_UR_01","IRON_R_01","WIND_R_01"],1.35),
 "FR_10":(["IRON_SR_01","IRON_R_01","IRON_R_02"],1.00),
 "FR_11":(["IRON_R_01","WIND_SR_01","IRON_SR_01"],1.00),
 "FR_12":(["IRON_UR_01","IRON_SSR_01","IRON_SR_01","TIDE_SSR_01","WIND_SSR_01"],1.80)}
ISL_HP = {"FR_02":800,"FR_03":800,"FR_04":800,"FR_05":800,"FR_06":2400,"FR_07":800,
          "FR_08":800,"FR_09":2400,"FR_10":800,"FR_11":800,"FR_12":5000}
STARTER = ["IRON_R_01","IRON_R_02","IRON_SR_01","FLAME_R_01","FLAME_R_02","FLAME_SR_01",
           "WIND_R_01","WIND_R_02","TIDE_R_01","TIDE_R_02","FLAME_SSR_01","IRON_SSR_01"]
ALL = list(CARDS)
TC = {"physical":{"light":1.0,"heavy":0.7,"shield":1.15},
      "burn":{"light":1.2,"heavy":0.85,"shield":1.0},
      "energy":{"light":1.1,"heavy":0.8,"shield":0.6}}
DT = {"flame":"burn","ironwall":"physical","wind":"physical","tide":"energy"}
RING = {"flame":"ironwall","ironwall":"wind","wind":"tide","tide":"flame"}
ENV = {"ironwall":1.15,"flame":0.95,"wind":1.0,"tide":1.0}
FACE = {"WIND_R_01":2,"WIND_R_02":2,"WIND_SR_01":2,"WIND_SSR_01":3,"WIND_UR_01":4}
SEG_DECAY = 0.60
MAX_ROUND = 30

def build(ids, ship_id, side, hp_mult=1.0):
    at, ar, am, dm = SHIPS[ship_id]
    out = []
    for i, cid in enumerate(ids):
        s, cost, atk, dfv, spd, hp = CARDS[cid]
        out.append({"cid":cid,"sys":s,"atk":atk*am*ENV[s],"def":dfv*dm+ar,"spd":spd,
                    "hp":hp*hp_mult,"arm":at,"side":side,"slot":i,
                    "seg":FACE.get(cid,1)})
    return out

def dmg(u, t):
    r = 1.3 if RING[u["sys"]] == t["sys"] else (1/1.3 if RING[t["sys"]] == u["sys"] else 1.0)
    base = u["atk"] * r * TC[DT[u["sys"]]][t["arm"]] * (1 - t["def"]/(t["def"]+100.0))
    return sum(max(1, round(base * SEG_DECAY**k)) for k in range(u["seg"]))

def resolve(A, B):
    A = [dict(u) for u in A]; B = [dict(u) for u in B]
    order = sorted(A+B, key=lambda u: (-u["spd"], u["side"], u["slot"]))
    for _ in range(MAX_ROUND):
        for u in order:
            if u["hp"] <= 0: continue
            foes = [x for x in (B if u["side"] == 0 else A) if x["hp"] > 0]
            if not foes: break
            t = min(foes, key=lambda x: x["slot"])
            t["hp"] -= dmg(u, t)
        la = sum(1 for x in A if x["hp"] > 0); lb = sum(1 for x in B if x["hp"] > 0)
        if la == 0 or lb == 0:
            return 0 if lb == 0 and la > 0 else (1 if la == 0 and lb > 0 else -1)
    ha = sum(max(0, x["hp"]) for x in A); hb = sum(max(0, x["hp"]) for x in B)
    return 0 if ha >= hb else 1          # 平局 HP → A（挑战方）胜

def legal(pool):
    out = []
    for n in range(1, 6):
        for c in combinations(pool, n):
            if sum(CARDS[i][1] for i in c) > 10: continue
            cnt = {}
            for i in c: cnt[CARDS[i][0]] = cnt.get(CARDS[i][0], 0)+1
            if max(cnt.values()) > 4: continue
            out.append(c)
    return out

for label, pool, ships in ([] if __name__ != "__main__" else
                          [("起始 12 卡 / 木筏", STARTER, ["SHIP_RAFT"]),
                           ("全收集 20 卡 / 三船", ALL, list(SHIPS))]):
    fleets = legal(pool)
    print(f"\n=== {label}：合法编队 {len(fleets)} × 船 {len(ships)} ===")
    print(f"{'岛':>6}{'tier':>7}{'实际HP':>8}{'标称HP':>8}{'可胜编队':>10}{'胜率%':>8}  最优编队")
    for iid in sorted(GUARDS):
        ids, hm = GUARDS[iid]
        G = build(ids, "SHIP_IRON", 1, hm)
        real_hp = int(sum(u["hp"] for u in G))
        win = 0; best = None
        for sh in ships:
            for f in fleets:
                if resolve(build(list(f), sh, 0), G) == 0:
                    win += 1
                    if best is None: best = (sh, f)
        tot = len(fleets)*len(ships)
        tier = "boss" if iid == "FR_12" else ("heavy" if hm > 1.0 else "light")
        b = f"{best[0]}+{'/'.join(best[1])}" if best else "—— 无解 ——"
        print(f"{iid:>6}{tier:>7}{real_hp:>8}{ISL_HP[iid]:>8}{win:>10}{win/tot*100:>8.1f}  {b}")
