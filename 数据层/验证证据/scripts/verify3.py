# -*- coding: utf-8 -*-
# 疾风段数修正案 A/B/C/D 对比 —— 目标：克制环有效性指数 ≥1.0，体系均值极差 ≤1.35x
from itertools import combinations
from collections import Counter
CARDS=[("FLAME_R_01","flame",1,40,25,50),("FLAME_R_02","flame",1,45,22,48),("FLAME_SR_01","flame",2,70,40,55),
("FLAME_SSR_01","flame",3,110,60,72),("FLAME_UR_01","flame",4,160,95,85),
("IRON_R_01","ironwall",1,35,45,38),("IRON_R_02","ironwall",1,33,50,35),("IRON_SR_01","ironwall",2,60,75,42),
("IRON_SSR_01","ironwall",3,95,115,50),("IRON_UR_01","ironwall",4,140,170,55),
("WIND_R_01","wind",1,42,24,65),("WIND_R_02","wind",1,44,22,62),("WIND_SR_01","wind",2,72,38,80),
("WIND_SSR_01","wind",3,115,58,95),("WIND_UR_01","wind",4,165,90,110),
("TIDE_R_01","tide",1,38,30,52),("TIDE_R_02","tide",1,40,28,50),("TIDE_SR_01","tide",2,68,48,58),
("TIDE_SSR_01","tide",3,108,70,74),("TIDE_UR_01","tide",4,158,105,88)]
TC={"physical":{"light":1.0,"heavy":0.7,"shield":1.15},"burn":{"light":1.2,"heavy":0.85,"shield":1.0},
    "energy":{"light":1.1,"heavy":0.8,"shield":0.6}}
DT={"flame":"burn","ironwall":"physical","wind":"physical","tide":"energy"}
ENV={"ironwall":1.15,"flame":0.95,"wind":1.0,"tide":1.0}
RING={"flame":"ironwall","ironwall":"wind","wind":"tide","tide":"flame"}
FACE={"WIND_R_01":2,"WIND_R_02":2,"WIND_SR_01":2,"WIND_SSR_01":3,"WIND_UR_01":4}

def seg_now(cid,s,spd): return 1+max(0,min(2,spd//20-1)) if s=="wind" else 1
def seg_face(cid,s,spd): return FACE[cid] if s=="wind" else 1

def dmg(card,gdef,garm,gsys,opt):
    cid,s,cost,atk,d,spd=card
    coef=1.3 if RING[s]==gsys else (1/1.3 if RING[gsys]==s else 1.0)
    ar=gdef/(gdef+100.0); base=atk*ENV[s]*coef*TC[DT[s]][garm]*(1.0-ar)
    if s!="wind": return max(1,round(base))
    if opt=="now":  return max(1,round(base))*seg_now(cid,s,spd)
    if opt=="A":    return max(1,round(base))*seg_face(cid,s,spd)
    if opt=="B":    # 段衰减 0.6
        n=seg_now(cid,s,spd); return sum(max(1,round(base*(0.6**k))) for k in range(n))
    if opt=="C":    # 卡面段数 + 段衰减 0.6
        n=seg_face(cid,s,spd); return sum(max(1,round(base*(0.6**k))) for k in range(n))
    if opt=="D":    # 单回合总攻预算制：atk×1.15 分 N 段（N=卡面段）
        n=seg_face(cid,s,spd); per=base*1.15/n; return sum(max(1,round(per)) for _ in range(n))

def stats(opt):
    rows=[(dmg(c,80,"heavy","ironwall",opt)/c[2],c[0],c[1],c[2],dmg(c,80,"heavy","ironwall",opt)) for c in CARDS]
    m={s:sum(r[0] for r in rows if r[2]==s)/5 for s in ["flame","ironwall","wind","tide"]}
    ring=m["flame"]/m["wind"]      # flame 克 ironwall / wind 被 ironwall 克 —— 打同一 ironwall 桩
    spread=max(m.values())/min(m.values())
    top=sorted(rows,reverse=True)[0]
    best=None
    for n in range(1,6):
        for cb in combinations(CARDS,n):
            if sum(c[2] for c in cb)>10: continue
            if max(Counter(c[1] for c in cb).values())>4: continue
            dp=sum(dmg(c,80,"heavy","ironwall",opt) for c in cb)
            if best is None or dp>best[0]: best=(dp,[c[0] for c in cb])
    syscnt=Counter(x.split("_")[0] for x in best[1])
    return m,ring,spread,top,best,syscnt

names={"now":"现状(代码)","A":"A 卡面段数","B":"B 段衰减0.6(保留现段数)","C":"C 卡面段数+段衰减0.6","D":"D 总攻预算制(atk×1.15/N)"}
print(f"{'方案':<26}{'ring指数':>9}{'体系极差':>9}  最强单卡            最优队体系分布")
for opt in ["now","A","B","C","D"]:
    m,ring,spread,top,best,sc=stats(opt)
    print(f"{names[opt]:<26}{ring:9.2f}{spread:9.2f}  {top[1]:<14}{top[0]:5.1f}/c  {dict(sc)} DPR={best[0]}")
    print(f"{'':26}体系均值/cost: "+" ".join(f"{k}={v:.1f}" for k,v in m.items()))
print("\n判定标准：ring指数 ≥1.00（克制方效率必须高于被克方）；体系极差 ≤1.35（无主导体系）")
