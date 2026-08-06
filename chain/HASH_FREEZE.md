# 链上哈希冻结 · poseidon8_snarkvm_v1

> **日期**：2026-08-06 · **状态**：已冻结（Leo 4.4.0 `leo build` + `leo run` 向量已回写）  
> **替换**：`poseidon8_soft_v1`（128/61-bit soft field）→ **snarkVM 原生 Poseidon8**

## 1. 算法

| 项 | 值 |
|---|---|
| 名称 | `poseidon8_snarkvm_v1` |
| Leo API | `Poseidon8::hash_to_field(BattleCommit)` |
| 曲线/域 | snarkVM / Aleo `field`（BN254 Fr） |
| 输入 | 结构体 8 肢（见下） |

## 2. 字段序（禁止改序；改序=重冻）

1. `ruleset_h: field` — 由 design SHA-256 hex → `FieldMapper.hex_to_field`
2. `fleets_h: field` — 战报 SHA/设计 hash → field
3. `env_h: field`
4. `seed_f: field` — `seed as field`（u64）
5. `winner_f: field` — 0/1/2
6. `rounds_f: field`
7. `log_root: field`
8. `season_f: field` — u32 as field

## 3. Field 映射（design → snarkVM）

实现：`chain/sidecar/field_mapper.py` · `client/core/FieldMapper.gd`

规则（冻结）：

- 取输入 hex（无 `0x`），不足 64 字符左侧补 0，超过则 **取低 64 hex（256 bit）**。
- 解释为 big-endian 整数 `n`，再 `n mod FIELD_MODULUS`。
- `FIELD_MODULUS` = BN254 Fr =  
  `21888242871839275222246405745257275088548364400416034343698204186575808495617`

> soft_v1 的 `2^61-1` **作废**，不得再用于承诺。

## 4. 客户端 / Sidecar 行为

| 模式 | 行为 |
|---|---|
| `CHAIN_MOCK=true` | 本地用 FieldMapper + **无法在 GDScript 复现完整 Poseidon8** → 委托 Sidecar `/commit` 即便 mock 也可算（或标记 `poseidon8_pending_leo`） |
| Sidecar + leo | `leo run commit_battle ...` / `leo execute`（有私钥时） |
| 真钱包 | Provable SDK / Wallet Adapter 签名 execute |

## 5. 重冻检查清单

- [x] `leo build` 通过（`chain/programs/bv_commit`，Leo 4.4.0）
- [x] 固定向量 `chain/sidecar/testdata/poseidon8_vectors.json` 与 `leo run` 一致（v0_smoke）
- [x] `EngineLock.HASH_ALG` / Sidecar / FieldMapper 注明 `poseidon8_snarkvm_v1`
- [x] soft_v1 仅保留兼容读，不再写入新 commit（`ChainGateway` 无 soft fallback）
- [ ] 本机账户 faucet 注资后 `broadcast=true` → wallet-bridge execute
