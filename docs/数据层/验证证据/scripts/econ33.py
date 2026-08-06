# -*- coding: utf-8 -*-
# econ33：滚动口径下「D5 达标 vs 玩家投入率」的敏感度扫描 + 产出侧闸门方案对比
import io, contextlib
import econ32 as C

ROWS = [round(0.05 * i, 2) for i in range(21)]

if __name__ == "__main__":
    print("=== 表 A · 玩家日投入率 × 峰值日通胀（滚动口径，分母=前一日池存）===")
    print(f"{'投入率':>7}{'峰值日通胀%':>13}{'30日末池':>11}{'D5':>7}")
    thr = None
    for r in ROWS:
        with contextlib.redirect_stdout(io.StringIO()):
            p, pool, _ = C.run(invest_rate=r)
        ok = p <= 5
        if ok and thr is None:
            thr = r
        print(f"{r:>7.2f}{p:>13.2f}{pool:>11}{'PASS' if ok else 'FAIL':>7}")
    print(f"\n达标阈值：投入率 >= {thr:.2f} 时 D5 通过；低于此值的囤积型玩家必然 FAIL")

    print("\n=== 表 B · 强制 sink（维护费率）能否救回纯囤积玩家（invest_rate=0）===")
    print(f"{'维护费×倍':>10}{'峰值日通胀%':>13}{'30日末池':>11}{'D5':>7}")
    import econ31 as E
    base_up = dict(E.UPKEEP)
    for m in (1.0, 2.0, 3.0, 4.0, 5.0, 6.0):
        E.UPKEEP = {k: int(v * m) for k, v in base_up.items()}
        with contextlib.redirect_stdout(io.StringIO()):
            p, pool, _ = C.run(invest_rate=0.0)
        print(f"{m:>10.1f}{p:>13.2f}{pool:>11}{'PASS' if p <= 5 else 'FAIL':>7}")
    E.UPKEEP = base_up

    print("\n=== 表 C · 囤积衰减强度对纯囤积玩家的作用（invest_rate=0）===")
    print(f"{'HOARD_DECAY':>12}{'峰值日通胀%':>13}{'30日末池':>11}{'D5':>7}")
    for h in (0.0, 0.10, 0.25, 0.40, 0.60):
        with contextlib.redirect_stdout(io.StringIO()):
            p, pool, _ = C.run(invest_rate=0.0, hoard=h)
        print(f"{h:>12.2f}{p:>13.2f}{pool:>11}{'PASS' if p <= 5 else 'FAIL':>7}")
