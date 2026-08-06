# -*- coding: utf-8 -*-
"""bv_curve：全 11 岛进度曲线 @ 指定 SEG_DECAY（GDD-02 §6.3 / GDD-03 复跑）
用法：python bv_curve.py <SEG_DECAY> [seg_mode]
养成档位按 D2（LVL_STEP=0.05）：Lv1=1.00 / Lv4=1.15 / Lv10=1.45
"""
import sys, time
import bv_engine as E

SEG = float(sys.argv[1]) if len(sys.argv) > 1 else 0.40
MODE = sys.argv[2] if len(sys.argv) > 2 else "geo"
ORDER = ["FR_02", "FR_03", "FR_05", "FR_07", "FR_10", "FR_04", "FR_08", "FR_11", "FR_06", "FR_09", "FR_12"]


def job(iid):
    g = E.GU["guards"][iid]
    rst = E.FR12_A[0] if iid == "FR_12" else g["crew_ids"]
    hm = E.FR12_A[1] if iid == "FR_12" else g["hp_mult"]
    gs = g["ship_id"]
    r0 = E.winrate(E.SF, "SHIP_RAFT", rst, hm, 1.00, SEG, seg_mode=MODE, guard_ship=gs)
    a0 = E.winrate(E.FL, "SHIP_IRON", rst, hm, 1.00, SEG, seg_mode=MODE, guard_ship=gs)
    a1 = E.winrate(E.FL, "SHIP_IRON", rst, hm, 1.15, SEG, seg_mode=MODE, guard_ship=gs)
    a2 = E.winrate(E.FL, "SHIP_IRON", rst, hm, 1.45, SEG, seg_mode=MODE, guard_ship=gs)
    return iid, E.ISLANDS[iid]["tier"], r0, a0, a1, a2


if __name__ == "__main__":
    t = time.time()
    print(f"=== 全 11 岛进度曲线 · SEG_DECAY={SEG:.2f} · seg_mode={MODE} ===", flush=True)
    print("固定：ARMOR_CAP=0.80 / FR_12=cost12 hm1.35 / 养成 LVL_STEP=0.05", flush=True)
    print(f"{'岛':<20}{'tier':<7}{'起始12卡·木筏':>16}{'全20卡 Lv1':>13}{'全20卡 Lv4':>13}{'全20卡 Lv10':>14}", flush=True)
    res = []
    for iid in ORDER:
        r = job(iid)
        res.append(r)
        _, tier, r0, a0, a1, a2 = r
        nm = f"{iid} {E.ISLANDS[iid]['name']}"
        print(f"{nm:<20}{tier:<7}{r0:>15.1f}%{a0:>12.1f}%{a1:>12.1f}%{a2:>13.1f}%", flush=True)

    # 单调性 / 断崖自检（按 Lv4 列）
    seq = [(iid, a1) for iid, _, _, _, a1, _ in res]
    print("\n--- G1 单调性与断崖自检（全20卡 Lv4 列，阈值 40pp）---")
    worst = 0.0
    for i in range(len(seq) - 1):
        d = seq[i][1] - seq[i + 1][1]
        if d > worst: worst = d
        flag = "  <== 断崖 >40pp" if d > 40 else ("  <== 反转" if d < 0 else "")
        print(f"  {seq[i][0]} -> {seq[i+1][0]}: {seq[i][1]:.1f}% -> {seq[i+1][1]:.1f}%  落差 {d:+.1f}pp{flag}")
    print(f"最大落差 = {worst:.1f}pp  ->  {'PASS' if worst <= 40 else 'FAIL（超 40pp 阈值）'}")
    print(f"[用时 {time.time()-t:.0f}s]")
