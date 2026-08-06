# -*- coding: utf-8 -*-
# Demo D5：strategic 单池 30 步压测（单人切片）
P0 = 50_000
POI_RES = 500            # 每个 resource POI 产出
POI_COST, VOY_COST, BATTLE_COST = 8, 12, 20
STAMINA = 120
YIELD  = {"start":0,   "light":120, "heavy":360, "boss":900}   # 链下 strategic 日产
UPKEEP = {"start":0,   "light":50,  "heavy":175, "boss":500}   # 链下 strategic 日维护
DIV_TIDE={"start":0,   "light":1,   "heavy":3,   "boss":8}     # 链上 $TIDE 日分红（从赛季池划拨）
# 岛屿：tier 与其上的 resource POI 数
ISL = [("FR_01","start",1),("FR_02","light",1),("FR_03","light",1),("FR_04","light",0),
       ("FR_05","light",1),("FR_06","heavy",1),("FR_07","light",0),("FR_08","light",1),
       ("FR_09","heavy",1),("FR_10","light",0),("FR_11","light",1),("FR_12","boss",0)]
# 占领进度表（设计假设：体力与战力约束下的典型节奏）
SCHED = {1:["FR_01"],3:["FR_02"],5:["FR_03"],7:["FR_04"],9:["FR_05"],11:["FR_07"],
         13:["FR_08"],15:["FR_10"],17:["FR_11"],20:["FR_06"],24:["FR_09"],28:["FR_12"]}
DECAY = lambda n: max(0.40, 1.0 - 0.06*(n-1))   # 第 n 个岛的产出递减系数

# 主动 sink（玩家行为，日均）
CREW_LEVEL, SHIP_UP = 1200, 1500

pool, owned, tide = P0, [], 0
print(f"{'日':>3}{'占岛':>5}{'POI产':>7}{'日产':>7}{'维护':>7}{'养成':>7}{'造船':>7}{'补给':>7}{'净流':>8}{'池存量':>10}{'通胀%':>7}{'$TIDE':>7}")
rows=[]
for d in range(1,31):
    for i in SCHED.get(d,[]): owned.append(i)
    tinfo={i:t for i,t,_ in ISL}; poin={i:p for i,_,p in ISL}
    # 日产（按占领顺序递减）
    yld=sum(round(YIELD[tinfo[i]]*DECAY(k+1)) for k,i in enumerate(owned))
    upk=sum(UPKEEP[tinfo[i]] for i in owned)
    div=sum(DIV_TIDE[tinfo[i]] for i in owned)
    # POI：可探索 = 已占岛 + 1 个前沿岛；受体力约束
    reach=len(owned)+1
    res_poi=sum(p for i,_,p in ISL[:min(reach,12)])
    voy = min(3, max(1, reach//3)); battles = 1 if d in SCHED else 0
    sta_used = voy*VOY_COST + battles*BATTLE_COST
    poi_afford = max(0,(STAMINA - sta_used)//POI_COST)
    poi_n = min(res_poi, poi_afford)
    poi_income = poi_n*POI_RES
    supply = voy*100
    src = poi_income + yld
    snk = upk + CREW_LEVEL + SHIP_UP + supply
    net = src - snk
    open_pool = pool
    pool += net; tide += div
    infl = net/open_pool*100
    rows.append((d,len(owned),poi_income,yld,upk,CREW_LEVEL,SHIP_UP,supply,net,pool,infl,tide))
    if d<=6 or d%3==0 or d>=28:
        print(f"{d:>3}{len(owned):>5}{poi_income:>7}{yld:>7}{upk:>7}{CREW_LEVEL:>7}{SHIP_UP:>7}{supply:>7}{net:>8}{pool:>10}{infl:>7.2f}{tide:>7}")
mx=max(r[10] for r in rows)
print(f"\n峰值日通胀率 = {mx:.2f}%/天 （D5 阈值 5%）  {'✅ 通过' if mx<=5 else '❌ 超标'}")
print(f"30 日末 strategic 池 = {pool:,}（初始 {P0:,}，累计 {(pool-P0)/P0*100:.1f}%）")
print(f"30 日累计 $TIDE 分红 = {tide}（全部来自赛季奖励池划拨，非新铸 → net_issuance ≤ 0 恒成立）")
print(f"体力占用峰值 = {voy*VOY_COST + BATTLE_COST + poi_n*POI_COST}/{STAMINA}")
