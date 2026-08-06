# -*- coding: utf-8 -*-
# 进度曲线：起始 deck / 全收集 deck vs light/heavy/boss 守卫（一阶 DPR-vs-EHP 模型）
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
DECAY=0.6
def seg(cid,s):  return FACE[cid] if s=="wind" else 1     # 采用修正案 C
def coefof(s,gs): return 1.3 if RING[s]==gs else (1/1.3 if RING[gs]==s else 1.0)

def unit_dmg(atk,s,cid,gdef,garm,gsys,fix=True):
    base=atk*ENV[s]*coefof(s,gsys)*TC[DT[s]][garm]*(1-gdef/(gdef+100.0))
    if s!="wind": return max(1,round(base))
    n=seg(cid,s)
    if fix: return sum(max(1,round(base*(DECAY**k))) for k in range(n))
    n2=1+max(0,min(2,[c for c in CARDS if c[0]==cid][0][6-1]//20-1))
    return max(1,round(base))*n2

# 守卫规格（本次设计补齐，冻洋=ironwall 体系，重甲）
GUARDS={ # tier: (units, atk_each, def_each, hp_total, sys, armor)
 "light":(2, 46, 40,  800,"ironwall","heavy"),
 "heavy":(3, 78, 70, 2400,"ironwall","heavy"),
 "boss" :(5,112,100, 5000,"ironwall","heavy"),
}
# 玩家船：逆风铠 armorType=heavy, armor(def加成)=+0 ; 简化玩家护甲用卡 def
def eval_fleet(fleet,tier,fix=True):
    n,gatk,gdef,ghp,gsys,garm=GUARDS[tier]
    pdpr=sum(unit_dmg(c[3],c[1],c[0],gdef,garm,gsys,fix) for c in fleet)
    # 守卫对玩家：物理打玩家（假设玩家船 heavy 重甲 → typeCoef 0.7）
    php=sum(c[6] for c in fleet); pdef=sum(c[4] for c in fleet)/len(fleet)
    gdmg_each=max(1,round(gatk*ENV[gsys]*1.0*0.7*(1-pdef/(pdef+100.0))))  # 守卫 ironwall 对玩家混编按 1.0 均值
    gdpr=gdmg_each*n
    r_kill=ghp/pdpr; r_die=php/gdpr
    return pdpr,gdpr,r_kill,r_die,(r_kill<r_die and r_kill<=30)

def best(pool,tier,fix=True):
    bb=None
    for k in range(1,6):
        for cb in combinations(pool,k):
            if sum(c[2] for c in cb)>10: continue
            if max(Counter(c[1] for c in cb).values())>4: continue
            r=eval_fleet(cb,tier,fix)
            score=(r[3]-r[2])          # 余量越大越好
            if bb is None or score>bb[0]: bb=(score,cb,r)
    return bb

full=CARDS; start=[c for c in CARDS if c[0] in STARTER]
for label,pool in [("起始 deck(12张:每体系 R/R/SR)",start),("全收集(20张)",full)]:
    print(f"\n########## {label} ##########")
    for tier in ["light","heavy","boss"]:
        s,cb,r=best(pool,tier)
        print(f"[{tier:5s}] 最优队={[c[0] for c in cb]}")
        print(f"        玩家DPR={r[0]:4d}  守卫DPR={r[1]:4d}  击杀需{r[2]:5.1f}回合  阵亡需{r[3]:5.1f}回合  {'可胜' if r[4] else '★不可胜'}")

# 可胜编队占比（全收集，boss）
for tier in ["heavy","boss"]:
    tot=win=0
    for k in range(1,6):
        for cb in combinations(full,k):
            if sum(c[2] for c in cb)>10: continue
            if max(Counter(c[1] for c in cb).values())>4: continue
            tot+=1
            if eval_fleet(cb,tier)[4]: win+=1
    print(f"\n全收集下 [{tier}] 可胜编队 {win}/{tot} = {win/tot*100:.1f}%")
