# -*- coding: utf-8 -*-
# econ31：修订体力口径后的 D5 30 步压测
# 修订点（相对 econ30）：POI 单次仅 1 体力（Demo 契约 D2 断言硬锁），
# 真正的稀缺性改由「POI 每日充能次数 charges」+「航行体力」共同提供。
POI_STA        = 1        # D2 契约锁
VOY_STA        = 8        # 顺流相邻单跳
BATTLE_STA     = 20       # 挑战守卫
STAMINA        = 120
CHARGES = {"resource":2, "crew":2, "ship":1, "boss":1, "crew_ur":1}
YIELD_POI = {"resource":500, "crew":0, "ship":0, "boss":3000, "crew_ur":0}
POI = {"FR_01":["crew","resource"],"FR_02":["crew","resource"],"FR_03":["resource"],
       "FR_04":["crew","ship"],"FR_05":["resource"],"FR_06":["crew","ship","resource"],
       "FR_07":["crew"],"FR_08":["resource"],"FR_09":["crew","resource"],
       "FR_10":["ship"],"FR_11":["crew","resource"],"FR_12":["boss","crew_ur"]}
ADJ = {"FR_01":["FR_02","FR_04"],"FR_02":["FR_01","FR_03","FR_05"],
       "FR_03":["FR_02","FR_06","FR_07"],"FR_04":["FR_01","FR_05"],
       "FR_05":["FR_02","FR_04","FR_06","FR_09"],"FR_06":["FR_03","FR_05","FR_08","FR_10"],
       "FR_07":["FR_03","FR_08"],"FR_08":["FR_06","FR_07","FR_11"],
       "FR_09":["FR_05","FR_10"],"FR_10":["FR_06","FR_09","FR_11"],
       "FR_11":["FR_08","FR_10","FR_12"],"FR_12":["FR_11"]}
TIER = {"FR_01":"start","FR_02":"light","FR_03":"light","FR_04":"light","FR_05":"light",
        "FR_06":"heavy","FR_07":"light","FR_08":"light","FR_09":"heavy","FR_10":"light",
        "FR_11":"light","FR_12":"boss"}
# 护岛日产 / 维护 / $TIDE 分红（本文提案值）
YIELD  = {"start":0,"light":120,"heavy":360,"boss":900}
UPKEEP = {"start":0,"light":50, "heavy":175,"boss":500}
DIVTID = {"start":0,"light":1,  "heavy":3,  "boss":8}
DECAY  = lambda n: max(0.40, 1.0 - 0.06*(n-1))
# 占领节奏（受战力曲线约束的设计假设）
SCHED = {1:"FR_01",3:"FR_02",5:"FR_04",7:"FR_03",9:"FR_05",12:"FR_07",14:"FR_08",
         16:"FR_10",18:"FR_11",21:"FR_06",25:"FR_09",29:"FR_12"}
# 养成轴（B3 方案 1）：Lv1→10，每级 atk/hp +5%
LVL_BASE = {"R":120,"SR":240,"SSR":480,"UR":960}
DECK = [("R",8),("SR",4),("SSR",4),("UR",4)]
TOTAL_LVL_COST = sum(n*LVL_BASE[r]*sum(range(1,10)) for r,n in DECK)
SHIP_BUILD_TOTAL = 24000          # 2 艘进阶船
P0 = 20000                         # 初始池：新手远征拨款（设计提案）
SOFT_CAP = 20000                   # 囤积软上限
HOARD_DECAY = 0.10                 # 超出部分日衰减（物资受潮腐败）

def bfs(owned):
    """可达集 = 已占岛 ∪ 与已占岛相邻的前沿岛"""
    s = set(owned)
    for i in list(s):
        for j in ADJ[i]: s.add(j)
    return s

def hops_from_home(target, owned):
    d = {"FR_01":0}; q = ["FR_01"]
    while q:
        c = q.pop(0)
        for n in ADJ[c]:
            if n not in d: d[n] = d[c]+1; q.append(n)
    return d.get(target, 99)

pool, owned, tide = P0, [], 0
lvl_spent = 0; ship_spent = 0
rows = []
print(f"{'日':>3}{'占':>3}{'POI收':>7}{'日产':>6}{'维护':>6}{'养成':>7}{'造船':>7}{'补给':>6}"
      f"{'囤衰':>6}{'净流':>8}{'池存':>9}{'通胀%':>7}{'体力用':>7}{'$TIDE':>6}")
for d in range(1, 31):
    if d in SCHED: owned.append(SCHED[d])
    reach = bfs(owned)
    # ---- 体力预算规划（贪心：按 单位体力收益 降序取岛）----
    sta = STAMINA
    battle = 1 if d in SCHED and SCHED[d] != "FR_01" else 0
    sta -= battle*BATTLE_STA
    cand = []
    for i in sorted(reach):
        ch_cost = sum(CHARGES[p] for p in POI[i]) * POI_STA
        inc = sum(CHARGES[p]*YIELD_POI[p] for p in POI[i])
        if i == "FR_12" and "FR_12" not in owned: inc = 0     # boss POI 需先占岛
        hop = hops_from_home(i, owned) * VOY_STA
        cand.append((inc/max(1, ch_cost+hop), i, ch_cost+hop, inc))
    cand.sort(reverse=True)
    poi_income = 0; sta_used_poi = 0
    for _, i, c, inc in cand:
        if sta >= c:
            sta -= c; poi_income += inc; sta_used_poi += c
    # ---- 护岛 ----
    yld = sum(round(YIELD[TIER[i]]*DECAY(k+1)) for k, i in enumerate(owned))
    upk = sum(UPKEEP[TIER[i]] for i in owned)
    div = sum(DIVTID[TIER[i]] for i in owned)
    # ---- sink：养成（吃掉 60% 可支配盈余）/ 造船（日均摊）/ 补给 ----
    gross = poi_income + yld
    supply = (battle*200) + len(owned)*30
    disp = max(0, gross - upk - supply)
    lvl = min(int(disp*0.70), TOTAL_LVL_COST - lvl_spent); lvl_spent += lvl
    ship = min(int(disp*0.20), SHIP_BUILD_TOTAL - ship_spent); ship_spent += ship
    hoard = int(max(0, pool - SOFT_CAP) * HOARD_DECAY)
    net = gross - upk - supply - lvl - ship - hoard
    op = pool; pool += net; tide += div
    infl = net/max(1, op)*100
    rows.append((d, infl, pool))
    if d <= 6 or d % 3 == 0 or d >= 28:
        print(f"{d:>3}{len(owned):>3}{poi_income:>7}{yld:>6}{upk:>6}{lvl:>7}{ship:>7}{supply:>6}"
              f"{hoard:>6}{net:>8}{pool:>9}{infl:>7.2f}{STAMINA-sta:>7}{tide:>6}")
mx = max(r[1] for r in rows)
print(f"\n峰值日通胀 = {mx:.2f}%  (D5 阈值 5%) -> {'PASS' if mx <= 5 else 'FAIL'}")
print(f"30 日末池存 = {rows[-1][2]}   养成投入 = {lvl_spent}/{TOTAL_LVL_COST}"
      f"   造船投入 = {ship_spent}/{SHIP_BUILD_TOTAL}")
print(f"$TIDE 累计分红 = {tide}（来源：赛季奖励池划拨，非新铸 → net_issuance<=0 恒成立）")
# 体力缺口自检（G1）
full_ch = sum(sum(CHARGES[p] for p in POI[i]) for i in POI)*POI_STA
print(f"\nG1 体力缺口自检：全图巡游最短走廊 14 跳 = {14*VOY_STA} 体力，"
      f"全 POI 充能 = {full_ch} 体力，合计需求 {14*VOY_STA+full_ch} vs 供给 {STAMINA} "
      f"-> 缺口 {(14*VOY_STA+full_ch-STAMINA)/(14*VOY_STA+full_ch)*100:.1f}%")
