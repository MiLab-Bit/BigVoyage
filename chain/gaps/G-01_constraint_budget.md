# G-01 · 单 transition 约束预算（穿刺）

| 字段 | 内容 |
|---|---|
| ID | G-01 |
| 问题 | Aleo snarkVM / Varuna 单 transition 约束硬上限；wasm 客户端可承受证明耗时 |
| 状态 | **开放** · 本机尚未跑 `leo`/`snarkvm` 基准 |
| 上游 | `架构与技术/battle-core-zk-readiness-audit.md` §3 |

## 探针步骤（装好工具链后执行）

1. `leo --version` / `snarkvm --version` 记入本文件。
2. 对 `programs/bv_commit` 执行 `leo build`，记录约束数（若 CLI 暴露）。
3. 合成「假 L3」：固定 3v3×8 回合展开循环的最小 Leo，测证明生成墙钟时间（native + 若可能 wasm）。
4. 回填：硬上限 / 实测约束 / 是否推翻「百万约束不可行」量级判断。

## 临时结论（未验证）

沿用审计：**完整 5v5×30 不可单 transition**；L3 必须降规格。Demo 可继续 `CHAIN_MOCK`。
