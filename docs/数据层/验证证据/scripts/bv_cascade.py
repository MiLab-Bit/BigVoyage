# -*- coding: utf-8 -*-
"""bv_cascade：D3(SEG_DECAY) 级联复跑
   基线校准：seg_mode=flat / seg=0.60 / gm=1.15 / cap=0.80 / FR_12 cost12 hm1.35 -> 13.65%（与 bvd1_out10.txt 一致）
   任务 1：FR_12 胜率 × SEG_DECAY × 养成系数 gm × 段衰减模型
   任务 2：全 11 岛进度曲线 × SEG_DECAY
"""
import time, sys
import bv_engine as E

SEGS = [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.43, 0.55, 0.60]
GMS = [("Lv1", 1.00), ("Lv4(gm1.15)", 1.15), ("Lv10(gm1.45)", 1.45)]
ORDER = ["FR_02", "FR_03", "FR_05", "FR_07", "FR_10", "FR_04", "FR_08", "FR_11", "FR_06", "FR_09", "FR_12"]
t0 = time.time()


def log(*a):
    print(*a, flush=True)


log("=" * 104)
log("BV 级联复跑 · D3 SEG_DECAY 终值验证")
log("固定：玩家 SHIP_IRON / ARMOR_CAP=0.80 / FR_12 = cost12 五卡 hm1.35 / 编队空间 |FL|=%d" % len(E.FL))
log("=" * 104)

# ---------------- 任务 1：FR_12 × SEG_DECAY × gm ----------------
log("\n### 任务 1 · FR_12（渊眼 Boss）胜率 vs SEG_DECAY —— B3 是否重现")
log("目标区间：5%~15%（GDD-02 §6.4）。0.0% = B3 重现（Boss 不可通关）\n")
for mode in ("geo", "flat"):
    tag = "geo（GDD-03 §6.3 规格 SEG^(k-1)）" if mode == "geo" else "flat（bvd1_sim8 原实现，13.65% 出处）"
    log(f"-- 段衰减模型 = {tag}")
    log(f"{'SEG_DECAY':>10}" + "".join(f"{g[0]:>16}" for g in GMS) + f"{'判定(Lv4)':>12}")
    for s in SEGS:
        row = f"{s:>10.2f}"
        w4 = None
        for name, gm in GMS:
            w = E.winrate(E.FL, "SHIP_IRON", E.FR12_A[0], E.FR12_A[1], gm, s, seg_mode=mode)
            if gm == 1.15: w4 = w
            row += f"{w:>15.2f}%"
        verdict = "B3 重现" if w4 < 0.005 else ("偏低" if w4 < 5 else ("OK" if w4 <= 15 else "偏高"))
        log(row + f"{verdict:>12}")
    log("")

log(f"[任务 1 用时 {time.time()-t0:.0f}s]")

# ---------------- 任务 2：全岛进度曲线 ----------------
log("\n### 任务 2 · 全 11 岛进度曲线 vs SEG_DECAY（GDD-02 §6.3 / GDD-03 复跑）")
for s in (0.15, 0.40, 0.60):
    log(f"\n-- SEG_DECAY = {s:.2f}（seg_mode=geo）")
    log(f"{'岛':<20}{'tier':<7}{'起始12卡/木筏':>15}{'全20卡 Lv1':>13}{'全20卡 Lv4':>13}{'全20卡 Lv10':>14}")
    for iid in ORDER:
        g = E.GU["guards"][iid]
        rst = E.FR12_A[0] if iid == "FR_12" else g["crew_ids"]
        hm = E.FR12_A[1] if iid == "FR_12" else g["hp_mult"]
        r0 = E.winrate(E.SF, "SHIP_RAFT", rst, hm, 1.00, s, guard_ship=g["ship_id"])
        a0 = E.winrate(E.FL, "SHIP_IRON", rst, hm, 1.00, s, guard_ship=g["ship_id"])
        a1 = E.winrate(E.FL, "SHIP_IRON", rst, hm, 1.15, s, guard_ship=g["ship_id"])
        a2 = E.winrate(E.FL, "SHIP_IRON", rst, hm, 1.45, s, guard_ship=g["ship_id"])
        nm = f"{iid} {E.ISLANDS[iid]['name']}"
        log(f"{nm:<20}{E.ISLANDS[iid]['tier']:<7}{r0:>14.1f}%{a0:>12.1f}%{a1:>12.1f}%{a2:>13.1f}%")

log(f"\n[总用时 {time.time()-t0:.0f}s]")
