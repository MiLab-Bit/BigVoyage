import { Account } from "@provablehq/sdk";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(__dirname, "..", "dev_account.json");
const account = new Account();
const data = {
  privateKey: account.privateKey().to_string(),
  address: account.address().to_string(),
  network: process.env.ALEO_NETWORK || "testnet",
  created: new Date().toISOString(),
  warning: "DEV ONLY — never commit",
};
fs.writeFileSync(out, JSON.stringify(data, null, 2));
console.log("address:", data.address);
console.log("saved:", out);
console.log("Next: fund via https://faucet.aleo.org/ or Provable testnet faucet");
