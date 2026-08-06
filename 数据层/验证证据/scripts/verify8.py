# -*- coding: utf-8 -*-
# verify8：Boss（FR_12 渊眼）降规格搜索 —— 目标 Lv1 ≈0% / Lv5 20-35% / Lv10 50-70%
import verify6 as V, verify7 as W

def cost(ids): return sum(V.CARDS[i][1] for i in ids)

CAND = [
 (["IRON_UR_01","IRON_SSR_01","IRON_SR_01","TIDE_SSR_01","WIND_SSR_01"], 1.40, "现状 v0.1"),
 (["IRON_UR_01","IRON_SSR_01","WIND_SSR_01","IRON_SR_01"], 1.20, "COST 预算 12"),
 (["IRON_UR_01","IRON_SR_01","TIDE_SR_01"], 1.20, "COST 8"),
 (["IRON_UR_01","IRON_SR_01","WIND_SR_01"], 1.10, "COST 8"),
 (["IRON_SSR_01","IRON_SR_01","TIDE_SSR_01","IRON_R_01"], 1.30, "COST 9 无 UR"),
 (["IRON_SSR_01","IRON_SR_01","TIDE_SR_01"], 1.30, "COST 7 无 UR"),
 (["IRON_SSR_01","IRON_SR_01","TIDE_SR_01"], 1.00, "COST 7 无 UR"),
 (["IRON_SSR_01","IRON_SR_01"], 1.20, "COST 5 无 UR"),
]

print("=== FR_12 Boss 降规格搜索（全收集 20 卡 / SHIP_RAFT / 修正案 C 段数）===")
print(f"{'编成':<40}{'注':<14}{'COST':>5}{'hm':>6}{'HP':>7}{'Lv1%':>7}{'Lv5%':>7}{'Lv10%':>7}")
for ids, hm, note in CAND:
    G = W.build(ids, "SHIP_IRON", 1, hm)
    hp = int(sum(u["hp"] for u in G))
    r = [W.winrate(W.ALL_F, "SHIP_RAFT", G, g) for g in (1.00, 1.20, 1.45)]
    name = "+".join(x.replace("_01", "").replace("IRON", "铁").replace("TIDE", "潮")
                     .replace("WIND", "风").replace("FLAME", "焰") for x in ids)
    print(f"{name:<40}{note:<14}{cost(ids):>5}{hm:>6.2f}{hp:>7}{r[0]:>7.1f}{r[1]:>7.1f}{r[2]:>7.1f}")
