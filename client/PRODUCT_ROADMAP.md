# 产品落地状态（v1.25 · 链上已开）

## 链上（本机）

| 项 | 状态 |
|---|---|
| `CHAIN_MOCK` | **false** |
| Sidecar | `http://127.0.0.1:8790`（8787 被脏进程占） |
| Wallet-bridge | `:8788` · testnet 账户已有 |
| Leo Poseidon8 commit | ✅ `leo run` 产出真 commit |
| 网络 execute / broadcast | ⏳ 需 [faucet](https://faucet.aleo.org/) 注资后 `broadcast=true` |

启动：`powershell -ExecutionPolicy Bypass -File tools\start_chain.ps1`  
注资提示：`cd chain\wallet-bridge && npm run fund-hint`  
详情：`chain\LIVE_STATUS.md`

## 玩法 / UI（此前）

经营拆页 · 主线章节 · 联航战报 · 港主 LLM 试点 · HUD v1.22+

## 常用

```bat
tools\godot.cmd --path client
tools\godot.cmd --headless --path client res://tests\Smoke.tscn
```
