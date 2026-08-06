# Sidecar

权威承诺：`POST /commit` → FieldMapper → `leo run commit_battle`（`poseidon8_snarkvm_v1`）。

## 启动（推荐 Node）

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\tools\start_chain.ps1

# 或分进程
cd ..\wallet-bridge && npm start   # :8788 Provable SDK
cd . && npm start                  # :8787 node server.mjs
```

Python 版：`python server.py`（需真 Python，非 Windows Store 空桩）。

## 端点

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | leo + wallet-bridge 状态 |
| POST | `/commit` | field map → leo run（`broadcast:true` 时尝试链上 execute） |
| POST | `/wallet/create` | 经 wallet-bridge 创建账户 |
| GET | `/ops/events` | LiveOps |

## 向量

`testdata/poseidon8_vectors.json` 与 Leo 4.4.0 `leo run` 对齐。soft_v1 已作废。
