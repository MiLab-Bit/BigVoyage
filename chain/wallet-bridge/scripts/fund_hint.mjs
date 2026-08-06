import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const p = path.join(__dirname, "..", "dev_account.json");
if (!fs.existsSync(p)) {
  console.log("No account. Run: npm run account");
  process.exit(1);
}
const a = JSON.parse(fs.readFileSync(p, "utf8").replace(/^\uFEFF/, ""));
console.log(`
注意：Leo Wallet 用户必须先手动将网络更改为 Aleo 测试网才能连接。

Fund Aleo credits (testnet · free faucet, not fiat):
  Address: ${a.address}
  Network: ${a.network || "testnet"}
  Faucet:  https://faucet.aleo.org/
  Explorer API: https://api.explorer.provable.com/v1

Then:
  npm start
  # Sidecar will call wallet-bridge /execute
`);
