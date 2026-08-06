# -*- coding: utf-8 -*-
"""lock_hash.py · 2026-08-02 · 主理人锁链用
计算 design-layer 的 ruleset_hash / econ_ruleset_hash（blake2b-256 摘要），
并把「锁定版 guards.json（FR_09.hp_mult=1.20）」写到 design/data-spec/。

⚠ 这是设计层摘要。链上工程侧须用 Poseidon(constants ‖ cards ‖ ships ‖ env_table)
对**同一字段集**复现，得到 on-chain ruleset_hash（约束进战报承诺）。
本脚本的价值：把「冻结那一刻的常量真值」与「可校验的摘要」固化下来，杜绝口径漂移。
"""
import json, hashlib, os

TEMP = "C:/Users/Administrator/AppData/Local/Temp/bv/"
OUT = "C:/Users/Administrator/WorkBuddy/2026-08-02-00-24-06/BigVoyage/design/data-spec/"


def b2(obj):
    s = json.dumps(obj, sort_keys=True, ensure_ascii=False)
    return hashlib.blake2b(s.encode("utf-8"), digest_size=32).hexdigest()


C = json.load(open(TEMP + "data_constants.json", encoding="utf-8"))
cards = json.load(open(TEMP + "data_cards.json", encoding="utf-8"))
ships = json.load(open(TEMP + "data_ships.json", encoding="utf-8"))
guards = json.load(open(TEMP + "data_guards.json", encoding="utf-8"))
IS = json.load(open(TEMP + "data_islands.json", encoding="utf-8"))

# ---- 锁定战斗常量（终表，2026-08-02） ----
battle = dict(C)
battle["SEG_DECAY"] = 0.40        # D3
battle["ARMOR_CAP"] = 0.80        # C-5 / FR_12=A
battle["LVL_STEP"] = 0.05         # D2（养成斜率）
battle["DEF_COEF"] = 0.30         # 护甲方案1（减法系数），进 ruleset_hash
battle["DOT_ARMOR"] = True        # D13② DoT 过减法扣甲（代码级开关，锁进 hash）
# STAT_CAP 已在 C = {atk:200, def:200}；RESTRAINT/TYPE_COEF/RING/GUARD_MAX_ROUND 等已在 C

cards_hash = b2(cards)
ships_hash = b2(ships)
env_table = IS.get("sea_theme", {}).get("env_bias", {})

ruleset = {
    "constants": battle,
    "cards_hash": cards_hash,
    "ships_hash": ships_hash,
    "env_table": env_table,
}
ruleset_hash = b2(ruleset)

# ---- 锁定经济常量（终表，2026-08-02） ----
guards_locked = json.loads(json.dumps(guards))
guards_locked["guards"]["FR_09"]["hp_mult"] = 1.20   # ★Q5
guards_hash = b2(guards_locked)

econ = {
    "ISLAND_DAILY_YIELD": 120,
    "DEV_STEP": 0.25,
    "ADJ_BONUS": 0.25,
    "DECAY_SLOPE": 0.06,
    "MAX_CLAIM_DAYS": 30,
    "TIDE_BY_TIER": {"start": 0, "light": 1, "heavy": 3, "boss": 8},
    "SEASON_POOL": 5000,
    "STAMINA_MAX": 120,
    "STAMINA_COST_POI": 6,
    "INFLATION_DENOMINATOR": "rolling_prev_day_pool",   # D1 口径
    "REFERENCE_PLAYER": {"invest_rate": 0.80},          # D1 参考玩家档案
}
econ_locked = {
    "constants": econ,
    "guards_hash": guards_hash,
    "islands_hash": b2(IS),
}
econ_ruleset_hash = b2(econ_locked)

# ---- 落库：锁定版 guards.json ----
os.makedirs(OUT, exist_ok=True)
json.dump(guards_locked, open(OUT + "guards.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=2)

print("cards_hash             =", cards_hash)
print("ships_hash             =", ships_hash)
print("guards_hash(locked1.20)=", guards_hash)
print("ruleset_hash(design)   =", ruleset_hash)
print("econ_ruleset_hash(design)=", econ_ruleset_hash)
print("wrote", OUT + "guards.json")
