# BigVoyage · 本地机密说明

本文说明：**哪些敏感文件故意没有提交到 GitHub**、如何在本机生成，以及协作时的安全边界。

仓库：[MiLab-Bit/BigVoyage](https://github.com/MiLab-Bit/BigVoyage)  
相关忽略规则见根目录 `.gitignore`（`# Local secrets` 段）。

---

## 1. 未入库清单（Never commit）

| 本地文件 | 用途 | 仓库替代物 |
|---|---|---|
| `client/config/llm.local.json` | 港主 LLM API Key / 网关 | `client/config/llm.example.json` |
| `chain/wallet-bridge/dev_account.json` | Aleo 开发私钥 + 地址 | `chain/wallet-bridge/dev_account.example.json` |
| `**/wallet_dev.json` | 其它钱包开发导出 | （无，勿提交） |
| `**/*private*key*` / `**/*.pem` | 私钥 / TLS 材料 | （无，勿提交） |
| `*.local.json` | 任意本机覆盖配置 | 用 `*.example.json` 模板 |

另外：**工具链二进制**也不入库（体积 / 非机密）：`tools/leo/leo.exe`、`tools/godot/*.exe` 等，需本机自行安装。

---

## 2. 钱包密钥（Aleo / wallet-bridge）

### 是什么

`chain/wallet-bridge/dev_account.json` 由 Provable SDK 生成，大致字段：

```json
{
  "network": "testnet",
  "created": "...",
  "warning": "DEV ONLY — never commit",
  "privateKey": "APrivateKey1...",
  "address": "aleo1..."
}
```

- **privateKey**：签名 / 链上 execute 用，等同资产控制权  
- **address**：公开地址，可给 faucet、队友看余额（**不要**连同私钥一起发）

### 本机生成

```powershell
cd chain\wallet-bridge
npm install
npm run account          # 写出 dev_account.json（已 gitignore）
npm run fund-hint        # 打印地址 + faucet 指引
```

领测试币：https://faucet.aleo.org/（**Testnet**；Leo Wallet 也需切到 Aleo Testnet）

启动桥：

```powershell
npm start                # 默认 http://127.0.0.1:8788
```

### 安全注意

- 仅用于 **开发 / 测试网**；勿把同一私钥当主网资产钱包。  
- 若私钥曾出现在聊天、截图、日志里：**立刻废弃该账户，重新 `npm run account`，旧地址上的 testnet 币可放弃**。  
- 日志（`*.out.log` / `*.err.log`）也不要提交；其中可能夹带地址或请求体。

---

## 3. LLM API Key（港主简报）

### 是什么

客户端 `LlmGateway` 优先读 `res://config/llm.local.json`；没有则回退 `llm.example.json`（无密钥时走本地 fallback 文案）。

模板：`client/config/llm.example.json`

```json
{
  "enabled": true,
  "base_url": "https://www.abc-ai.cn/v1/chat/completions",
  "model": "Qwen-flash",
  "api_key": "",
  "temperature": 0.7,
  "timeout_sec": 25
}
```

### 本机配置

```powershell
copy client\config\llm.example.json client\config\llm.local.json
# 编辑 llm.local.json：填入 api_key，确认 enabled=true
```

- `enabled=false` 或空 key → 港主简报用本地兜底，不打外网。  
- Key 曾在对话中粘贴过的，建议在服务商控制台 **轮换 / 作废旧 key**。

---

## 4. 克隆仓库后的最短清单

1. 拉代码：`main`（工程）+ 按需 `docs/design` / `assets/*`  
2. 装 Godot 4.7+、Leo CLI（若要真链 commit）  
3. 可选 LLM：复制 `llm.example.json` → `llm.local.json` 并填 key  
4. 可选链：`chain/wallet-bridge` 里 `npm run account` → faucet → `npm start`；Sidecar 见 `tools/start_chain.ps1` / `chain/LIVE_STATUS.md`  
5. 推送前自检：

```powershell
git status
git check-ignore -v client\config\llm.local.json
git check-ignore -v chain\wallet-bridge\dev_account.json
# 两者应显示被 ignore；且 git status 中不应出现它们
```

---

## 5. 可以公开 vs 必须私密

| 可以公开 / 可进仓库 | 必须私密 / 仅本机 |
|---|---|
| 合约/Leo 源码、Sidecar 代码、客户端 | `privateKey`、任何助记词 |
| 测试网 **address**（收款、faucet） | LLM `api_key`、云厂商 Token |
| `*.example.json`、架构文档 | 含密钥的截图、聊天记录、日志附件 |
| faucet / explorer 链接 | `.pem`、云主机 SSH 私钥 |

---

## 6. 事故处理（泄露时）

1. **立刻**轮换 LLM Key；废弃已泄露的 Aleo 开发账户并新建。  
2. 检查 GitHub 提交 / Issue / Actions 日志是否含密钥；若已进历史，需改历史或作废密钥（作废优先）。  
3. 确认 `.gitignore` 仍包含上文路径；新人 onboarding 发本文而非发 `*.local.json` 文件。

---

*本文只描述「如何本地持有机密」，不包含任何真实密钥或私钥。*
