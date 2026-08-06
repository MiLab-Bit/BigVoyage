# Aleo 生产路径安装（本机一次）

## 1. Leo 工具链

```powershell
powershell -ExecutionPolicy Bypass -File tools\install_leo.ps1
# 或手动：解压 leo-lang-v4.4.0 Windows zip → C:\tools\leo\leo.exe
$env:LEO_BIN = "C:\tools\leo\leo.exe"
cd chain\programs\bv_commit
& $env:LEO_BIN build
& $env:LEO_BIN run commit_battle 1field 2field 3field 42u64 1u8 3u8 4field 1u32
```

把输出的 `commit: …field` 写回 `sidecar/testdata/poseidon8_vectors.json`。

## 2. Field 映射

- Python：`sidecar/field_mapper.py`
- Godot：`client/core/FieldMapper.gd`
- 规则见 `HASH_FREEZE.md`（BN254 Fr）

## 3. 真钱包 + 资金（Provable SDK / Leo Wallet）

> **注意：Leo Wallet 用户必须先手动将网络更改为 Aleo 测试网才能连接。**  
> 水龙头领的是 **testnet 免费 credits**，不是法币付款。

```powershell
cd chain\wallet-bridge
npm i
npm run account          # 生成 dev_account.json（勿提交）
npm run fund-hint        # 打印水龙头地址 + 网络提示
# Leo Wallet：先切到 Aleo Testnet，再连接 / 领水
# 浏览器打开 https://faucet.aleo.org/ 向该地址注资
npm start                # :8788
```

## 4. Sidecar（leo run / execute）

推荐 Node Sidecar（本机 Windows Store Python 可能是空桩）：

```powershell
powershell -ExecutionPolicy Bypass -File tools\start_chain.ps1
# 或：
#   cd chain\wallet-bridge && npm start   # :8788
#   cd chain\sidecar && npm start         # :8787  (node server.mjs)
# POST /commit → field map → leo run →（可选）wallet-bridge execute
```

Python 版仍保留：`python chain/sidecar/server.py`（需真 Python 3）。

客户端 `CHAIN_MOCK=true` 时仍会尝试 Sidecar；权威 commit 只认 leo Poseidon8。

## 5. soft_v1 → 重冻

`poseidon8_soft_v1` 已作废。新承诺算法名：`poseidon8_snarkvm_v1`。
