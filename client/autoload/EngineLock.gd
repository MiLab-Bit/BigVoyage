extends Node
## G2 引擎冻结元数据（只读 · 不参与结算）
## 权威：仓库根 `00-G2引擎冻结_Godot.md`

const ENGINE := "Godot"
const ENGINE_VERSION := "4.7"
const RENDERER := "Forward+"
const G2_FROZEN := true
const G2_DATE := "2026-08-06"
const CHAIN := "Aleo"
const CHAIN_MOCK_DEFAULT := false
## 链上承诺算法冻结（见 chain/HASH_FREEZE.md）；soft_v1 已作废不得写入新 commit
const HASH_ALG := "poseidon8_snarkvm_v1"

## design-layer hash 摘要（人类可读；链上须 snarkVM Poseidon8 同字段集复现）
const RULESET_HASH_DESIGN := "d8d175c3d70c0d389e22ee1a06cbbd8a87d1e78e15379e37cbe9a07be94fefb5"
const ECON_RULESET_HASH_DESIGN := "3ee5c05592404f4c8c7f5cb893b7721ff911208733c515fdc98dccc7def4a42e"
const CARDS_HASH_DESIGN := "5acbc0ef06de328e0bf10d19524665cd17fe64fe59821636ce1e0db82c4d5eb4"

func _ready() -> void:
	print("[EngineLock] G2=%s %s (%s) · chain=%s · hash_alg=%s · mock=%s" % [
		ENGINE, ENGINE_VERSION, RENDERER, CHAIN, HASH_ALG, str(CHAIN_MOCK_DEFAULT)
	])
