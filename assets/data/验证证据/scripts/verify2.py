# -*- coding: utf-8 -*-
# 克制环有效性 / 段数修正案对比
from itertools import combinations
from collections import Counter

CARDS = [
 ("FLAME_R_01","flame","R",1,40,25,50,200),("FLAME_R_02","flame","R",1,45,22,48,190),
 ("FLAME_SR_01","flame","SR",2,70,40,55,340),("FLAME_SSR_01","flame","SSR",3,110,60,72,580),
 ("FLAME_UR_01","flame","UR",4,160,95,85,900),
 ("IRON_R_01","ironwall","R",1,35,45,38,260),("IRON_R_02","ironwall","R",1,33,50,35,280),
 ("IRON_SR_01","ironwall","SR",2,60,75,42,460),("IRON_SSR_01","ironwall","SSR",3,95,115,50,760),
 ("IRON_UR_01","ironwall","UR",4,140,170,55,1150),
 ("WIND_R_01","wind","R",1,42,24,65,190),("WIND_R_02","wind","R",1,44,22,62,185),
 ("WIND_SR_01","wind","SR",2,72,38,80,330),("WIND_SSR_01","wind","SSR",3,115,58,95,560),
 ("WIND_UR_01","wind","UR",4,165,90,110,880),
 ("TIDE_R_01","tide","R",1,38,30,52,210),("TIDE_R_02","tide","R",1,40,28,50,205),
 ("TIDE_SR_01","tide","SR",2,68,48,58,350),("TIDE_SSR_01","tide","SSR",3,108,70,74,600),
 ("TIDE_UR_01","tide","UR",4,158,105,88,960),
]
TYPE_COEF={"physical":{"light":1.0,"heavy":0.7,"shield":1.15},
           "burn":{"light":1.2,"heavy":0.85,"shield":1.0},
           "energy":{"light":1.1,"heavy":0.8,"shield":0.6}}
DMG_TYPE={"flame":"burn","ironwall":"physical","wind":"physical","tide":"energy"}
ENV={"ironwall":1.15,"flame":0.95,"wind":1.0,"tide":1.0}
RING={"flame":"ironwall","ironwall":"wind","wind":"tide","tide":"flame"}
FACE={"WIND_R_01":2,"WIND_R_02":2,"WIND_SR_01":2,"WIND_SSR_01":3,"WIND_UR_01":4}

def hits_cur(cid,s,spd):
    return 1+max(0,min(2,spd//20-1)) if s=="wind" else 1
def hits_fix(cid,s,spd):
    if s!="wind": return 1
    return min(FACE[cid]+ (1 if spd>=100 else 0), FACE[cid]+2)  # 修正案：卡面基础段 + 阈值奖励(spd>=100 +1)

def eff(card,gdef,garmor,gsys,hfn):
    cid,s,r,cost,atk,d,spd,hp=card
    coef=1.3 if RING[s]==gsys else (1/1.3 if RING[gsys]==s else 1.0)
    t=TYPE_COEF[DMG_TYPE[s]][garmor]
    ar=gdef/(gdef+100.0)
    return max(1,round(atk*ENV[s]*coef*t*(1.0-ar)))*hfn(cid,s,spd)

def report(hfn,label):
    print(f"\n===== {label} · vs 冻洋守卫(ironwall/重甲/def=80) =====")
    rows=[(eff(c,80,"heavy","ironwall",hfn)/c[3],c[0],c[1],c[3],eff(c,80,"heavy","ironwall",hfn)) for c in CARDS]
    for x in sorted(rows,reverse=True)[:8]:
        print(f"  {x[0]:7.1f}/cost {x[1]:14s} {x[2]:9s} cost={x[3]} 单回合={x[4]}")
    # 各体系 均值/cost
    print("  体系均值/cost:", {s: round(sum(r[0] for r in rows if r[2]==s)/5,1) for s in ["flame","ironwall","wind","tide"]})
    best=None
    for n in range(1,6):
        for cb in combinations(CARDS,n):
            if sum(c[3] for c in cb)>10: continue
            if max(Counter(c[1] for c in cb).values())>4: continue
            dpr=sum(eff(c,80,"heavy","ironwall",hfn) for c in cb)
            if best is None or dpr>best[0]: best=(dpr,[c[0] for c in cb])
    print(f"  最优队 DPR={best[0]}  {best[1]}   heavy(2400) 需 {2400/best[0]:.1f} 回合  boss(5000,def120) 需 ...")

report(hits_cur,"现状（代码公式 1+clamp(spd//20-1,0,2)）")
report(hits_fix,"修正案 A（卡面基础段 + spd>=100 再 +1）")

# 克制环有效性指数：克制方 vs 被克方 同 cost 效率比
print("\n===== 克制环有效性指数（同 COST，克制方效率 ÷ 被克方效率，理论应 ≈1.3×1.3=1.69）=====")
for hfn,lab in [(hits_cur,"现状"),(hits_fix,"修正案A")]:
    # flame(克 ironwall) vs wind(被 ironwall 克)，均打 ironwall 重甲桩
    f=[eff(c,80,"heavy","ironwall",hfn)/c[3] for c in CARDS if c[1]=="flame"]
    w=[eff(c,80,"heavy","ironwall",hfn)/c[3] for c in CARDS if c[1]=="wind"]
    print(f"  {lab}: 克制方flame均值={sum(f)/5:.1f}/cost  被克方wind均值={sum(w)/5:.1f}/cost  比值={sum(f)/sum(w):.2f}（应>1）")
