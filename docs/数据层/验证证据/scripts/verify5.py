# -*- coding: utf-8 -*-
# 守卫规格标定：在 GUARD_HP 冻结值不变的前提下，求 (units, atk, def) 使进度曲线达标
from itertools import combinations
from collections import Counter
CARDS=[("FLAME_R_01","flame",1,40,25,50,200),("FLAME_R_02","flame",1,45,22,48,190),("FLAME_SR_01","flame",2,70,40,55,340),
("FLAME_SSR_01","flame",3,110,60,72,580),("FLAME_UR_01","flame",4,160,95,85,900),
("IRON_R_01","ironwall",1,35,45,38,260),("IRON_R_02","ironwall",1,33,50,35,280),("IRON_SR_01","ironwall",2,60,75,42,460),
("IRON_SSR_01","ironwall",3,95,115,50,760),("IRON_UR_01","ironwall",4,140,170,55,1150),
("WIND_R_01","wind",1,42,24,65,190),("WIND_R_02","wind",1,44,22,62,185),("WIND_SR_01","wind",2,72,38,80,330),
("WIND_SSR_01","wind",3,115,58,95,560),("WIND_UR_01","wind",4,165,90,110,880),
("TIDE_R_01","tide",1,38,30,52,210),("TIDE_R_02","tide",1,40,28,50,205),("TIDE_SR_01","tide",2,68,48,58,350),
("TIDE_SSR_01","tide",3,108,70,74,600),("TIDE_UR_01","tide",4,158,105,88,960)]
STARTER={"FLAME_R_01","FLAME_R_02","FLAME_SR_01","IRON_R_01","IRON_R_02","IRON_SR_01",
         "WIND_R_01","WIND_R_02","WIND_SR_01","TIDE_R_01","TIDE_R_02","TIDE_SR_01"}
TC={"physical":{"light":1.0,"heavy":0.7,"shield":1.15},"burn":{"light":1.2,"heavy":0.85,"shield":1.0},
    "energy":{"light":1.1,"heavy":0.8,"shield":0.6}}
DT={"flame":"burn","ironwall":"physical","wind":"physical","tide":"energy"}
ENV={"ironwall":1.15,"flame":0.95,"wind":1.0,"tide":1.0}
RING={"flame":"ironwall","ironwall":"wind","wind":"tide","tide":"flame"}
FACE={"WIND_R_01":2,"WIND_R_02":2,"WIND_SR_01":2,"WIND_SSR_01":3,"WIND_UR_01":4}
DECAY=0.6; ATTR=0.6   # 减员衰减系数（一阶近似：战斗过程中平均 60% 火力在线）

def udmg(c,gdef,garm,gsys):
    cid,s,cost,atk,d,spd,hp=c
    base=atk*ENV[s]*(1.3 if RING[s]==gsys else (1/1.3 if RING[gsys]==s else 1.0))*TC[DT[s]][garm]*(1-gdef/(gdef+100.0))
    if s!="wind": return max(1,round(base))
    return sum(max(1,round(base*(DECAY**k))) for k in range(FACE[cid]))

def fight(fleet,G):
    n,gatk,gdef,ghp,gsys,garm=G
    pdpr=sum(udmg(c,gdef,garm,gsys) for c in fleet)
    php=sum(c[6] for c in fleet); pdef=sum(c[4] for c in fleet)/len(fleet)
    gper=max(1,round(gatk*ENV[gsys]*0.7*(1-pdef/(pdef+100.0))))
    gdpr=gper*n
    rk=ghp/(pdpr*ATTR)                       # 玩家也减员
    dmg_taken=gdpr*ATTR*rk
    return rk, php, dmg_taken, (rk<=30 and dmg_taken<php)

def winrate(pool,G):
    tot=w=0; bestmargin=-9; bestcb=None
    for k in range(1,6):
        for cb in combinations(pool,k):
            if sum(c[2] for c in cb)>10: continue
            if max(Counter(c[1] for c in cb).values())>4: continue
            tot+=1; rk,php,dt,ok=fight(cb,G)
            if ok:
                w+=1; m=php/dt
                if m>bestmargin: bestmargin,bestcb=m,(cb,rk)
    return w,tot,bestcb

full=CARDS; start=[c for c in CARDS if c[0] in STARTER]
CAND={
 "light":[(2,52,35,800),(2,52,45,800)],
 "heavy":[(3,74,60,2400),(3,74,70,2400),(3,82,65,2400)],
 "boss" :[(4,92,50,5000),(4,92,60,5000),(5,78,55,5000),(4,100,55,5000),(4,86,55,5000)],
}
for tier,cands in CAND.items():
    print(f"\n===== {tier} =====")
    for (n,atk,dfn,hp) in cands:
        G=(n,atk,dfn,hp,"ironwall","heavy")
        ws,ts,_=winrate(start,G); wf,tf,bf=winrate(full,G)
        rk = f"{bf[1]:.1f}" if bf else "-"
        print(f"  units={n} atk={atk} def={dfn}: 起始deck胜率={ws/ts*100:5.1f}%  全收集胜率={wf/tf*100:5.1f}%  最优队击杀回合≈{rk}")
