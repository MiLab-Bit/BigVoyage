# -*- coding: utf-8 -*-
# BigVoyage 数值校验脚本（策划侧自用，不进工程）
from itertools import combinations
from collections import Counter

CARDS = [
 # id, sys, rarity, cost, atk, dfn, spd, hp
 ("FLAME_R_01","flame","R",1,40,25,50,200),
 ("FLAME_R_02","flame","R",1,45,22,48,190),
 ("FLAME_SR_01","flame","SR",2,70,40,55,340),
 ("FLAME_SSR_01","flame","SSR",3,110,60,72,580),
 ("FLAME_UR_01","flame","UR",4,160,95,85,900),
 ("IRON_R_01","ironwall","R",1,35,45,38,260),
 ("IRON_R_02","ironwall","R",1,33,50,35,280),
 ("IRON_SR_01","ironwall","SR",2,60,75,42,460),
 ("IRON_SSR_01","ironwall","SSR",3,95,115,50,760),
 ("IRON_UR_01","ironwall","UR",4,140,170,55,1150),
 ("WIND_R_01","wind","R",1,42,24,65,190),
 ("WIND_R_02","wind","R",1,44,22,62,185),
 ("WIND_SR_01","wind","SR",2,72,38,80,330),
 ("WIND_SSR_01","wind","SSR",3,115,58,95,560),
 ("WIND_UR_01","wind","UR",4,165,90,110,880),
 ("TIDE_R_01","tide","R",1,38,30,52,210),
 ("TIDE_R_02","tide","R",1,40,28,50,205),
 ("TIDE_SR_01","tide","SR",2,68,48,58,350),
 ("TIDE_SSR_01","tide","SSR",3,108,70,74,600),
 ("TIDE_UR_01","tide","UR",4,158,105,88,960),
]
CAP, SLOTS, SOFT = 10, 5, 4

# ---------- 1. 合法编队数 ----------
legal = 0
by_size = Counter()
for n in range(1, SLOTS+1):
    for combo in combinations(CARDS, n):
        if sum(c[3] for c in combo) > CAP: continue
        cnt = Counter(c[1] for c in combo)
        if max(cnt.values()) > SOFT: continue
        legal += 1
        by_size[n] += 1
print("合法编队总数(不含空队, 不计顺序):", legal)
print("  按槽数:", dict(by_size))

# ---------- 2. 每 COST 输出效率（对 def=0 假想桩, 无克制无护甲） ----------
# hits: 疾风 multi -> extra = max(0, min(2, spd//20 - 1)); 其余 1 段
def hits(sysname, spd):
    if sysname != "wind": return 1
    return 1 + max(0, min(2, spd//20 - 1))

print("\n--- 单回合裸输出 / COST（def=0 桩，无克制、无 typeCoef）---")
rows=[]
for cid,s,r,cost,atk,d,spd,hp in CARDS:
    h = hits(s,spd)
    dmg = atk*h
    rows.append((dmg/cost, cid, s, r, cost, atk, spd, h, dmg))
for x in sorted(rows, reverse=True):
    print(f"{x[0]:7.1f}/cost  {x[1]:14s} {x[2]:8s} {x[3]:3s} cost={x[4]} atk={x[5]:3d} spd={x[6]:3d} 段={x[7]} 单回合={x[8]}")

# ---------- 3. 段数公式压平验证 ----------
print("\n--- 疾风段数：卡面声明 vs 代码公式 ---")
face = {"WIND_R_01":2,"WIND_R_02":2,"WIND_SR_01":2,"WIND_SSR_01":3,"WIND_UR_01":4}
for cid,s,r,cost,atk,d,spd,hp in CARDS:
    if s!="wind": continue
    print(f"{cid:12s} spd={spd:3d}  卡面={face[cid]} 段   公式={hits(s,spd)} 段   {'一致' if face[cid]==hits(s,spd) else '★不一致'}")

# ---------- 4. 守卫强度 vs 玩家最强编队（粗算总有效输出） ----------
# 简化：只算 30 回合内玩家总输出 vs 守卫 hp；守卫 def 设 tier 相关
TYPE_COEF = {  # 伤害类型 -> {护甲类型: 系数}
  "physical": {"light":1.0,"heavy":0.7,"shield":1.15},
  "burn":     {"light":1.2,"heavy":0.85,"shield":1.0},
  "energy":   {"light":1.1,"heavy":0.8,"shield":0.6},
}
DMG_TYPE = {"flame":"burn","ironwall":"physical","wind":"physical","tide":"energy"}
ENV = {"ironwall":1.15,"flame":0.95,"wind":1.0,"tide":1.0}
RING = {"flame":"ironwall","ironwall":"wind","wind":"tide","tide":"flame"}

def dmg_round(card, guard_def, guard_armor, guard_sys):
    cid,s,r,cost,atk,d,spd,hp = card
    coef = 1.0
    if RING[s]==guard_sys: coef = 1.3
    elif RING[guard_sys]==s: coef = 1/1.3
    tcoef = TYPE_COEF[DMG_TYPE[s]][guard_armor]
    armor_ratio = guard_def/(guard_def+100.0)
    raw = atk*ENV[s]*coef*tcoef*(1.0-armor_ratio)
    return max(1, round(raw))*hits(s,spd)

# 守卫：冻洋 = ironwall 体系，重甲
for tier,ghp,gdef in [("light",800,40),("heavy",2400,80),("boss",5000,120)]:
    best=None
    for n in range(1,SLOTS+1):
        for combo in combinations(CARDS,n):
            if sum(c[3] for c in combo)>CAP: continue
            cnt=Counter(c[1] for c in combo)
            if max(cnt.values())>SOFT: continue
            dpr=sum(dmg_round(c,gdef,"heavy","ironwall") for c in combo)
            if best is None or dpr>best[0]: best=(dpr,[c[0] for c in combo])
    print(f"\n[{tier}] guard_hp={ghp} def={gdef}  玩家最强队 DPR={best[0]}  需回合={ghp/best[0]:.1f}  队伍={best[1]}")
