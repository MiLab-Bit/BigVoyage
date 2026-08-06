# -*- coding: utf-8 -*-
# BigVoyage Demo 经济终稿标定 v3
# 关键结构性修正（相对 v2）：
#   F1 体力成为真约束：STAMINA_COST_POI = 6（120 体力 -> 每日最多 20 次 POI，而全图 56 槽）
#   F2 POI 产出按 tier 梯度：yield = POI_RESOURCE_BASE(500) * TIER_YIELD_M[tier]
#   F3 sink 扩容：20 卡可升级 + 12 岛 dev0..4 + 主队突破 asc1
#   F4 sink 平滑：开发/升级改为「连续投入进度制」，不再攒够一次性付
#   F5 常驻 sink：领地维护费 = 0.40 * 护岛日产（每日强制扣除）
#   F6 护栏：池软顶 60000，超出部分日衰减 20%
import math, io, sys

OUT = r"C:\Users\Administrator\AppData\Local\Temp\bv\out_econ3.txt"
o = io.open(OUT, "w", encoding="utf-8")
def P(s=""):
    o.write(s + "\n"); o.flush()

# ---------- L1 冻结/既有常量 ----------
POI_RESOURCE_BASE = 500
ISLAND_DAILY_YIELD = 120
STAMINA_MAX = 120
DAILY_TARGET = 20000

# ---------- 新增 PLAYTEST_KNOB ----------
STAMINA_COST_POI  = 6
STAMINA_COST_RAID = 8
TIER_YIELD_M = {"start":0.6, "light":1.0, "heavy":2.0, "boss":4.0}   # POI 产出梯度
TIER_M       = {"start":0.5, "light":1.0, "heavy":2.5, "boss":6.0}   # 护岛日产梯度
SLOTS        = {"start":4,   "light":5,   "heavy":5,   "boss":2}
UPKEEP_RATE  = 0.40
POOL_SOFT_CAP = 60000
DECAY = 0.20
ADJ_BONUS = 0.10
DEV_BONUS = 0.25
DEV_MAX = 4

ISL = [
 ("FR_01","霜锚港","start",2),("FR_02","铁砧湾","light",3),("FR_03","雾骨礁","light",3),
 ("FR_04","寒铁崖","light",2),("FR_05","冰棱渡","light",4),("FR_06","黑曜岩岛","heavy",4),
 ("FR_07","断桅滩","light",2),("FR_08","极光哨","light",3),("FR_09","冻潮门","heavy",2),
 ("FR_10","玄冰冢","light",3),("FR_11","风啸角","light",3),("FR_12","渊眼","boss",1),
]
# 探明顺序（沿邻接图 BFS 的一条合理主线）
ORDER = ["FR_01","FR_02","FR_04","FR_05","FR_03","FR_07","FR_06","FR_08","FR_09","FR_10","FR_11","FR_12"]
TIER = {i[0]: i[2] for i in ISL}
ADJC = {i[0]: i[3] for i in ISL}
NAME = {i[0]: i[1] for i in ISL}

# ---------- 成本函数 ----------
def UP(L):        # 单卡 L -> L+1 的升级成本
    return math.ceil(150 * (L ** 1.3) / 10) * 10
def DEV(d):       # 岛 dev d -> d+1 的开发成本
    return 2500 * (d + 1)
ASC_COST = 30000
SHIP_IRON_COST = 15000

def gm(lv, asc):  # 养成倍率
    return (1 + 0.02 * (lv - 1)) * (1 + 0.08 * asc)

# ============================================================
P("[F0] 结构性修正后：POI 产出上限重算（体力成为真约束）")
P("-" * 104)
P("  STAMINA_MAX=120 / STAMINA_COST_POI=6  ->  每日最多 20 次 POI")
P("  全图槽位总数 = %d（> 20），玩家必须选择去哪些岛 = G1 取舍成立" % sum(SLOTS[t] for _,_,t,_ in ISL))
P("")
P("  单槽期望产出 = POI_RESOURCE_BASE(500) x TIER_YIELD_M[tier]")
P("  %-10s %-8s %-10s %-10s %-10s" % ("tier","槽位/岛","岛数","单槽期望","该 tier 总槽"))
cnt = {}
for _,_,t,_ in ISL: cnt[t] = cnt.get(t,0)+1
for t in ["start","light","heavy","boss"]:
    P("  %-10s %-8d %-10d %-10d %-10d" % (t, SLOTS[t], cnt[t], POI_RESOURCE_BASE*TIER_YIELD_M[t], SLOTS[t]*cnt[t]))
P("")
# 贪心：按单槽期望降序吃满 20 次
pool_slots = []
for iid,_,t,_ in ISL:
    for _ in range(SLOTS[t]):
        pool_slots.append((POI_RESOURCE_BASE*TIER_YIELD_M[t], t, iid))
pool_slots.sort(reverse=True)
best20 = pool_slots[:20]
P("  满图理性玩家日产（20 次全投最高 tier）= %d  vs daily_target=%d  偏差 %+.1f%%"
  % (sum(x[0] for x in best20), DAILY_TARGET, (sum(x[0] for x in best20)-DAILY_TARGET)*100.0/DAILY_TARGET))
# 阶段性上限
for stage, allow in [("仅 light 开放", {"start","light"}), ("+heavy 开放", {"start","light","heavy"}), ("满图", {"start","light","heavy","boss"})]:
    ps = [x for x in pool_slots if x[1] in allow]
    ps.sort(reverse=True)
    P("  %-14s 日产上限 = %6d" % (stage, sum(x[0] for x in ps[:20])))
P("")

# ============================================================
P("[F1] 护岛日产与领地维护费（常驻 sink）")
P("-" * 104)
P("  yield_i = 120 x TIER_M x (1+0.25*dev) x (1+0.10*已占邻接数)")
P("  upkeep_i = yield_i x UPKEEP_RATE(0.40)   <- 每日强制扣除，随规模增长")
P("  %-8s %-10s %-8s %-9s %-9s %-9s %-9s" % ("岛","tier","TIER_M","产 dev0","维 dev0","产 dev4","维 dev4"))
ty0 = ty4 = 0
for iid,nm,t,adj in ISL:
    y0 = ISLAND_DAILY_YIELD*TIER_M[t]*(1+DEV_BONUS*0)*(1+ADJ_BONUS*adj)
    y4 = ISLAND_DAILY_YIELD*TIER_M[t]*(1+DEV_BONUS*4)*(1+ADJ_BONUS*adj)
    ty0 += y0; ty4 += y4
    P("  %-8s %-10s %-8.1f %-9d %-9d %-9d %-9d" % (iid,t,TIER_M[t],y0,y0*UPKEEP_RATE,y4,y4*UPKEEP_RATE))
P("  %-8s %-10s %-8s %-9d %-9d %-9d %-9d" % ("合计","","",ty0,ty0*UPKEEP_RATE,ty4,ty4*UPKEEP_RATE))
P("  净护岛收益 dev0=%d/日  dev4=%d/日" % (ty0*(1-UPKEEP_RATE), ty4*(1-UPKEEP_RATE)))
P("")

# ============================================================
P("[F2] sink 总容量 vs 30 日累计产出")
P("-" * 104)
up_one = sum(UP(L) for L in range(1,10))
P("  单卡 Lv1->Lv10 累计 = %d" % up_one)
P("  20 卡全升 Lv10        = %d" % (up_one*20))
dev_one = sum(DEV(d) for d in range(DEV_MAX))
P("  单岛 dev0->dev4 累计  = %d" % dev_one)
P("  12 岛全开发           = %d" % (dev_one*12))
P("  主队 5 卡 asc1        = %d" % (ASC_COST*5))
P("  造 SHIP_IRON          = %d" % SHIP_IRON_COST)
cap = up_one*20 + dev_one*12 + ASC_COST*5 + SHIP_IRON_COST
P("  ------------------------------------")
P("  一次性 sink 容量合计  = %d" % cap)
P("")

# ============================================================
P("[F3] 30 步单人经济模拟（连续投入制 + 常驻维护费）")
P("-" * 118)
P("  支出优先级：①维护费(强制) ②主队5卡->Lv10 ③SHIP_IRON ④岛屿开发(就低) ⑤其余15卡->Lv10 ⑥主队asc1")
P("  攻岛门槛：light 需 gm>=1.00；heavy 需 gm>=1.10 且卡>=16；boss 需 gm>=1.15 且卡=20 且有 SHIP_IRON")
P("")
hdr = ("%3s %5s %5s %4s %4s %5s %7s %7s %7s %7s %7s %7s %7s %7s %8s %7s"
       % ("d","探明","已占","卡","Lv","gm","POI产","岛产","总入","维护","升级","开发","造船","衰减","池","通胀%"))
P("  " + hdr)

scouted = ["FR_01"]; owned = ["FR_01"]
cards = 12
lv = [1]*20; asc = [0]*20
dev = {"FR_01":0}
pool = 50000.0
have_iron = False
INIT_POOL = 50000.0
inflation = []
tot_in = tot_out = 0.0
# 进度累计（连续投入制）
prog_up = [0.0]*20
prog_dev = {}
prog_ship = 0.0
prog_asc = [0.0]*20

for d in range(1, 31):
    st = STAMINA_MAX
    # --- 攻岛（每日至多 1 次）---
    tgt = None
    for iid in ORDER:
        if iid in owned: continue
        if iid not in scouted: break   # 必须先探明
        t = TIER[iid]
        g = gm(lv[0], asc[0])
        if t in ("start","light") and g >= 1.00: tgt = iid
        elif t == "heavy" and g >= 1.10 and cards >= 16: tgt = iid
        elif t == "boss" and g >= 1.15 and cards >= 20 and have_iron: tgt = iid
        break
    if tgt and st >= STAMINA_COST_RAID:
        st -= STAMINA_COST_RAID
        owned.append(tgt); dev[tgt] = 0
        # 占领后解锁下一个未探明岛
    # 探明推进：每日最多探明 1 个新岛（需已占前置）
    for iid in ORDER:
        if iid not in scouted:
            if len(owned) >= max(1, ORDER.index(iid) - 2):
                scouted.append(iid)
            break

    # --- POI ---
    n_poi = st // STAMINA_COST_POI
    avail = []
    for iid in scouted:
        t = TIER[iid]
        for _ in range(SLOTS[t]):
            avail.append(POI_RESOURCE_BASE*TIER_YIELD_M[t])
    avail.sort(reverse=True)
    poi_gain = sum(avail[:n_poi])
    # 卡牌获取：每 3 次 POI 期望 +1 张新卡，直到 20
    if cards < 20:
        cards = min(20, cards + max(1, n_poi // 6))

    # --- 护岛产 ---
    isl_gain = 0.0
    for iid in owned:
        t = TIER[iid]
        adjo = sum(1 for x in owned if x != iid)   # 简化：已占数近似邻接加成上限
        adjo = min(ADJC[iid], adjo)
        isl_gain += ISLAND_DAILY_YIELD*TIER_M[t]*(1+DEV_BONUS*dev[iid])*(1+ADJ_BONUS*adjo)
    upkeep = isl_gain * UPKEEP_RATE
    gain = poi_gain + isl_gain
    pool += gain; tot_in += gain

    # --- 支出 ---
    spend_up = spend_dev = spend_ship = 0.0
    pool -= upkeep; tot_out += upkeep
    budget = max(0.0, pool)

    def invest(need, prog, amt):
        """连续投入：返回 (实投, 新进度, 是否完成)"""
        room = need - prog
        put = min(amt, room)
        return put, prog + put, (prog + put) >= need - 1e-9

    # ② 主队 5 卡
    for i in range(5):
        if budget <= 0: break
        if lv[i] < 10:
            need = UP(lv[i])
            put, prog_up[i], done = invest(need, prog_up[i], budget)
            budget -= put; spend_up += put
            if done: lv[i] += 1; prog_up[i] = 0.0
    # ③ 造船
    if budget > 0 and not have_iron:
        put, prog_ship, done = invest(SHIP_IRON_COST, prog_ship, budget)
        budget -= put; spend_ship += put
        if done: have_iron = True
    # ④ 岛屿开发（就低优先）
    if budget > 0:
        for iid in sorted(owned, key=lambda x: dev[x]):
            if budget <= 0: break
            if dev[iid] < DEV_MAX:
                need = DEV(dev[iid])
                put, prog_dev[iid], done = invest(need, prog_dev.get(iid,0.0), budget)
                budget -= put; spend_dev += put
                if done: dev[iid] += 1; prog_dev[iid] = 0.0
    # ⑤ 其余 15 卡
    if budget > 0:
        for i in range(5, 20):
            if budget <= 0: break
            if i < cards and lv[i] < 10:
                need = UP(lv[i])
                put, prog_up[i], done = invest(need, prog_up[i], budget)
                budget -= put; spend_up += put
                if done: lv[i] += 1; prog_up[i] = 0.0
    # ⑥ 主队突破
    if budget > 0:
        for i in range(5):
            if budget <= 0: break
            if lv[i] >= 10 and asc[i] < 1:
                put, prog_asc[i], done = invest(ASC_COST, prog_asc[i], budget)
                budget -= put
                spend_up += put
                if done: asc[i] += 1; prog_asc[i] = 0.0

    spent = spend_up + spend_dev + spend_ship
    pool -= spent; tot_out += spent
    # --- 软顶衰减 ---
    decay = 0.0
    if pool > POOL_SOFT_CAP:
        decay = (pool - POOL_SOFT_CAP) * DECAY
        pool -= decay; tot_out += decay
    net = gain - upkeep - spent - decay
    infl = net / INIT_POOL * 100
    inflation.append(infl)
    P("  %3d %5d %5d %4d %4d %5.2f %7d %7d %7d %7d %7d %7d %7d %7d %8d %7.1f"
      % (d, len(scouted), len(owned), cards, lv[0], gm(lv[0],asc[0]), poi_gain, isl_gain, gain,
         upkeep, spend_up, spend_dev, spend_ship, decay, pool, infl))

P("")
last10 = inflation[-10:]
P("  30 步累计：总入 %d  总出 %d  期末池 %d" % (tot_in, tot_out, pool))
P("  后 10 步平均日通胀率 %.2f%%（D5 阈值 <=5%%，口径=净增/初始池 50000）" % (sum(last10)/len(last10)))
P("  后 10 步峰值日通胀率 %.2f%%" % max(last10))
P("  全程峰值 %.2f%%  最低 %.2f%%" % (max(inflation), min(inflation)))
P("  期末池 %d <= 软顶 %d ? %s" % (pool, POOL_SOFT_CAP, "是" if pool <= POOL_SOFT_CAP else "否"))
P("  终局：Lv=%s  asc=%s  已占=%d  dev=%s" % (lv[:5], asc[:5], len(owned), sorted(dev.values(), reverse=True)))
o.close()
print("done")
