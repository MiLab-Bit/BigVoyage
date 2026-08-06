# -*- coding: utf-8 -*-
"""lock_armor_b（BV-Lock, 2026-08-02）· 护甲方案1 仿真侧复验（FR_12 / B3 + 断崖岛）
   固定：seg_mode=geo / SEG_DECAY=0.40(D3) / ARMOR_CAP=0.80 / 玩家 SHIP_IRON / 编队空间 |FL|
   变量：def_coef ∈ {0.00(引擎历史行为), 0.30(★方案1), 0.50(原解析系数)}
   任务 B1：FR_12（渊眼 Boss, cost12 五卡 hm1.35）胜率 × def_coef × gm
   任务 B2：FR_06 / FR_09 断崖复核（含 Q5：FR_09 hp_mult 1.35 -> 1.20）
"""
import sys, time
import bv_engine as E

SEG = 0.40
CAP = 0.80
t0 = time.time()


def log(*a):
    print(*a, flush=True)


mode = sys.argv[1] if len(sys.argv) > 1 else "all"

log("=" * 100)
log("B · 护甲方案1 仿真复验 | SEG_DECAY=%.2f(D3) ARMOR_CAP=%.2f seg_mode=geo |FL|=%d" % (SEG, CAP, len(E.FL)))
log("=" * 100)

if mode in ("all", "b1"):
    log("\n### B1 · FR_12（渊眼 Boss）胜率 vs DEF_COEF —— B3 是否重现")
    log("目标区间：Lv4(gm1.15) 落在 5%~15%（GDD-02 §6.4）\n")
    log(f"{'DEF_COEF':>9}{'Lv1':>12}{'Lv4(gm1.15)':>14}{'Lv10(gm1.45)':>14}{'判定(Lv4)':>12}  备注")
    notes = {0.00: "引擎历史行为（既往 10.94% 快照口径）",
             0.30: "★ 用户已决 方案1",
             0.50: "10-经济 §6.1 解析式原系数"}
    for dc in (0.00, 0.30, 0.50):
        row = f"{dc:>9.2f}"
        w4 = None
        for gm in (1.00, 1.15, 1.45):
            w = E.winrate(E.FL, "SHIP_IRON", E.FR12_A[0], E.FR12_A[1], gm, SEG,
                          cap=CAP, seg_mode="geo", def_coef=dc)
            if abs(gm - 1.15) < 1e-9:
                w4 = w
            row += f"{w:>13.2f}%"
        v = "B3 重现" if w4 < 0.005 else ("偏低" if w4 < 5 else ("OK" if w4 <= 15 else "偏高"))
        log(row + f"{v:>12}  {notes[dc]}")
    log(f"[B1 用时 {time.time()-t0:.0f}s]")

if mode in ("all", "b2"):
    log("\n### B2 · 断崖岛复核：FR_06 / FR_09（Q5：FR_09 hp_mult 1.35 -> 1.20）")
    log(f"{'岛':<10}{'hp_mult':>9}{'DEF_COEF':>9}{'全20卡 Lv1':>13}{'Lv4(gm1.15)':>14}{'Lv10(gm1.45)':>14}")
    cases = [("FR_06", 1.35), ("FR_09", 1.35), ("FR_09", 1.20)]
    res = {}
    for iid, hm in cases:
        g = E.GU["guards"][iid]
        for dc in (0.00, 0.30):
            r = [E.winrate(E.FL, "SHIP_IRON", g["crew_ids"], hm, gm, SEG,
                           cap=CAP, seg_mode="geo", guard_ship=g["ship_id"], def_coef=dc)
                 for gm in (1.00, 1.15, 1.45)]
            res[(iid, hm, dc)] = r
            log(f"{iid:<10}{hm:>9.2f}{dc:>9.2f}{r[0]:>12.1f}%{r[1]:>13.1f}%{r[2]:>13.1f}%")
    log("\n-- FR_06 -> FR_09 难度断崖（Lv10 口径，pp = 百分点）")
    for dc in (0.00, 0.30):
        a = res[("FR_06", 1.35, dc)][2]
        b135 = res[("FR_09", 1.35, dc)][2]
        b120 = res[("FR_09", 1.20, dc)][2]
        log(f"  DEF_COEF={dc:.2f}: FR_06 {a:.1f}%  ->  FR_09@1.35 {b135:.1f}% (断崖 {a-b135:+.1f}pp)"
            f"  ->  FR_09@1.20 {b120:.1f}% (断崖 {a-b120:+.1f}pp, 收窄 {(a-b135)-(a-b120):.1f}pp)")
    log(f"[B2 用时 {time.time()-t0:.0f}s]")

log(f"\n[总用时 {time.time()-t0:.0f}s]")
